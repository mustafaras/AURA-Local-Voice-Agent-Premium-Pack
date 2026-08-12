import Foundation

/// Emitted when the user barge-in (new speech while the assistant is speaking)
/// is detected and accepted. The downstream coordinator must stop TTS.
public struct BargeInEvent: EventPayload {
  public static let eventType = "conversation.bargein"

  public let atState: ConversationState
  public let reason: String

  public init(atState: ConversationState, reason: String) {
    self.atState = atState
    self.reason = reason
  }
}
