import Foundation

/// Emitted when the conversation state machine detects that the user has gone
/// silent for too long while listening or that an engine has exceeded its budget.
public struct ConversationTimeoutEvent: EventPayload {
  public static let eventType = "conversation.timeout"

  public let stateAtTimeout: ConversationState
  public let timeoutKind: String

  public init(stateAtTimeout: ConversationState, timeoutKind: String) {
    self.stateAtTimeout = stateAtTimeout
    self.timeoutKind = timeoutKind
  }
}
