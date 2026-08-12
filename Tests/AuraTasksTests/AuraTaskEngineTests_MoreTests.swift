import AuraCore
import AuraStore
import AuraTasks
import Foundation
import Testing

@Test
func cancellationMovesTaskToCancelled() async throws {
  let fixture = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 10)
  )
  let engine = fixture.engine
  let capture = fixture.capture
  let gate = Gate()
  let runner = BlockingRunner(gate: gate)
  let status = try await engine.enqueue(
    request: TaskRequest(objective: "cancel me", priority: .high),
    runner: runner
  )
  try? await Task.sleep(nanoseconds: 50_000_000)
  #expect(await engine.status(id: status.id)?.state == .running)

  try await engine.cancel(id: status.id)
  _ = await capture.waitForEvent(TaskCancelledEvent.self, timeoutNanoseconds: 200_000_000)

  let finalStatus = await engine.status(id: status.id)
  #expect(finalStatus?.state == .cancelled)
  await gate.release()
  try? await Task.sleep(nanoseconds: 50_000_000)
  #expect(await engine.status(id: status.id)?.state == .cancelled)
}

@Test
func cancelUnknownTaskThrowsNotFound() async throws {
  let engine = try await makeEngine().engine
  let id = UUID()
  await #expect(throws: AuraError.self) {
    try await engine.cancel(id: id)
  }
}

// MARK: - Pause / resume

@Test
func pauseAndResumeRunningTask() async throws {
  let fixture = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 10)
  )
  let engine = fixture.engine
  let capture = fixture.capture
  let gate = Gate()
  let runner = BlockingRunner(gate: gate)
  let status = try await engine.enqueue(
    request: TaskRequest(objective: "pause me", priority: .high),
    runner: runner
  )
  try? await Task.sleep(nanoseconds: 50_000_000)
  #expect(await engine.status(id: status.id)?.state == .running)

  try await engine.pause(id: status.id)
  _ = await capture.waitForEvent(TaskPausedEvent.self, timeoutNanoseconds: 200_000_000)
  #expect(await engine.status(id: status.id)?.state == .paused)

  let resumeGate = Gate()
  let resumedRunner = BlockingRunner(gate: resumeGate)
  try await engine.resume(id: status.id, runner: resumedRunner)
  _ = await capture.waitForEvent(TaskStateChangedEvent.self, timeoutNanoseconds: 200_000_000)
  #expect(await engine.status(id: status.id)?.state == .running)

  await resumeGate.release()
  _ = await capture.waitForEvent(TaskCompletedEvent.self, timeoutNanoseconds: 200_000_000)
  #expect(await engine.status(id: status.id)?.state == .completed)
}

// MARK: - Checkpoint persistence

@Test
func checkpointPersistsAndCanBeLoaded() async throws {
  let store = try await makeTempStore()
  let engine = try await makeEngine(store: store).engine
  let runner = CountingRunner(plan: TaskPlan(totalSteps: 1)) { _, _, _, context in
    do {
      try await context.reportCheckpoint(
        name: "step-1",
        state: ["counter": "42"]
      )
    } catch {
      Issue.record("Checkpoint failed: \(error)")
    }
  }
  let status = try await engine.enqueue(
    request: TaskRequest(objective: "checkpoint"),
    runner: runner
  )
  try? await Task.sleep(nanoseconds: 100_000_000)

  let backend = await TaskStoreBackend(store: store)
  let checkpoint = try await backend.loadCheckpoint(taskID: status.id, name: "step-1")
  #expect(checkpoint?.name == "step-1")
  #expect(checkpoint?.state["counter"] == "42")
  let latest = try await backend.loadLatestCheckpoint(taskID: status.id)
  #expect(latest?.name == "step-1")
}

// MARK: - Deadline and inactivity watchdog

@Test
func expiredTaskFailsWithoutRetry() async throws {
  let engine = try await makeEngine(
    config: TaskConfiguration(defaultMaxRetries: 3, maxConcurrentTasks: 1, queueCapacity: 5)
  )
  .engine
  let gate = Gate()
  let status = try await engine.enqueue(
    request: TaskRequest(
      objective: "deadline",
      deadline: Date().addingTimeInterval(0.05),
      inactivityTimeoutSeconds: 2,
      maxRetries: 3),
    runner: BlockingRunner(gate: gate))
  try? await Task.sleep(nanoseconds: 250_000_000)
  let finalStatus = await engine.status(id: status.id)
  #expect(finalStatus?.state == .failed)
  #expect(finalStatus?.errorMessage?.contains("expired") == true)
}

@Test
func inactiveTaskFailsWithoutRetry() async throws {
  let engine = try await makeEngine(
    config: TaskConfiguration(defaultMaxRetries: 3, maxConcurrentTasks: 1, queueCapacity: 5)
  )
  .engine
  let gate = Gate()
  let status = try await engine.enqueue(
    request: TaskRequest(
      objective: "inactivity",
      deadline: Date().addingTimeInterval(2),
      inactivityTimeoutSeconds: 0.05,
      maxRetries: 3),
    runner: BlockingRunner(gate: gate))
  try? await Task.sleep(nanoseconds: 250_000_000)
  let finalStatus = await engine.status(id: status.id)
  #expect(finalStatus?.state == .failed)
  #expect(finalStatus?.errorMessage?.contains("inactivity timeout") == true)
}

// MARK: - Retry exhaustion

@Test
func retryExhaustionFailsTask() async throws {
  let engine = try await makeEngine(
    config: TaskConfiguration(defaultMaxRetries: 1, maxConcurrentTasks: 1, queueCapacity: 10)
  )
  .engine
  let runner = FailingRunner(error: AuraError.taskError("boom"))
  let status = try await engine.enqueue(
    request: TaskRequest(objective: "retry fail", maxRetries: 1),
    runner: runner
  )
  try? await Task.sleep(nanoseconds: 300_000_000)
  let finalStatus = await engine.status(id: status.id)
  #expect(finalStatus?.state == .failed)
  #expect(finalStatus?.errorMessage?.contains("boom") == true)
}

// MARK: - Delete

@Test
func deleteRemovesTaskAndData() async throws {
  let store = try await makeTempStore()
  let engine = try await makeEngine(store: store).engine
  let runner = CountingRunner(plan: TaskPlan(totalSteps: 1)) { _, _, _, _ in }
  let status = try await engine.enqueue(
    request: TaskRequest(objective: "delete me"),
    runner: runner
  )
  try await engine.delete(id: status.id)
  #expect(await engine.status(id: status.id) == nil)

  let backend = await TaskStoreBackend(store: store)
  let snapshot = try await backend.loadTaskSnapshot(id: status.id)
  #expect(snapshot == nil)
}

// MARK: - Concurrent task limit

@Test
func maxConcurrentTasksLimitsActiveRunners() async throws {
  let engine = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 10)
  )
  .engine
  let runner = CountingRunner(plan: TaskPlan(totalSteps: 1)) { _, _, _, _ in
    try? await Task.sleep(nanoseconds: 200_000_000)
  }
  _ = try await engine.enqueue(
    request: TaskRequest(objective: "first", priority: .normal),
    runner: runner
  )
  _ = try await engine.enqueue(
    request: TaskRequest(objective: "second", priority: .normal),
    runner: runner
  )
  try? await Task.sleep(nanoseconds: 50_000_000)

  let statuses = await engine.allStatuses()
  let runningCount = statuses.filter { $0.state == .running }.count
  let pendingCount = statuses.filter { $0.state == .pending }.count
  #expect(runningCount == 1)
  #expect(pendingCount == 1)
}
