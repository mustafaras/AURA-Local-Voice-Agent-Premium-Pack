@testable import AuraAgent
import AuraCore
import Foundation
import Testing

private let ollamaTestActor = ActorID.agentOllama
private let ollamaTestSession = UUID()

@Test
func ollamaRegistryRefreshPopulatesModelsFromTags() async throws {
  let client = FakeOllamaAPIClient(
    modelsResult: .success([OllamaTestFixtures.localModel(), OllamaTestFixtures.cloudModel()]))
  let registry = OllamaModelRegistry(apiClient: client)

  let models = try await registry.refresh(
    actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())
  #expect(models.count == 2)
  #expect(await registry.models().count == 2)
}

@Test
func ollamaRegistryClassifiesLocalVsCloudFromRemoteHost() async throws {
  let client = FakeOllamaAPIClient(
    modelsResult: .success([OllamaTestFixtures.localModel(), OllamaTestFixtures.cloudModel()]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  let models = await registry.models()
  let local = try #require(models.first { $0.name == "gemma4:latest" })
  let cloud = try #require(models.first { $0.name == "minimax-m3:cloud" })
  #expect(local.isLocal)
  #expect(!cloud.isLocal)
}

@Test
func ollamaRegistryRoutesToSmallestLocalCompletionCapableModel() async throws {
  let small = OllamaTestFixtures.localModel(name: "small:latest", sizeBytes: 1_000_000_000)
  let large = OllamaTestFixtures.localModel(name: "large:latest", sizeBytes: 9_000_000_000)
  let client = FakeOllamaAPIClient(modelsResult: .success([large, small]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  let routed = await registry.route(capability: .classification, allowCloudModels: false)
  #expect(routed?.name == "small:latest")
}

@Test
func ollamaRegistryExcludesCloudModelsByDefault() async throws {
  let client = FakeOllamaAPIClient(modelsResult: .success([OllamaTestFixtures.cloudModel()]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  let routed = await registry.route(capability: .summarization, allowCloudModels: false)
  #expect(routed == nil)
}

@Test
func ollamaRegistryIncludesCloudModelsWhenExplicitlyAllowed() async throws {
  let client = FakeOllamaAPIClient(modelsResult: .success([OllamaTestFixtures.cloudModel()]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  let routed = await registry.route(capability: .summarization, allowCloudModels: true)
  #expect(routed?.name == "minimax-m3:cloud")
}

@Test
func ollamaRegistryPrefersThinkingCapableModelsForReasoning() async throws {
  let noThinking = OllamaTestFixtures.localModel(
    name: "plain:latest", sizeBytes: 500_000_000, capabilities: ["completion"])
  let thinking = OllamaTestFixtures.localModel(
    name: "thinker:latest", sizeBytes: 9_000_000_000, capabilities: ["completion", "thinking"])
  let client = FakeOllamaAPIClient(modelsResult: .success([noThinking, thinking]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  // Without the reasoning preference, the smaller non-thinking model wins.
  let classificationRouted = await registry.route(
    capability: .classification, allowCloudModels: false)
  #expect(classificationRouted?.name == "plain:latest")

  // For reasoning, the thinking-capable model is preferred even though larger.
  let reasoningRouted = await registry.route(capability: .reasoning, allowCloudModels: false)
  #expect(reasoningRouted?.name == "thinker:latest")
}

@Test
func ollamaRegistryReturnsNilWhenNoCandidateSatisfiesCapability() async throws {
  let embeddingOnly = OllamaTagsModel(
    name: "embed:latest", remoteHost: nil, size: 100,
    details: OllamaTagsModel.Details(), capabilities: ["embedding"])
  let client = FakeOllamaAPIClient(modelsResult: .success([embeddingOnly]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  let routed = await registry.route(capability: .classification, allowCloudModels: false)
  #expect(routed == nil)
}

@Test
func ollamaRegistryModelsIsEmptyBeforeFirstRefresh() async {
  let client = FakeOllamaAPIClient()
  let registry = OllamaModelRegistry(apiClient: client)
  #expect(await registry.models().isEmpty)
}

// MARK: - Preferred-model pin

/// The hazard the pin exists for: `:cloud` entries report a placeholder size
/// of a few hundred bytes, so "smallest `sizeBytes`" resolves to a cloud model
/// even when a multi-gigabyte local model is registered and eligible. Routing
/// silently leaves the device on a size rule that was written to protect
/// memory. Pinned here so the behaviour can never change unnoticed.
@Test
func ollamaRegistrySizeRuleResolvesToCloudBecauseCloudReportsPlaceholderSize() async throws {
  let local = OllamaTestFixtures.localModel(name: "granite4.2:8b", sizeBytes: 5_347_929_166)
  let cloud = OllamaTestFixtures.cloudModel(name: "glm-5.3:cloud")
  let client = FakeOllamaAPIClient(modelsResult: .success([local, cloud]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  let routed = await registry.route(capability: .reasoning, allowCloudModels: true)
  #expect(routed?.name == "glm-5.3:cloud")
  #expect(routed?.isLocal == false)
}

@Test
func ollamaRegistryHonorsPreferredModelOverTheSizeRule() async throws {
  // `glm-5.3:cloud` reports the smaller placeholder, so the size rule would
  // take it; the pin names the flash variant instead.
  let smallest = OllamaTestFixtures.cloudModel(name: "glm-5.3:cloud")
  let pinned = OllamaTestFixtures.cloudModel(name: "glm-5.3-flash:cloud")
  let client = FakeOllamaAPIClient(modelsResult: .success([smallest, pinned]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  let routed = await registry.route(
    capability: .reasoning, allowCloudModels: true, preferredModel: "glm-5.3-flash:cloud")
  #expect(routed?.name == "glm-5.3-flash:cloud")
}

@Test
func ollamaRegistryFallsBackToTheSizeRuleWhenThePinnedModelIsNotRegistered() async throws {
  let small = OllamaTestFixtures.localModel(name: "small:latest", sizeBytes: 1_000_000_000)
  let large = OllamaTestFixtures.localModel(name: "large:latest", sizeBytes: 9_000_000_000)
  let client = FakeOllamaAPIClient(modelsResult: .success([large, small]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  // A pin naming a model this host does not have must degrade to the
  // heuristic, never to "no model" — a stale pin cannot take the assistant
  // offline.
  let routed = await registry.route(
    capability: .classification, allowCloudModels: false,
    preferredModel: "a-model-this-host-does-not-have:cloud")
  #expect(routed?.name == "small:latest")
}

/// The invariant that makes the pin safe: it selects *within* what policy
/// already permits. Pinning a cloud model while cloud routing is forbidden
/// must select the local model, never the pin.
@Test
func ollamaRegistryPreferredModelCannotBypassTheCloudPolicy() async throws {
  let local = OllamaTestFixtures.localModel(name: "granite4.2:8b", sizeBytes: 5_347_929_166)
  let cloud = OllamaTestFixtures.cloudModel(name: "glm-5.3-flash:cloud")
  let client = FakeOllamaAPIClient(modelsResult: .success([local, cloud]))
  let registry = OllamaModelRegistry(apiClient: client)
  _ = try await registry.refresh(actor: ollamaTestActor, correlationID: UUID(), causationID: UUID())

  let routed = await registry.route(
    capability: .reasoning, allowCloudModels: false,
    preferredModel: "glm-5.3-flash:cloud")
  #expect(routed?.name == "granite4.2:8b")
  #expect(routed?.isLocal == true)
}

@Test
func ollamaConfigurationPinsTheFlashCloudModelByDefault() {
  #expect(OllamaConfiguration().preferredModel == "glm-5.3-flash:cloud")
  // An explicitly empty pin survives merging: it means "route by capability",
  // not "value missing".
  var cleared = OllamaConfiguration()
  cleared.preferredModel = ""
  #expect(cleared.mergedWithDefaults().preferredModel == "")
}

// MARK: - Generation knobs (token budget / reasoning effort)

@Test
func ollamaFreeTextRequestsCarryTheBudgetAndReasoningEffort() {
  let knobs = URLSessionOllamaAPIClient.generationKnobs(
    isSchemaConstrained: false, responseTokenBudget: 4096, thinkingEffort: "low")
  #expect(knobs.numPredict == 4096)
  #expect(knobs.think == "low")
}

/// The invariant: a schema-constrained request keeps the shape it has always
/// sent. A token cap that truncates a JSON document produces an unparseable
/// answer, which is a worse failure than a long one.
@Test
func ollamaSchemaConstrainedRequestsCarryNeitherKnob() {
  let knobs = URLSessionOllamaAPIClient.generationKnobs(
    isSchemaConstrained: true, responseTokenBudget: 4096, thinkingEffort: "low")
  #expect(knobs.numPredict == nil)
  #expect(knobs.think == nil)
}

@Test
func ollamaZeroBudgetAndEmptyEffortOmitBothFields() {
  let knobs = URLSessionOllamaAPIClient.generationKnobs(
    isSchemaConstrained: false, responseTokenBudget: 0, thinkingEffort: "")
  #expect(knobs.numPredict == nil)
  #expect(knobs.think == nil)
}

@Test
func ollamaConfigurationDefaultsToABudgetedLowEffortAnswer() {
  let config = OllamaConfiguration()
  #expect(config.responseTokenBudget == 4096)
  // Measured: leaving reasoning on spends the whole budget on a `thinking`
  // field AURA never reads and returns an empty answer.
  #expect(config.thinkingEffort == "low")
}
