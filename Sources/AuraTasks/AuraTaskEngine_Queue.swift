import AuraCore
import AuraStore
import Foundation

extension AuraTaskEngine {
  // MARK: - Public API

  /// Enqueue a new durable task, persist its snapshot, and start the queue pump.
  @discardableResult
  public func enqueue(
    request: TaskRequest,
    runner: TaskRunner,
    taskID: UUID = UUID()
  ) async throws(AuraError) -> TaskStatus {
    guard !shutdown else {
      throw .taskError("Engine is shutting down")
    }
    guard tasksByID.count < configuration.queueCapacity else {
      throw .taskQueueFull
    }
    guard tasksByID[taskID] == nil else {
      throw .taskInvalidState("task ID is already registered: " + taskID.uuidString)
    }

    let task = AuraTask(
      id: taskID,
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
}
