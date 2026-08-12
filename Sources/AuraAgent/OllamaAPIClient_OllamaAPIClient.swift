import AuraCore
import AuraSecurity
import Foundation

/// Network seam for the Ollama local HTTP API, mirroring the
/// `AdapterProcessExecuting` seam used by the CLI-spawning adapters: a
/// protocol plus a production implementation, so tests never make a real
/// network call.
public protocol OllamaAPIClient: Sendable {
  func health() async throws -> OllamaVersionResponse
  func listModels() async throws -> [OllamaTagsModel]
  func listRunningModels() async throws -> [OllamaPsModel]
  func generate(
    model: String, prompt: String, format: OllamaFormatSchema?, keepAliveSeconds: Double
  ) async throws -> OllamaGenerateResponse
  /// Forces an immediate unload via `keep_alive: 0` — verified real
  /// behavior: the daemon evicts the model and returns `done_reason:
  /// "unload"` with an empty `response`.
  func unload(model: String) async throws
}
