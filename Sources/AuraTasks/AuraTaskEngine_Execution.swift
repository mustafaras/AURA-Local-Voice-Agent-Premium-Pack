import AuraCore
import AuraStore
import Foundation

extension AuraTaskEngine {
  func run(task: AuraTask, runner: TaskRunner) async {
    await startTask(task)
    guard let plan = await planTask(task, runner: runner) else { return }
    let context = executionContext(for: task)
    await executePlannedTask(task, runner: runner, plan: plan, context: context)
  }

  private func startTask(_ task: AuraTask) async {
    task.transition(to: .running)
    try? await persistState(task: task)
    try? await emit(
      TaskStateChangedEvent(taskID: task.id, previousState: .pending, newState: .running))
  }

  private func planTask(_ task: AuraTask, runner: TaskRunner) async -> TaskPlan? {
    do {
      let plan = try await runner.plan(for: task.requestSnapshot())
      task.setProgress(
        completedSteps: 0, totalSteps: plan.totalSteps,
        currentStepDescription: plan.stepDescriptions.first ?? "")
      return plan
    } catch {
      await finish(task: task, state: .failed, error: "Planning failed: \(error)")
      pumpQueue(runner: runner)
      return nil
    }
  }

  private func executePlannedTask(
    _ task: AuraTask,
    runner: TaskRunner,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async {
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
      await handleAuraError(error, task: task, runner: runner, cancellationState: cancellationState)
    } catch {
      await retryOrFail(task: task, runner: runner, error: "\(error)")
    }
  }

  private func handleAuraError(
    _ error: AuraError,
    task: AuraTask,
    runner: TaskRunner,
    cancellationState: TaskState
  ) async {
    if case .taskCancelled = error {
      await finish(task: task, state: cancellationState, error: "Cancelled")
      return
    }
    if isTerminalBoundFailure(error) {
      await finish(task: task, state: .failed, error: error.localizedDescription)
      return
    }
    await retryOrFail(task: task, runner: runner, error: error.localizedDescription)
  }

  private func retryOrFail(task: AuraTask, runner: TaskRunner, error: String) async {
    task.incrementAttempt()
    guard task.attempt <= task.maxRetries else {
      await finish(task: task, state: .failed, error: error)
      return
    }
    task.transition(to: .pending)
    _ = queue.enqueue(task)
    try? await emit(
      TaskStateChangedEvent(taskID: task.id, previousState: .running, newState: .pending))
  }

  private func executionContext(for task: AuraTask) -> TaskExecutionContext {
    TaskExecutionContext(
      taskID: task.id,
      onProgress: { [weak self] update in
        guard let self else { return }
        if let taskRecord = await self.tasksByID[update.taskID] {
          taskRecord.setProgress(
            completedSteps: update.completedSteps, totalSteps: update.totalSteps,
            currentStepDescription: update.currentStepDescription)
        }
        try? await self.emit(
          TaskProgressEvent(
            taskID: update.taskID, completedSteps: update.completedSteps,
            totalSteps: update.totalSteps,
            currentStepDescription: update.currentStepDescription))
      },
      onCheckpoint: { [weak self] checkpoint in
        guard let self else { return }
        do {
          try await self.storeBackend.saveCheckpoint(checkpoint)
          if let taskRecord = await self.tasksByID[checkpoint.taskID] {
            await MainActor.run { taskRecord.latestCheckpointName = checkpoint.name }
            try await self.persistState(task: taskRecord)
          }
          try await self.emit(
            TaskCheckpointEvent(
              taskID: checkpoint.taskID, checkpointKey: checkpoint.name,
              checkpointedAt: Date(timeIntervalSince1970: checkpoint.capturedAt)))
        } catch { return }
      })
  }

  func isTerminalBoundFailure(_ error: AuraError) -> Bool {
    switch error {
    case .taskExpired:
      return true
    case .taskError(let message):
      return message.contains("inactivity timeout")
    default:
      return false
    }
  }

  func runWithWatchdog(
    task: AuraTask,
    runner: TaskRunner,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    do {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          try await self.executeRunner(task, runner: runner, plan: plan, context: context)
        }
        group.addTask { try await self.watchTask(task, context: context) }
        defer { group.cancelAll() }
        _ = try await group.next()
      }
    } catch let error as AuraError {
      throw error
    } catch is CancellationError {
      throw AuraError.taskCancelled(task.id)
    } catch {
      throw AuraError.taskError("task watchdog failed: \(error.localizedDescription)")
    }
  }

  private func executeRunner(
    _ task: AuraTask,
    runner: TaskRunner,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws {
    try await runner.execute(
      taskID: task.id, request: task.requestSnapshot(), plan: plan, context: context)
  }

  private func watchTask(
    _ task: AuraTask, context: TaskExecutionContext
  ) async throws(AuraError) {
    while true {
      if Task.isCancelled {
        await context.markCancelled()
        throw AuraError.taskCancelled(task.id)
      }
      if task.isExpired() {
        await context.markCancelled()
        throw AuraError.taskExpired(task.id)
      }
      let inactivity = await context.secondsSinceLastActivity()
      if task.inactivityTimeoutSeconds > 0,
        inactivity >= task.inactivityTimeoutSeconds
      {
        await context.markCancelled()
        throw AuraError.taskError(
          "task inactivity timeout after \(task.inactivityTimeoutSeconds)s")
      }
      do {
        try await Task.sleep(for: .milliseconds(50))
      } catch {
        await context.markCancelled()
        throw AuraError.taskCancelled(task.id)
      }
    }
  }

  func finish(task: AuraTask, state: TaskState, error: String?) async {
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

  func persistState(task: AuraTask) async throws(AuraError) {
    try await storeBackend.saveTaskSnapshot(task.snapshot())
  }

  func emit<P: EventPayload>(_ payload: P) async throws(AuraError) {
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
