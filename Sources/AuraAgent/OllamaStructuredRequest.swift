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
    let decoded: OllamaClassificationResult = try decode(
      raw.response, typeName: "OllamaClassificationResult")
    guard labels.contains(decoded.classification) else {
      throw AuraError.ollamaError(
        "model returned classification '\(decoded.classification)' outside the "
          + "requested label set \(labels)"
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
    let decoded: OllamaNLUResult
    do {
      decoded = try decode(raw.response, typeName: "OllamaNLUResult")
    } catch {
      // Defense-in-depth: some local models ignore the JSON schema and emit
      // prose around the object. Try to recover the first valid JSON object.
      guard let recovered = extractFirstNLUObject(from: raw.response) else {
        throw error
      }
      decoded = recovered
    }
    // Normalize fields defensively; even well-formed JSON may contain word
    // confidences ("high"/"medium"/"low") or invented capability ids.
    let normalized = OllamaNLUResult(
      dialogueAct: normalizeEnum(decoded.dialogueAct, default: "answer"),
      language: normalizeLanguage(decoded.language, default: "unknown"),
      capabilityID: sanitizeCapabilityID(dialogueAct: decoded.dialogueAct, capabilityID: decoded.capabilityID),
      confidence: normalizeConfidence(decoded.confidence),
      ambiguityReason: decoded.ambiguityReason)
    return normalized
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

  private static func decode<T: Decodable>(
    _ text: String,
    typeName: String
  ) throws(AuraError) -> T {
    guard let data = text.data(using: .utf8) else {
      throw AuraError.ollamaError("\(typeName): response was not valid UTF-8")
    }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw AuraError.ollamaError("\(typeName): failed to decode structured response: \(error)")
    }
  }

  /// Recover a structured NLU result from a response that wraps an otherwise
  /// *complete* JSON object in prose or trailing garbage.
  ///
  /// This is repair within a strict bounded budget, not guessing. Scavenging
  /// individual fields out of free prose and defaulting whatever is missing
  /// was tried and removed: it manufactured a confident-looking result from
  /// text that never contained one, which is exactly what R2 forbids
  /// ("Validate every local-model response … never guess an executable
  /// plan"). A response that does not carry every schema-required field must
  /// fail closed so the caller keeps its deterministic classification.
  private static func extractFirstNLUObject(from text: String) -> OllamaNLUResult? {
    extractBalancedNLUObject(from: text)
  }

  private static func extractBalancedNLUObject(from text: String) -> OllamaNLUResult? {
    guard let start = text.firstIndex(of: "{"),
      let end = findMatchingBrace(in: text, start: start)
    else { return nil }
    let json = String(text[start...end])
    guard let data = json.data(using: .utf8) else { return nil }

    struct LooseNLU: Decodable {
      let dialogueAct: String?
      let language: String?
      let capabilityID: String?
      let confidence: String?
      let ambiguityReason: String?

      enum CodingKeys: String, CodingKey {
        case dialogueAct = "dialogue_act"
        case language
        case capabilityID = "capability_id"
        case confidence
        case ambiguityReason = "ambiguity_reason"
      }
    }

    guard let loose = try? JSONDecoder().decode(LooseNLU.self, from: data) else { return nil }
    // Every field the `.nlu` format schema marks required must actually be
    // present. Defaulting an absent field would invent a dialogue act,
    // language, or confidence the model never produced.
    guard let dialogueAct = loose.dialogueAct,
      let language = loose.language,
      let capabilityID = loose.capabilityID,
      let confidence = loose.confidence,
      let ambiguityReason = loose.ambiguityReason
    else { return nil }
    return OllamaNLUResult(
      dialogueAct: normalizeEnum(dialogueAct, default: "answer"),
      language: normalizeLanguage(language, default: "unknown"),
      capabilityID: capabilityID,
      confidence: normalizeConfidence(confidence),
      ambiguityReason: ambiguityReason)
  }

  /// Strip any invented capability id when the dialogue act is not an
  /// executable action. This keeps the typed safety gate
  /// `dialogueAct == .answer && capabilityID == nil` true for conversation.
  private static func sanitizeCapabilityID(dialogueAct: String, capabilityID: String?) -> String {
    let nonExecutableActs: Set<String> = ["answer", "clarify", "cancel"]
    guard nonExecutableActs.contains(dialogueAct.lowercased()) else {
      return capabilityID ?? ""
    }
    return ""
  }

  private static func findMatchingBrace(in text: String, start: String.Index) -> String.Index? {
    var depth = 0
    var index = start
    while index < text.endIndex {
      let char = text[index]
      if char == "{" { depth += 1 }
      else if char == "}" { depth -= 1 }
      if depth == 0 { return index }
      text.formIndex(after: &index)
    }
    return nil
  }

  private static func normalizeEnum(_ raw: String?, default defaultValue: String) -> String {
    guard let raw = raw else { return defaultValue }
    var trimmed = raw.lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    // Some models emit the enum value buried in a short prose prefix/suffix;
    // strip known detritus and take the first remaining known token.
    let allowed: Set<String> = ["answer", "execute", "clarify", "confirm", "delegate", "cancel"]
    let tokens = trimmed
      .components(separatedBy: CharacterSet.whitespaces.union(.punctuationCharacters))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    for token in tokens {
      if allowed.contains(token) { return token }
    }
    return defaultValue
  }

  private static func normalizeLanguage(_ raw: String?, default defaultValue: String) -> String {
    guard let raw = raw else { return defaultValue }
    var trimmed = raw.lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let allowed: Set<String> = ["turkish", "english", "mixed", "unknown"]
    let tokens = trimmed
      .components(separatedBy: CharacterSet.whitespaces.union(.punctuationCharacters))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    for token in tokens {
      if allowed.contains(token) { return token }
    }
    return defaultValue
  }

  private static func normalizeConfidence(_ raw: String?) -> String {
    guard let raw = raw else { return "0.5" }
    let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return "0.5" }
    // If the model emits a word like "high"/"medium"/"low", map it to a
    // conservative numeric token so downstream typed parsing can proceed.
    switch cleaned.lowercased() {
    case "high": return "0.85"
    case "medium": return "0.6"
    case "low": return "0.35"
    default: break
    }
    // Prose may leak into the numeric field; keep only the first numeric
    // token so typed parsing succeeds. Default to 0.5 when nothing is recoverable.
    guard let regex = try? NSRegularExpression(
      pattern: #"[0-9]*\.?[0-9]+"#, options: []) else { return "0.5" }
    let range = NSRange(cleaned.startIndex..., in: cleaned)
    guard let match = regex.firstMatch(in: cleaned, options: [], range: range),
      let swiftRange = Range(match.range, in: cleaned),
      let value = Double(String(cleaned[swiftRange]))
    else { return "0.5" }
    let clamped = min(max(value, 0), 1)
    return String(clamped)
  }
}
