import AuraAgent
import AuraCore
import AuraPolicy
import AuraStore
import Foundation
import Testing

// MARK: - Policy engine helpers (mirrors CopilotTaskRunnerTests' pattern)

private func makeOllamaTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeOllamaPolicyEngine(
  configuration: PolicyConfiguration = PolicyConfiguration(
    defaultConfirmationTier: .destructive,
    allowByDefaultTiers: [.observation, .reversible],
    denyByDefaultTiers: [.mutation, .destructive]
  ),
  eventBus: AuraEventBus
) async throws -> PolicyEngine {
  let store = try await makeOllamaTempStore()
  return try await PolicyEngine(configuration: configuration, eventBus: eventBus, store: store)
}

private func makeAdapter(
  configuration: OllamaConfiguration = OllamaConfiguration(),
  policyEngine: PolicyEngine,
  approvalPresenter: any OllamaApprovalPresenting = OllamaAlwaysDenyApprovalPresenter(),
  apiClient: any OllamaAPIClient,
  eventBus: AuraEventBus,
  thermalStateProvider: @escaping @Sendable () -> ProcessInfo.ThermalState = { .nominal }
) throws -> OllamaAdapter {
  try OllamaAdapter(
    configuration: configuration, policyEngine: policyEngine, approvalPresenter: approvalPresenter,
    apiClient: apiClient, eventBus: eventBus, thermalStateProvider: thermalStateProvider)
}

private func succeedingClassifyClient(
  model: OllamaTagsModel = OllamaTestFixtures.localModel(),
  running: [OllamaPsModel] = []
) -> FakeOllamaAPIClient {
  let client = FakeOllamaAPIClient(
    modelsResult: .success([model]), runningModelsResult: .success(running))
  return client
}

// MARK: - Local vs. cloud policy gating

@Test
func ollamaAdapterLocalInferenceAllowedByDefaultWithoutConfirmation() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaLocal"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = succeedingClassifyClient()
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: #"{"classification":"urgent"}"#, done: true)
  }
  let adapter = try makeAdapter(policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let result = try await adapter.classify(
    prompt: "please help urgently", labels: ["urgent", "normal"], actor: .agentOllama,
    sessionID: UUID(), correlationID: UUID(), causationID: UUID())
  #expect(result.text == "urgent")
  #expect(result.degraded == false)
  #expect(result.model == "gemma4:latest")
}

@Test
func ollamaAdapterCloudInferenceDeniedByDefaultFallsBackWhenProvided() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaCloudDeny"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = succeedingClassifyClient(model: OllamaTestFixtures.cloudModel())
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: #"{"classification":"urgent"}"#, done: true)
  }
  var configuration = OllamaConfiguration()
  configuration.allowCloudModels = true
  let adapter = try makeAdapter(
    configuration: configuration, policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let result = try await adapter.classify(
    prompt: "x", labels: ["urgent", "normal"], actor: .agentOllama, sessionID: UUID(),
    correlationID: UUID(), causationID: UUID(),
    deterministicFallback: { _, labels in labels.first ?? "unknown" })
  #expect(result.degraded)
  #expect(result.model == nil)
  #expect(await client.generateCallCount == 0)
}

@Test
func ollamaAdapterCloudInferenceDeniedByDefaultThrowsWithoutFallback() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaCloudDenyThrow"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = succeedingClassifyClient(model: OllamaTestFixtures.cloudModel())
  var configuration = OllamaConfiguration()
  configuration.allowCloudModels = true
  let adapter = try makeAdapter(
    configuration: configuration, policyEngine: policyEngine, apiClient: client, eventBus: bus)

  await #expect(throws: AuraError.self) {
    try await adapter.classify(
      prompt: "x", labels: ["urgent", "normal"], actor: .agentOllama, sessionID: UUID(),
      correlationID: UUID(), causationID: UUID())
  }
}

@Test
func ollamaAdapterCloudInferenceConfirmPathRoundTripsThroughPolicyEngine() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaCloudConfirm"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  try await policyEngine.issueGrant(
    Grant(
      capability: .agentOllamaCloudInference,
      confirmationRequirement: .always,
      issuer: .user,
      purpose: "test"
    ))
  let client = succeedingClassifyClient(model: OllamaTestFixtures.cloudModel())
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: #"{"classification":"normal"}"#, done: true)
  }
  var configuration = OllamaConfiguration()
  configuration.allowCloudModels = true
  let adapter = try makeAdapter(
    configuration: configuration, policyEngine: policyEngine,
    approvalPresenter: OllamaAlwaysAllowApprovalPresenter(), apiClient: client, eventBus: bus)

  let result = try await adapter.classify(
    prompt: "x", labels: ["urgent", "normal"], actor: .agentOllama, sessionID: UUID(),
    correlationID: UUID(), causationID: UUID())
  #expect(result.text == "normal")
  #expect(result.degraded == false)
  #expect(await client.generateCallCount == 1)
}

@Test
func ollamaAdapterCloudInferenceConfirmPathDeniedWhenPresenterRefuses() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaCloudConfirmDeny"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  try await policyEngine.issueGrant(
    Grant(
      capability: .agentOllamaCloudInference,
      confirmationRequirement: .always,
      issuer: .user,
      purpose: "test"
    ))
  let client = succeedingClassifyClient(model: OllamaTestFixtures.cloudModel())
  var configuration = OllamaConfiguration()
  configuration.allowCloudModels = true
  let adapter = try makeAdapter(
    configuration: configuration, policyEngine: policyEngine,
    approvalPresenter: OllamaAlwaysDenyApprovalPresenter(), apiClient: client, eventBus: bus)

  await #expect(throws: AuraError.self) {
    try await adapter.classify(
      prompt: "x", labels: ["urgent", "normal"], actor: .agentOllama, sessionID: UUID(),
      correlationID: UUID(), causationID: UUID())
  }
  #expect(await client.generateCallCount == 0)
}

// MARK: - Health check / degraded mode

@Test
func ollamaAdapterHealthCheckFailureUsesFallback() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaHealth"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(
    healthResult: .failure(AuraError.ollamaError("connection refused")))
  let adapter = try makeAdapter(policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let result = try await adapter.classify(
    prompt: "x", labels: ["a", "b"], actor: .agentOllama, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID(), deterministicFallback: { _, labels in labels.first ?? "?" })
  #expect(result.degraded)
  #expect(result.text == "a")
}

@Test
func ollamaAdapterHealthCheckFailureThrowsWithoutFallback() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaHealthThrow"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(
    healthResult: .failure(AuraError.ollamaError("connection refused")))
  let adapter = try makeAdapter(policyEngine: policyEngine, apiClient: client, eventBus: bus)

  await #expect(throws: AuraError.self) {
    try await adapter.summarize(
      prompt: "x", actor: .agentOllama, sessionID: UUID(), correlationID: UUID(),
      causationID: UUID())
  }
}

@Test
func ollamaAdapterReasonHasNoFallbackParameterAndThrowsWhenDegraded() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaReason"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(healthResult: .failure(AuraError.ollamaError("down")))
  let adapter = try makeAdapter(policyEngine: policyEngine, apiClient: client, eventBus: bus)

  await #expect(throws: AuraError.self) {
    try await adapter.reason(
      prompt: "why is the sky blue", actor: .agentOllama, sessionID: UUID(),
      correlationID: UUID(), causationID: UUID())
  }
}

@Test
func ollamaAdapterThermalCriticalEntersDegradedModeEvenWhenHealthy() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaThermal"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = succeedingClassifyClient()
  let adapter = try makeAdapter(
    policyEngine: policyEngine, apiClient: client, eventBus: bus,
    thermalStateProvider: { .critical })

  let result = try await adapter.classify(
    prompt: "x", labels: ["a", "b"], actor: .agentOllama, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID(), deterministicFallback: { _, labels in labels.last ?? "?" })
  #expect(result.degraded)
  #expect(await client.generateCallCount == 0)
}

@Test
func ollamaAdapterNoModelForCapabilityEntersDegradedMode() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaNoModel"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(modelsResult: .success([]))
  let adapter = try makeAdapter(policyEngine: policyEngine, apiClient: client, eventBus: bus)

  await #expect(throws: AuraError.self) {
    try await adapter.summarize(
      prompt: "x", actor: .agentOllama, sessionID: UUID(), correlationID: UUID(),
      causationID: UUID())
  }
}

// MARK: - Memory budget

@Test
func ollamaAdapterEvictsResidentModelToFitBudget() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaEvict"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let newModel = OllamaTestFixtures.localModel(name: "new:latest", sizeBytes: 4_000_000_000)
  let residentOther = OllamaPsModel(
    name: "old:latest", size: 5_000_000_000, sizeVram: 5_000_000_000,
    expiresAt: "2020-01-01T00:00:00Z")
  let client = FakeOllamaAPIClient(
    modelsResult: .success([newModel]), runningModelsResult: .success([residentOther]))
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: #"{"summary":"ok"}"#, done: true)
  }
  var configuration = OllamaConfiguration()
  // 5GB resident + 4GB new model exceeds this; evicting the 5GB resident
  // model makes the 4GB new model fit.
  configuration.maxResidentModelBytes = 6_000_000_000
  let adapter = try makeAdapter(
    configuration: configuration, policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let result = try await adapter.summarize(
    prompt: "x", actor: .agentOllama, sessionID: UUID(), correlationID: UUID(), causationID: UUID())
  #expect(result.degraded == false)
  #expect(await client.unloadedModels == ["old:latest"])
}

@Test
func ollamaAdapterDegradesWhenModelStillExceedsBudgetAfterEvictingEverything() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaBudgetTooLarge"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let hugeModel = OllamaTestFixtures.localModel(name: "huge:latest", sizeBytes: 20_000_000_000)
  let client = FakeOllamaAPIClient(
    modelsResult: .success([hugeModel]), runningModelsResult: .success([]))
  var configuration = OllamaConfiguration()
  configuration.maxResidentModelBytes = 1_000_000_000
  let adapter = try makeAdapter(
    configuration: configuration, policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let result = try await adapter.summarize(
    prompt: "x", actor: .agentOllama, sessionID: UUID(), correlationID: UUID(), causationID: UUID(),
    deterministicFallback: { _ in "fallback summary" })
  #expect(result.degraded)
  #expect(result.text == "fallback summary")
  #expect(await client.generateCallCount == 0)
}

@Test
func ollamaAdapterAllowsColdLoadWhenDiskSizeExceedsBudgetButEstimatedResidentSizeFits() async throws
{
  // Reproduces the real gemma4:latest coldstart rejection from
  // EV-R2-20260803-OLLAMA-LIVE-BENCHMARK-01 and EV-R2-20260803-REAL-DESKTOP-SESSION-01:
  // 9.6 GB on-disk size against a 6 GB budget used to be rejected outright,
  // even though the real resident footprint (~3.2 GB, ~0.33x disk size) fits
  // comfortably. At the default 0.5 estimatedResidentMemoryRatio, the
  // estimated footprint (4.8 GB) must fit under the 6 GB budget with no
  // eviction needed.
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaColdstartDiskVram"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let gemma4 = OllamaTestFixtures.localModel(name: "gemma4:latest", sizeBytes: 9_600_000_000)
  let client = FakeOllamaAPIClient(
    modelsResult: .success([gemma4]), runningModelsResult: .success([]))
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: #"{"summary":"ok"}"#, done: true)
  }
  var configuration = OllamaConfiguration()
  configuration.maxResidentModelBytes = 6_000_000_000
  let adapter = try makeAdapter(
    configuration: configuration, policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let result = try await adapter.summarize(
    prompt: "x", actor: .agentOllama, sessionID: UUID(), correlationID: UUID(), causationID: UUID())
  #expect(result.degraded == false)
  #expect(await client.unloadedModels.isEmpty)
}

@Test
func ollamaAdapterSkipsBudgetCheckWhenModelAlreadyResident() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaAlreadyResident"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let model = OllamaTestFixtures.localModel(name: "gemma4:latest", sizeBytes: 9_000_000_000)
  let resident = OllamaPsModel(
    name: "gemma4:latest", size: 9_000_000_000, sizeVram: 9_000_000_000,
    expiresAt: "2099-01-01T00:00:00Z")
  let client = FakeOllamaAPIClient(
    modelsResult: .success([model]), runningModelsResult: .success([resident]))
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: #"{"summary":"ok"}"#, done: true)
  }
  var configuration = OllamaConfiguration()
  configuration.maxResidentModelBytes = 1_000_000_000  // smaller than the resident model itself
  let adapter = try makeAdapter(
    configuration: configuration, policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let result = try await adapter.summarize(
    prompt: "x", actor: .agentOllama, sessionID: UUID(), correlationID: UUID(), causationID: UUID())
  #expect(result.degraded == false)
  #expect(await client.unloadedModels.isEmpty)
}

// MARK: - Reasoning (free-form, no structured validation)

@Test
func ollamaAdapterReasonReturnsFreeFormText() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaReasonOK"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = succeedingClassifyClient()
  await client.setGenerateHandler { model, _, format, _ in
    #expect(format == nil)
    return OllamaGenerateResponse(
      model: model, response: "because of Rayleigh scattering", done: true, evalCount: 5)
  }
  let adapter = try makeAdapter(policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let result = try await adapter.reason(
    prompt: "why is the sky blue", actor: .agentOllama, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(result.text == "because of Rayleigh scattering")
  #expect(result.degraded == false)
}

// MARK: - Health check event

@Test
func ollamaAdapterHealthCheckReturnsTrueOnSuccess() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "ollamaHealthOK"))
  let policyEngine = try await makeOllamaPolicyEngine(eventBus: bus)
  let client = FakeOllamaAPIClient(healthResult: .success(OllamaVersionResponse(version: "0.32.3")))
  let adapter = try makeAdapter(policyEngine: policyEngine, apiClient: client, eventBus: bus)

  let healthy = await adapter.healthCheck(
    actor: .agentOllama, correlationID: UUID(), causationID: UUID())
  #expect(healthy)
}
