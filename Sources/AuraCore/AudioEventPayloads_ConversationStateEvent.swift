import Foundation

// MARK: - Conversation state payloads

/// Emitted whenever the conversation state machine changes state. Used by UI
/// for status display and by the orchestrator for coordination.
public struct ConversationStateEvent: EventPayload {
  public static let eventType = "conversation.state"

  public let state: ConversationState
  public let previousState: ConversationState?
  public let reason: String

  public init(
    state: ConversationState,
    previousState: ConversationState? = nil,
    reason: String = ""
  ) {
    self.state = state
    self.previousState = previousState
    self.reason = reason
  }
}
