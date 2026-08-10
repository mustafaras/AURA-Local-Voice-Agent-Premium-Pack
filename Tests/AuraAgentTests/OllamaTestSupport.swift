import AuraAgent
import AuraCore
import Foundation

/// Shared, deterministic `OllamaAPIClient` test double used across
/// `Ollama*Tests.swift` — no test makes a real network call. `internal`
/// (not `private`) so every Ollama test file in this target can use one
/// definition rather than duplicating it.
actor FakeOllamaAPIClient: OllamaAPIClient {
  private var healthResult: Result<OllamaVersionResponse, Error>
  private var modelsResult: Result<[OllamaTagsModel], Error>
  private var runningModelsResult: Result<[OllamaPsModel], Error>
  private var generateHandler:
    (@Sendable (String, String, OllamaFormatSchema?, Double) throws -> OllamaGenerateResponse)?
  private(set) var unloadedModels: [String] = []
  private(set) var generateCallCount = 0

  init(
    healthResult: Result<OllamaVersionResponse, Error> = .success(
      OllamaVersionResponse(version: "0.32.3")),
    modelsResult: Result<[OllamaTagsModel], Error> = .success([]),
    runningModelsResult: Result<[OllamaPsModel], Error> = .success([])
  ) {
    self.healthResult = healthResult
    self.modelsResult = modelsResult
    self.runningModelsResult = runningModelsResult
  }

  func setHealth(_ result: Result<OllamaVersionResponse, Error>) {
    healthResult = result
  }

  func setModels(_ models: [OllamaTagsModel]) {
    modelsResult = .success(models)
  }

  func setRunningModels(_ models: [OllamaPsModel]) {
    runningModelsResult = .success(models)
  }

  func setGenerateHandler(
    _ handler:
      @escaping @Sendable (String, String, OllamaFormatSchema?, Double) throws ->
      OllamaGenerateResponse
  ) {
    generateHandler = handler
  }

  func health() async throws -> OllamaVersionResponse {
    try healthResult.get()
  }

  func listModels() async throws -> [OllamaTagsModel] {
    try modelsResult.get()
  }

  func listRunningModels() async throws -> [OllamaPsModel] {
    try runningModelsResult.get()
  }

  func generate(
    model: String, prompt: String, format: OllamaFormatSchema?, keepAliveSeconds: Double
  ) async throws -> OllamaGenerateResponse {
    generateCallCount += 1
    guard let generateHandler else {
      throw AuraError.ollamaError("FakeOllamaAPIClient: no generate handler configured")
    }
    return try generateHandler(model, prompt, format, keepAliveSeconds)
  }

  func unload(model: String) async throws {
    unloadedModels.append(model)
    runningModelsResult = runningModelsResult.map { models in
      models.filter { $0.name != model }
    }
  }
}

/// Convenience constructors for real-shaped, synthetic registry entries —
/// field values mirror what was actually observed in
/// `Fixtures/ollama_tags_real.json`, not invented shapes.
enum OllamaTestFixtures {
  // Deliberately well under `OllamaConfiguration.maxResidentModelBytes`'s
  // 6 GB default — tests that specifically exercise the memory-budget path
  // pass their own explicit `sizeBytes` (e.g. the real ~9.6 GB gemma4 size)
  // rather than relying on this default.
  static func localModel(
    name: String = "gemma4:latest",
    sizeBytes: UInt64 = 2_000_000_000,
    capabilities: [String] = ["completion", "tools", "thinking"]
  ) -> OllamaTagsModel {
    OllamaTagsModel(
      name: name,
      remoteHost: nil,
      size: sizeBytes,
      details: OllamaTagsModel.Details(
        family: "gemma4", parameterSize: "8.0B", quantizationLevel: "Q4_K_M", contextLength: nil),
      capabilities: capabilities
    )
  }

  static func cloudModel(
    name: String = "minimax-m3:cloud",
    capabilities: [String] = ["completion", "tools", "thinking", "vision"]
  ) -> OllamaTagsModel {
    OllamaTagsModel(
      name: name,
      remoteHost: "https://ollama.com:443",
      size: 362,
      details: OllamaTagsModel.Details(
        family: "minimax-m3", parameterSize: nil, quantizationLevel: nil, contextLength: 524288),
      capabilities: capabilities
    )
  }
}
