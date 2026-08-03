import AuraCore
import Foundation

/// Sends a schema-constrained `/api/generate` request and independently
/// re-validates the response before it is trusted.
///
/// Ollama's `format` parameter constrains generation server-side (verified:
/// a real request with `format: {"type":"object","properties":
/// {"classification":{"type":"string","enum":["urgent","normal"]}}, ...}`
/// produced exactly `{"classification":"urgent"}`), but AGENTS.md's "no raw
/// model output may become an executable action" applies regardless of how
/// well-behaved the observed case was — this is defense-in-depth, not
/// distrust of a specific documented Ollama gap. Every response is decoded
/// into a concrete typed struct and, for classification, independently
/// re-checked against the caller's own label set rather than trusting the
/// server-side `enum` constraint alone.
public enum OllamaStructuredRequest {
  public static func classify(
    apiClient: any OllamaAPIClient,
    model: String,
    prompt: String,
    labels: [String],
    keepAliveSeconds: Double
  ) async throws(AuraError) -> OllamaClassificationResult {
    guard !labels.isEmpty else {
      throw AuraError.ollamaError("classify requires at least one label")
    }
    let raw = try await callGenerate(
      apiClient: apiClient, model: model, prompt: prompt,
      format: .classification(labels: labels), keepAliveSeconds: keepAliveSeconds)
    let decoded: OllamaClassificationResult = try decode(raw.response, typeName: "OllamaClassificationResult")
    guard labels.contains(decoded.classification) else {
      throw AuraError.ollamaError(
        "model returned classification '\(decoded.classification)' outside the requested label set \(labels)"
      )
    }
    return decoded
  }

  public static func summarize(
    apiClient: any OllamaAPIClient,
    model: String,
    prompt: String,
    keepAliveSeconds: Double
  ) async throws(AuraError) -> OllamaSummaryResult {
    let raw = try await callGenerate(
      apiClient: apiClient, model: model, prompt: prompt, format: .summary,
      keepAliveSeconds: keepAliveSeconds)
    return try decode(raw.response, typeName: "OllamaSummaryResult")
  }

  public static func propose(
    apiClient: any OllamaAPIClient,
    model: String,
    prompt: String,
    keepAliveSeconds: Double
  ) async throws(AuraError) -> OllamaNLUResult {
    let raw = try await callGenerate(
      apiClient: apiClient, model: model, prompt: prompt, format: .nlu,
      keepAliveSeconds: keepAliveSeconds)
    return try decode(raw.response, typeName: "OllamaNLUResult")
  }

  private static func callGenerate(
    apiClient: any OllamaAPIClient,
    model: String,
    prompt: String,
    format: OllamaFormatSchema,
    keepAliveSeconds: Double
  ) async throws(AuraError) -> OllamaGenerateResponse {
    do {
      return try await apiClient.generate(
        model: model, prompt: prompt, format: format, keepAliveSeconds: keepAliveSeconds)
    } catch let error as AuraError {
      throw error
    } catch {
      throw AuraError.ollamaError("generate failed: \(error)")
    }
  }

  private static func decode<T: Decodable>(_ text: String, typeName: String) throws(AuraError) -> T {
    guard let data = text.data(using: .utf8) else {
      throw AuraError.ollamaError("\(typeName): response was not valid UTF-8")
    }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw AuraError.ollamaError("\(typeName): failed to decode structured response: \(error)")
    }
  }
}
