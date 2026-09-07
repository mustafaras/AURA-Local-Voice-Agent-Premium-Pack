import AuraCore
import AuraStore
import AuraTasks
import Foundation
import Testing

// MARK: - Test helpers

actor Capture {
  private struct Waiter {
    let id: UUID
    let matches: @Sendable (any EventPayload) -> Bool
    let continuation: CheckedContinuation<(any EventPayload)?, Never>
  }

  private var payloads: [any EventPayload] = []
  private var waiters: [Waiter] = []

  func append(_ payload: any EventPayload) {
    if let index = waiters.firstIndex(where: { $0.matches(payload) }) {
      waiters.remove(at: index).continuation.resume(returning: payload)
    } else {
      payloads.append(payload)
    }
  }

  /// Returns the first matching payload, waiting event-driven instead of
  /// polling: `append` resumes a registered waiter the moment a matching
  /// payload arrives. Bounded at 10 s so a missing event fails the test
  /// rather than hanging it. Replaces the old 0.2–0.5 s poll deadline,
  /// which flaked when the task engine finished just past the deadline.
  func waitForEvent<E: EventPayload>(
    _ type: E.Type,
    timeoutNanoseconds: UInt64 = 10_000_000_000
  ) async -> E? {
    let waiterID = UUID()
    let received = await nextPayload(
      id: waiterID, timeoutNanoseconds: timeoutNanoseconds, matches: { $0 is E })
    return received as? E
  }

  private func nextPayload(
    id: UUID,
    timeoutNanoseconds: UInt64,
    matches: @escaping @Sendable (any EventPayload) -> Bool
  ) async -> (any EventPayload)? {
    await withTaskGroup(of: (any EventPayload)?.self) { group in
      group.addTask { await self.receive(id: id, matches: matches) }
      group.addTask {
        try? await Task.sleep(nanoseconds: timeoutNanoseconds)
        await self.cancelWaiter(id: id)
        return nil
      }
      let received = (await group.next()) ?? nil
      group.cancelAll()
      return received
    }
  }

  /// The stored-payload scan and the waiter registration run in one
  /// synchronous, actor-isolated section, so no `append` can land between
  /// them and strand a waiter.
  private func receive(
    id: UUID,
    matches: @escaping @Sendable (any EventPayload) -> Bool
  ) async -> (any EventPayload)? {
    if let found = payloads.first(where: matches) {
      return found
    }
    return await withCheckedContinuation { continuation in
      waiters.append(Waiter(id: id, matches: matches, continuation: continuation))
    }
  }

  private func cancelWaiter(id: UUID) {
    guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
    waiters.remove(at: index).continuation.resume(returning: nil)
  }
}

extension EventPayload {
  func asType<T: EventPayload>(_ type: T.Type) -> T? {
    self as? T
  }
}

actor Gate {
  var continuation: CheckedContinuation<Void, Never>?
  var open = false

  func hold() async {
    guard !open else { return }
    await withTaskCancellationHandler {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        self.continuation = continuation
      }
    } onCancel: { [weak self] in
      guard let self else { return }
      Task {
        await self.cancelHold()
      }
    }
  }

  func cancelHold() {
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

struct TaskEngineFixture {
  let engine: AuraTaskEngine
  let store: AuraStore
  let capture: Capture
}

func makeEngine(
  config: TaskConfiguration = TaskConfiguration(maxConcurrentTasks: 2, queueCapacity: 5),
  store: AuraStore? = nil
) async throws -> TaskEngineFixture {
  let storeInstance: AuraStore
  if let store {
    storeInstance = store
  } else {
    storeInstance = try await makeTempStore()
  }
  let capture = Capture()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraTasksTests", category: "testBus"))
  await bus.subscribe(TaskEnqueuedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskStateChangedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskProgressEvent.self) { envelope in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskPausedEvent.self) { (envelope: EventEnvelope<TaskPausedEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskResumedEvent.self) { (envelope: EventEnvelope<TaskResumedEvent>) async in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskCancelledEvent.self) { envelope in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }
  await bus.subscribe(TaskCheckpointEvent.self) { envelope in
    await capture.append(envelope.payload)
  }
  let engine = await AuraTaskEngine(store: storeInstance, eventBus: bus, configuration: config)
  try await engine.recoverState()
  return TaskEngineFixture(engine: engine, store: storeInstance, capture: capture)
}

// MARK: - Task enqueue and status

@Test
func enqueueReturnsPendingStatus() async throws {
  let fixture = try await makeEngine()
  let engine = fixture.engine
  let capture = fixture.capture
  let gate = Gate()
  let runner = BlockingRunner(gate: gate)
  let status = try await engine.enqueue(
    request: TaskRequest(objective: "count"),
    runner: runner
  )
  #expect(status.objective == "count")
  #expect(status.state == .pending)

  _ = await capture.waitForEvent(TaskStateChangedEvent.self)
  #expect(await engine.status(id: status.id)?.state == .running)
  await gate.release()
  try? await Task.sleep(nanoseconds: 50_000_000)
}

@Test
func queueCapacityRejectsExcessTasks() async throws {
  // queueCapacity limits the number of tasks that can be tracked at once.
  // Use a blocking runner so the first task occupies the queue.
  let engine = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 1)
  ).engine
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
  let engine = try await makeEngine(
    config: TaskConfiguration(maxConcurrentTasks: 1, queueCapacity: 10)
  ).engine
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
