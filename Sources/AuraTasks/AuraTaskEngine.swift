import AuraCore
import AuraStore
import Foundation

/// Coordinates durable, cancellable, resumable background tasks.
///
/// `AuraTaskEngine` owns a priority queue, tracks active runners, persists
/// checkpoints to `AuraStore`, and enforces cancellation, deadlines, and
/// inactivity timeouts.
public actor AuraTaskEngine {
  private var queue = TaskQueue(capacity: 0)
  private var activeRunners: [UUID: Task<Void, Never>] = [:]
  private var tasksByID: [UUID: AuraTask] = [:]
  private var shutdown = false
  private var recoveryCompleted = false

  private let storeBackend: TaskStoreBackend
  private let eventBus: AuraEventBus
  private let configuration: TaskConfiguration

  /// Creates a new engine.
  /// - Parameters:
  ///   - store: The `AuraStore` used for checkpoints and task snapshots.
  ///   - eventBus: The typed event bus for task lifecycle events.
  ///   - configuration: Task-specific configuration values.
  public init(
    store: AuraStore,
    eventBus: AuraEventBus = .shared,
    configuration: TaskConfiguration? = nil
  ) async {
    let resolved = configuration ?? TaskConfiguration()
    self.storeBackend = await TaskStoreBackend(store: store)
    self.eventBus = eventBus
    self.configuration = resolved
    self.queue = TaskQueue(capacity: resolved.queueCapacity)
  }

  // MARK: - Recovery

  /// Loads previously persisted tasks and re-enqueues those that can resume.
  ///
  /// Must be called before `start()` to guarantee crash-recovery semantics.
  public func recoverState() async throws(AuraError) {
    guard !recoveryCompleted else { return }
    let ids = try await storeBackend.indexEntries()
    for id in ids {
      guard let snapshot = try await storeBackend.loadTaskSnapshot(id: id) else {
        // Stale index entry; remove it.
        try await storeBackend.removeTaskSnapshot(id: id)
        continue
      }
      guard let task = AuraTask.from(snapshot: snapshot) else { continue }

      // Terminal states are remembered but not re-queued.
      switch snapshot.state {
      case .pending, .running:
        tasksByID[task.id] = task
        _ = queue.enqueue(task)
        // Running tasks were interrupted; treat as pending for retry.
      case .paused:
        tasksByID[task.id] = task
      case .completed, .failed, .cancelled:
        tasksByID[task.id] = task
      }
    }
    recoveryCompleted = true
  }

  // MARK: - Public API

  /// Enqueue a new durable task, persist its snapshot, and start the queue pump.
  @discardableResult
  public func enqueue(
    request: TaskRequest,
    runner: TaskRunner
  ) async throws(AuraError) -> TaskStatus {
    guard !shutdown else {
      throw .taskError("Engine is shutting down")
    }
    guard tasksByID.count < configuration.queueCapacity else {
      throw .taskQueueFull
    }

    let task = AuraTask(
      priority: request.priority,
      objective: request.objective,
      deadline: request.deadline,
      inactivityTimeoutSeconds: request.inactivityTimeoutSeconds
        ?? configuration.defaultInactivityTimeoutSeconds,
      maxRetries: request.maxRetries ?? configuration.defaultMaxRetries,
      context: request.context
    )
    task.transition(to: .pending)
    tasksByID[task.id] = task

    let snapshot = task.snapshot()
    try await storeBackend.saveTaskSnapshot(snapshot)

    let payload = TaskEnqueuedEvent(
      taskID: task.id,
      objective: task.objective,
      priority: task.priority,
      deadline: task.deadline
    )
    try await emit(payload)

    let enqueued = queue.enqueue(task)
    if enqueued {
      pumpQueue(runner: runner)
    }

    return task.statusSnapshot()
  }

  /// Start processing the queue. Idempotent with `enqueue` since each enqueue
  /// also pumps; useful for resuming after `recoverState` or manual re-pump.
  public func start(runner: TaskRunner) {
    guard !shutdown else { return }
    pumpQueue(runner: runner)
  }

  /// Return the current status for a task, if known.
  public func status(id: UUID) -> TaskStatus? {
    tasksByID[id]?.statusSnapshot()
  }

  /// Return a summary of every tracked task.
  public func allStatuses() -> [TaskStatus] {
    tasksByID.values.map { $0.statusSnapshot() }
  }

  /// Cancel a queued or running task.
  public func cancel(id: UUID) async throws(AuraError) {
    guard let task = tasksByID[id] else {
      throw .taskNotFound(id)
    }
    guard task.state.canCancel else {
      throw .taskInvalidState("cannot cancel task in state \(task.state)")
    }

    task.transition(to: .cancelled)
    queue.remove(id: id)

    if let running = activeRunners.removeValue(forKey: id) {
      running.cancel()
    }

    try await persistState(task: task)
    try await emit(
      TaskCancelledEvent(
        taskID: id,
        reason: "Cancellation requested"
      )
    )
  }

  /// Pause a queued or running task. Running tasks receive cancellation first.
  public func pause(id: UUID) async throws(AuraError) {
    guard let task = tasksByID[id] else {
      throw .taskNotFound(id)
    }
    guard task.state.canPause else {
      throw .taskInvalidState("cannot pause task in state \(task.state)")
    }

    queue.remove(id: id)
    if let running = activeRunners.removeValue(forKey: id) {
      running.cancel()
    }
    task.transition(to: .paused)

    try await persistState(task: task)
    try await emit(
      TaskPausedEvent(
        taskID: id,
        checkpointKey: task.latestCheckpointName ?? "none"
      )
    )
  }

  /// Resume a paused task by re-enqueueing it.
  public func resume(id: UUID, runner: TaskRunner) async throws(AuraError) {
    guard let task = tasksByID[id] else {
      throw .taskNotFound(id)
    }
    guard task.state == .paused else {
      throw .taskInvalidState("resume requires paused state, got \(task.state)")
    }

    task.transition(to: .pending)
    let enqueued = queue.enqueue(task)
    if enqueued {
      pumpQueue(runner: runner)
    }

    try await persistState(task: task)
    try await emit(
      TaskResumedEvent(
        taskID: id
      )
    )
  }

  /// Delete a terminal or pending task and remove all persisted data.
  public func delete(id: UUID) async throws(AuraError) {
    guard tasksByID[id] != nil else {
      throw .taskNotFound(id)
    }

    queue.remove(id: id)
    activeRunners.removeValue(forKey: id)?.cancel()
    tasksByID.removeValue(forKey: id)

    try await storeBackend.removeTaskSnapshot(id: id)
  }

  /// Gracefully stop accepting new work and cancel active runners.
  public func shutdown() async {
    shutdown = true
    for (_, runner) in activeRunners {
      runner.cancel()
    }
    activeRunners.removeAll()
  }

  // MARK: - Queue pumping

  private func pumpQueue(runner: TaskRunner) {
    // Avoid creating too many concurrent tasks; this is a simple FIFO-with-priority pump.
    // Each call pulls one task and runs it; when it finishes, it pumps again.
    Task {
      await pumpQueueAsync(runner: runner)
    }
  }

  private func pumpQueueAsync(runner: TaskRunner) async {
    guard !shutdown else { return }
    guard activeRunners.count < configuration.maxConcurrentTasks else { return }

    guard let task = queue.dequeue() else { return }
    let taskID = task.id
    activeRunners[taskID] = Task {
      await self.run(task: task, runner: runner)
      // Ensure the task record is removed before the next pump so the
      // engine never over-counts active slots.
      self.activeRunners.removeValue(forKey: taskID)
      self.pumpQueue(runner: runner)
    }
  }

  private func run(task: AuraTask, runner: TaskRunner) async {
    task.transition(to: .running)
    try? await persistState(task: task)
    try? await emit(
      TaskStateChangedEvent(
        taskID: task.id,
        previousState: .pending,
        newState: .running
      )
    )

    let request = task.requestSnapshot()
    let plan: TaskPlan
    do {
      plan = try await runner.plan(for: request)
      task.setProgress(
        completedSteps: 0,
        totalSteps: plan.totalSteps,
        currentStepDescription: plan.stepDescriptions.first ?? ""
      )
    } catch {
      await finish(task: task, state: .failed, error: "Planning failed: \(error)")
      pumpQueue(runner: runner)
      return
    }

    let context = TaskExecutionContext(
      taskID: task.id,
      onProgress: { [weak self] update in
        guard let self else { return }
        if let t = await self.tasksByID[update.taskID] {
          t.setProgress(
            completedSteps: update.completedSteps,
            totalSteps: update.totalSteps,
            currentStepDescription: update.currentStepDescription
          )
        }
        try? await self.emit(
          TaskProgressEvent(
            taskID: update.taskID,
            completedSteps: update.completedSteps,
            totalSteps: update.totalSteps,
            currentStepDescription: update.currentStepDescription
          )
        )
      },
      onCheckpoint: { [weak self] checkpoint in
        guard let self else { return }
        do {
          try await self.storeBackend.saveCheckpoint(checkpoint)
          if let t = await self.tasksByID[checkpoint.taskID] {
            await MainActor.run {
              t.latestCheckpointName = checkpoint.name
            }
            try await self.persistState(task: t)
          }
          try await self.emit(
            TaskCheckpointEvent(
              taskID: checkpoint.taskID,
              checkpointKey: checkpoint.name,
              checkpointedAt: Date(timeIntervalSince1970: checkpoint.capturedAt)
            )
          )
        } catch { return }
      }
    )

    let cancellationState = TaskState.cancelled

    do {
      try await withTaskCancellationHandler {
        try Task.checkCancellation()
        try await runWithWatchdog(task: task, runner: runner, plan: plan, context: context)
        await finish(task: task, state: .completed, error: nil)
      } onCancel: {
        Task { await context.markCancelled() }
      }
    } catch is CancellationError {
      await finish(task: task, state: cancellationState, error: "Cancelled")
    } catch let error as AuraError {
      task.incrementAttempt()
      if task.attempt <= task.maxRetries {
        task.transition(to: .pending)
        _ = queue.enqueue(task)
        try? await emit(
          TaskStateChangedEvent(
            taskID: task.id,
            previousState: .running,
            newState: .pending
          )
        )
      } else {
        await finish(task: task, state: .failed, error: error.localizedDescription)
      }
    } catch {
      task.incrementAttempt()
      if task.attempt <= task.maxRetries {
        task.transition(to: .pending)
        _ = queue.enqueue(task)
        try? await emit(
          TaskStateChangedEvent(
            taskID: task.id,
            previousState: .running,
            newState: .pending
          )
        )
      } else {
        await finish(task: task, state: .failed, error: "\(error)")
      }
    }
  }

  private func runWithWatchdog(
    task: AuraTask,
    runner: TaskRunner,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    // Simple co-operative watchdog: the runner reports activity through context.
    // The runner is responsible for periodic progress/checkpoint calls; if it does not,
    // we cannot safely interrupt arbitrary Swift code. Document this limitation.
    try await runner.execute(taskID: task.id, request: task.requestSnapshot(), plan: plan, context: context)
  }

  private func finish(task: AuraTask, state: TaskState, error: String?) async {
    // Do not overwrite a user-requested cancellation or pause, and never
    // replace one terminal outcome with another. This prevents the runner
    // task from racing past an explicit cancel/pause request.
    let currentState = task.state
    guard !currentState.isTerminal, currentState != .paused, currentState != .cancelled else {
      return
    }

    task.transition(to: state, error: error)
    try? await persistState(task: task)

    let outcome: TaskCompletedEvent.Outcome
    switch state {
    case .completed:
      outcome = .succeeded
    case .failed:
      outcome = .failed
    case .cancelled:
      outcome = .cancelled
    default:
      outcome = .failed
    }
    try? await emit(
      TaskCompletedEvent(
        taskID: task.id,
        outcome: outcome,
        summary: error ?? "Task \(state): \(task.objective)"
      )
    )
  }

  private func persistState(task: AuraTask) async throws(AuraError) {
    try await storeBackend.saveTaskSnapshot(task.snapshot())
  }

  private func emit<P: EventPayload>(_ payload: P) async throws(AuraError) {
    let envelope = EventEnvelope<P>(
      correlationID: UUID(),
      causationID: UUID(),
      actor: .task,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}

// MARK: - AuraTask helpers

extension AuraTask {
  fileprivate static func from(snapshot: TaskSnapshot) -> AuraTask? {
    let task = AuraTask(
      id: snapshot.id,
      createdAt: snapshot.createdAt,
      priority: snapshot.priority,
      objective: snapshot.objective,
      deadline: snapshot.deadline,
      inactivityTimeoutSeconds: snapshot.inactivityTimeoutSeconds,
      maxRetries: snapshot.maxRetries,
      context: snapshot.context
    )
    task.transition(to: snapshot.state, error: snapshot.errorMessage)
    task.setProgress(
      completedSteps: snapshot.completedSteps,
      totalSteps: snapshot.totalSteps,
      currentStepDescription: snapshot.currentStepDescription
    )
    task.setAttempt(snapshot.attempt)
    task.latestCheckpointName = snapshot.latestCheckpointName
    return task
  }

  fileprivate func snapshot() -> TaskSnapshot {
    TaskSnapshot(
      id: id,
      state: state,
      priority: priority,
      objective: objective,
      deadline: deadline,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      currentStepDescription: currentStepDescription,
      errorMessage: errorMessage,
      inactivityTimeoutSeconds: inactivityTimeoutSeconds,
      maxRetries: maxRetries,
      attempt: attempt,
      context: context,
      latestCheckpointName: latestCheckpointName
    )
  }

  fileprivate func requestSnapshot() -> TaskRequest {
    TaskRequest(
      objective: objective,
      priority: priority,
      deadline: deadline,
      inactivityTimeoutSeconds: inactivityTimeoutSeconds,
      maxRetries: maxRetries,
      context: context
    )
  }

  fileprivate func setAttempt(_ value: Int) {
    lock.lock()
    _attempt = value
    lock.unlock()
  }
}

// MARK: - TaskState helpers

extension TaskState {
  fileprivate var canCancel: Bool {
    switch self {
    case .pending, .running, .paused:
      return true
    case .completed, .failed, .cancelled:
      return false
    }
  }

  fileprivate var canPause: Bool {
    switch self {
    case .pending, .running:
      return true
    case .paused, .completed, .failed, .cancelled:
      return false
    }
  }

  fileprivate var isTerminal: Bool {
    switch self {
    case .completed, .failed, .cancelled:
      return true
    case .pending, .running, .paused:
      return false
    }
  }
}
