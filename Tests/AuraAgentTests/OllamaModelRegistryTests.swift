import AuraAgent
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
  let classificationRouted = await registry.route(capability: .classification, allowCloudModels: false)
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
