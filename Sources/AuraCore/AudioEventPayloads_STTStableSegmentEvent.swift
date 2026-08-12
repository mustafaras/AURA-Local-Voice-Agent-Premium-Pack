import Foundation

/// Emitted when a transcript segment stabilizes and becomes available for
/// downstream intent processing (subject to policy authorization).
public struct STTStableSegmentEvent: EventPayload {
  public static let eventType = "stt.segment.stable"

  public let text: String
  public let alternatives: [STTAlternative]
  public let confidence: Double

  /// If the stable segment matched a deterministic early-command, this is
  /// the canonical command string. Nil otherwise.
  public let deterministicCommand: String?
  public let turnContext: TurnContext?

  public init(
    text: String,
    alternatives: [STTAlternative] = [],
    confidence: Double,
    deterministicCommand: String? = nil,
    turnContext: TurnContext? = nil
  ) {
    self.text = text
    self.alternatives = alternatives
    self.confidence = confidence
    self.deterministicCommand = deterministicCommand
    self.turnContext = turnContext
  }
}
