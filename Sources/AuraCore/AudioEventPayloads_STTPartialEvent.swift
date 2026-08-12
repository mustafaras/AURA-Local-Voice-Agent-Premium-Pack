import Foundation

// MARK: - Streaming STT event payloads

/// Emitted for each volatile partial transcript. Display-only; not authorized
/// for intent execution.
public struct STTPartialEvent: EventPayload {
  public static let eventType = "stt.partial"

  public let text: String
  public let confidence: Double
  public let turnContext: TurnContext?

  public init(text: String, confidence: Double, turnContext: TurnContext? = nil) {
    self.text = text
    self.confidence = confidence
    self.turnContext = turnContext
  }
}
