import AuraAgent
import AuraCore
import AuraPolicy
import AuraStore
import AuraTasks
import Foundation
import Testing

private actor OllamaTaskCapture {
  var payloads: [any EventPayload] = []

  func append(_ payload: any EventPayload) {
    payloads.append(payload)
  }

  func waitForEvent<E: EventPayload>(
    _ type: E.Type,
    timeoutNanoseconds: UInt64 = 1_000_000_000
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
  await bus.subscribe(TaskCompletedEvent.self) {
    (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
  await bus.subscribe(TaskCompletedEvent.self) {
    (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
  await bus.subscribe(TaskCompletedEvent.self) {
    (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
  await bus.subscribe(TaskCompletedEvent.self) {
    (envelope: EventEnvelope<TaskCompletedEvent>) async in
    await capture.append(envelope.payload)
  }

  _ = try await engine.enqueue(request: TaskRequest(objective: "reason about this"), runner: runner)

  let completed = await capture.waitForEvent(TaskCompletedEvent.self)
  #expect(completed?.outcome == .failed)
}
