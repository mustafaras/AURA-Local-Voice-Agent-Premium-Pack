import AuraCore
import AuraStore
import AuraTasks
import Foundation
import Testing

// MARK: - Test helpers

actor Capture {
  var payloads: [any EventPayload] = []

  func append(_ payload: any EventPayload) {
    payloads.append(payload)
  }

  func waitForEvent<E: EventPayload>(
    _ type: E.Type,
    timeoutNanoseconds: UInt64 = 500_000_000
  ) async -> E? {
    let deadline = ContinuousClock().now + .nanoseconds(Int64(timeoutNanoseconds))
    while ContinuousClock().now < deadline {
      if let found = payloads.first(where: { $0 is E }) as? E {
        return found
      }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return nil
  }
}

extension EventPayload {
  func asType<T: EventPayload>(_ type: T.Type) -> T? {
    self as? T
  }
}

actor Gate {
  private var continuation: CheckedContinuation<Void, Never>?
  private var open = false

  func hold() async {
    guard !open else { return }
    await withTaskCancellationHandler {
      await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        self.continuation = c
      }
    } onCancel: { [weak self] in
      guard let self else { return }
      Task {
        await self.cancelHold()
      }
    }
  }

  private func cancelHold() {
    open = true
    continuation?.resume()
    continuation = nil
  }

  func release() {
    open = true
    continuation?.resume()
    continuation = nil
  }

  func reset() {
    open = false
    continuation = nil
  }
}

struct BlockingRunner: TaskRunner {
  var gate: Gate?

  init(gate: Gate? = nil) {
    self.gate = gate
  }

  func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan { TaskPlan(totalSteps: 1) }

  func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    if let gate {
      await gate.hold()
    } else {
      // Non-gated default runner: cooperatively yield so it never completes during a test.
      for _ in 0..<1000 {
        try? Task.checkCancellation()
        try? await Task.sleep(nanoseconds: 10_000_000)
      }
    }
  }
}

struct CountingRunner: TaskRunner {
  var plan: TaskPlan
  var execute:
    @Sendable (
      UUID,
      TaskRequest,
      TaskPlan,
      TaskExecutionContext
    ) async -> Void

  func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan { plan }

  func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    await execute(taskID, request, plan, context)
  }
}

struct FailingRunner: TaskRunner {
  var plan: TaskPlan = TaskPlan(totalSteps: 1)
  var error: AuraError

  func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan { plan }

  func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    throw error
  }
}

func makeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

func makeEngine(
  config: TaskConfiguration = TaskConfiguration(maxConcurrentTasks: 2, queueCapacity: 5),
  store: AuraStore? = nil
) async throws -> (AuraTaskEngine, AuraStore, Capture) {
  let s: AuraStore
  if let store {
    s = store
  } else {
    s = try await makeTempStore()
  }
  let capture = Capture()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraTasksTests", category: "testBus"))
  await bus.subscribe(TaskEnqueuedEvent.self) {
    (envelope: EventEnvelope<TaskEnqueuedEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskStateChangedEvent.self) {
    (envelope: EventEnvelope<TaskStateChangedEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskProgressEvent.self) {
    (envelope: EventEnvelope<TaskProgressEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskPausedEvent.self) { (envelope: EventEnvelope<TaskPausedEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskResumedEvent.self) { (envelope: EventEnvelope<TaskResumedEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskCancelledEvent.self) {
    (envelope: EventEnvelope<TaskCancelledEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskCompletedEvent.self) {
    (envelope: EventEnvelope<TaskCompletedEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskCheckpointEvent.self) {
    (envelope: EventEnvelope<TaskCheckpointEvent>) async in
    await capture.append(envelope.payload)
  }
  let engine = await AuraTaskEngine(store: s, eventBus: bus, configuration: config)
  try await engine.recoverState()
  return (engine, s, capture)
}

// MARK: - Task enqueue and status

@Test
func enqueueReturnsPendingStatus() async throws {
  let (engine, _, capture) = try await makeEngine()
  let gate = Gate()
  let runner = BlockingRunner(gate: gate)
  let status = try await engine.enqueue(
    request: TaskRequest(objective: "count"),
    runner: runner
  )
  #expect(status.objective == "count")
  #expect(status.state == .pending)

  _ = await capture.waitForEvent(TaskStateChangedEvent.self, timeoutNanoseconds: 200_000_000)
  #expect(await engine.status(id: status.id)?.state == .running)
  await gate.release()
  try? await Task.sleep(nanoseconds: 50_000_000)
}

@Test
func queueCapacityRejectsExcessTasks() async throws {
  // queueCapacity limits the number of tasks that can be tracked at once.
  // Use a blocking runner so the first task occupies the queue.
  let (engine, _, _) = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 1)
  )
  let gate = Gate()
  let runner = BlockingRunner(gate: gate)
  _ = try await engine.enqueue(request: TaskRequest(objective: "first"), runner: runner)
  await #expect(throws: AuraError.self) {
    try await engine.enqueue(request: TaskRequest(objective: "second"), runner: runner)
  }
  await gate.release()
  try? await Task.sleep(nanoseconds: 50_000_000)
}

// MARK: - Priority ordering

@Test
func priorityQueueOrdersHighBeforeNormal() async throws {
  let (engine, _, _) = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 10)
  )
  let gate = Gate()
  let runner = BlockingRunner(gate: gate)

  let normal = try await engine.enqueue(
    request: TaskRequest(objective: "normal", priority: .normal),
    runner: runner
  )
  let high = try await engine.enqueue(
    request: TaskRequest(objective: "high", priority: .high),
    runner: runner
  )
  let urgent = try await engine.enqueue(
    request: TaskRequest(objective: "urgent", priority: .urgent),
    runner: runner
  )

  // Wait for the normal-priority task to start; the others should be pending.
  try? await Task.sleep(nanoseconds: 50_000_000)

  let statuses = await engine.allStatuses()
  let pendingIDs = statuses.filter { $0.state == .pending }.map { $0.id }
  #expect(pendingIDs.contains(high.id))
  #expect(pendingIDs.contains(urgent.id))
  #expect(!pendingIDs.contains(normal.id))

  await gate.release()
  try? await Task.sleep(nanoseconds: 50_000_000)
}

// MARK: - Cancellation

@Test
func cancellationMovesTaskToCancelled() async throws {
  let (engine, _, capture) = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 10)
  )
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
  let (engine, _, _) = try await makeEngine()
  let id = UUID()
  await #expect(throws: AuraError.self) {
    try await engine.cancel(id: id)
  }
}

// MARK: - Pause / resume

@Test
func pauseAndResumeRunningTask() async throws {
  let (engine, _, capture) = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 10)
  )
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
  let (engine, _, _) = try await makeEngine(store: store)
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
  let (engine, _, _) = try await makeEngine(
    config: TaskConfiguration(defaultMaxRetries: 3, maxConcurrentTasks: 1, queueCapacity: 5))
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
  let (engine, _, _) = try await makeEngine(
    config: TaskConfiguration(defaultMaxRetries: 3, maxConcurrentTasks: 1, queueCapacity: 5))
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
  let (engine, _, _) = try await makeEngine(
    config: TaskConfiguration(defaultMaxRetries: 1, maxConcurrentTasks: 1, queueCapacity: 10)
  )
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
  let (engine, _, _) = try await makeEngine(store: store)
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
  let (engine, _, _) = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 10)
  )
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
