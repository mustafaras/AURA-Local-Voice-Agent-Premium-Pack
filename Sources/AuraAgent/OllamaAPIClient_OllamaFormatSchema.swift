import AuraCore
import AuraSecurity
import Foundation

/// A narrow, purpose-built JSON Schema representation covering exactly the
/// shape verified to work against `/api/generate`'s `format` parameter — a
/// flat object with string/enum properties. This is not a general JSON
/// Schema DSL; AURA only ever asks Ollama to constrain output to the two
/// capability-shaped schemas below.
public struct OllamaFormatSchema: Codable, Sendable, Equatable {
  public let type: String
  public let properties: [String: Property]
  public let required: [String]

  public struct Property: Codable, Sendable, Equatable {
    public let type: String
    public let `enum`: [String]?

    public init(type: String, enum values: [String]? = nil) {
      self.type = type
      self.enum = values
    }
  }

  /// `{"classification": {"type": "string", "enum": labels}}`, required.
  /// Verified: this exact shape, sent as `format`, made a real local model
  /// return `{"classification": "urgent"}` for a two-label request.
  public static func classification(labels: [String]) -> OllamaFormatSchema {
    OllamaFormatSchema(
      type: "object",
      properties: ["classification": Property(type: "string", enum: labels)],
      required: ["classification"]
    )
  }

  /// `{"summary": {"type": "string"}}`, required.
  public static let summary = OllamaFormatSchema(
    type: "object",
    properties: ["summary": Property(type: "string")],
    required: ["summary"]
  )

  public static let nlu = OllamaFormatSchema(
    type: "object",
    properties: [
      "dialogue_act": Property(
        type: "string", enum: ["answer", "execute", "clarify", "confirm", "delegate", "cancel"]),
      "language": Property(type: "string", enum: ["turkish", "english", "mixed", "unknown"]),
      "capability_id": Property(type: "string"),
      "confidence": Property(type: "string"),
      "ambiguity_reason": Property(type: "string"),
    ],
    required: ["dialogue_act", "language", "capability_id", "confidence", "ambiguity_reason"]
  )
}
