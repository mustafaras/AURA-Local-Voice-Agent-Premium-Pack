import Foundation

/// Emitted when a user turn completes semantically, either because speech
/// ended and the STT segment is stable, or because a deterministic command was
/// matched. The payload carries enough context for the intent engine to begin
/// planning.
public struct TurnCompletedEvent: EventPayload {
  public static let eventType = "conversation.turn.completed"

  public let text: String
  public let confidence: Double
  public let isFinal: Bool
  public let deterministicCommand: String?
  public let requiresPolicyReview: Bool
  public let turnContext: TurnContext?

  public init(
    text: String,
    confidence: Double,
    isFinal: Bool,
    deterministicCommand: String? = nil,
    requiresPolicyReview: Bool = true,
    turnContext: TurnContext? = nil
  ) {
    self.text = text
    self.confidence = confidence
    self.isFinal = isFinal
    self.deterministicCommand = deterministicCommand
    self.requiresPolicyReview = requiresPolicyReview
    self.turnContext = turnContext
  }
}
