import AuraAgent
import AuraCore
import AuraPolicy
import AuraStore
import AuraTasks
import Foundation
import Testing

actor OllamaTaskCapture {
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
  /// rather than hanging it. Replaces the old 0.5–1 s wall-clock poll loop,
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

private func makeOllamaTaskTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeOllamaTaskPolicyEngine(eventBus: AuraEventBus) async throws -> PolicyEngine {
  let store = try await makeOllamaTaskTempStore()
  return try await PolicyEngine(
    configuration: PolicyConfiguration(
      defaultConfirmationTier: .destructive,
      allowByDefaultTiers: [.observation, .reversible],
      denyByDefaultTiers: [.mutation, .destructive]
    ),
    eventBus: eventBus, store: store)
}

@Test
func ollamaTaskRunnerHappyPathReasoningCompletesTaskViaEngine() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaTaskHappy"))
  let policyEngine = try await makeOllamaTaskPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(modelsResult: .success([OllamaTestFixtures.localModel()]))
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: "42", done: true)
  }
  let adapter = try OllamaAdapter(
    configuration: OllamaConfiguration(), policyEngine: policyEngine, apiClient: client,
    eventBus: bus)
  let store = try await makeOllamaTaskTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = OllamaTaskRunner(adapter: adapter, sessionID: UUID(), defaultCapability: .reasoning)
  let capture = OllamaTaskCapture()
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  let status = try await engine.enqueue(
    request: TaskRequest(objective: "what is the answer to everything?"), runner: runner)
  #expect(status.state == .pending)

  let completed = await capture.waitForEvent(TaskCompletedEvent.self)
  #expect(completed?.outcome == .succeeded)
  #expect(await client.generateCallCount == 1)
}

@Test
func ollamaTaskRunnerClassificationUsesLabelsFromContext() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaTaskClassify"))
  let policyEngine = try await makeOllamaTaskPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(modelsResult: .success([OllamaTestFixtures.localModel()]))
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: #"{"classification":"urgent"}"#, done: true)
  }
  let adapter = try OllamaAdapter(
    configuration: OllamaConfiguration(), policyEngine: policyEngine, apiClient: client,
    eventBus: bus)
  let store = try await makeOllamaTaskTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = OllamaTaskRunner(adapter: adapter, sessionID: UUID())
  let capture = OllamaTaskCapture()
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  let request = TaskRequest(
    objective: "please fix the login bug ASAP",
    context: [
      OllamaTaskRunner.capabilityContextKey: OllamaTaskCapability.classification.rawValue,
      OllamaTaskRunner.labelsContextKey: "urgent, normal",
    ])
  _ = try await engine.enqueue(request: request, runner: runner)

  let completed = await capture.waitForEvent(TaskCompletedEvent.self)
  #expect(completed?.outcome == .succeeded)
}

@Test
func ollamaTaskRunnerClassificationWithoutLabelsFailsTask() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaTaskNoLabels"))
  let policyEngine = try await makeOllamaTaskPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(modelsResult: .success([OllamaTestFixtures.localModel()]))
  let adapter = try OllamaAdapter(
    configuration: OllamaConfiguration(), policyEngine: policyEngine, apiClient: client,
    eventBus: bus)
  let store = try await makeOllamaTaskTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = OllamaTaskRunner(adapter: adapter, sessionID: UUID())
  let capture = OllamaTaskCapture()
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  let request = TaskRequest(
    objective: "classify this",
    context: [OllamaTaskRunner.capabilityContextKey: OllamaTaskCapability.classification.rawValue])
  _ = try await engine.enqueue(request: request, runner: runner)

  let completed = await capture.waitForEvent(TaskCompletedEvent.self)
  #expect(completed?.outcome == .failed)
}

@Test
func ollamaTaskRunnerFailsTaskWhenOllamaUnavailableAndNoFallback() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaTaskUnavailable"))
  let policyEngine = try await makeOllamaTaskPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(healthResult: .failure(AuraError.ollamaError("down")))
  let adapter = try OllamaAdapter(
    configuration: OllamaConfiguration(), policyEngine: policyEngine, apiClient: client,
    eventBus: bus)
  let store = try await makeOllamaTaskTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = OllamaTaskRunner(adapter: adapter, sessionID: UUID(), defaultCapability: .reasoning)
  let capture = OllamaTaskCapture()
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  _ = try await engine.enqueue(request: TaskRequest(objective: "reason about this"), runner: runner)

  let completed = await capture.waitForEvent(TaskCompletedEvent.self)
  #expect(completed?.outcome == .failed)
}
