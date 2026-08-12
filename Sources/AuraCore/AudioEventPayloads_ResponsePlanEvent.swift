import Foundation

/// Emitted when the intent engine has produced a response plan and the TTS
/// queue is about to be scheduled. Carries a non-executable summary for UI.
public struct ResponsePlanEvent: EventPayload {
  public static let eventType = "conversation.response.plan"

  public let planID: String
  public let summary: String
  public let hasSpokenResponse: Bool

  /// True when the plan is the result of a local, no-remote-model intent
  /// (e.g. `appActivate`, `appTerminate`, or `shellExecute`). `Conversation`
  /// uses this flag to decide whether the current turn qualifies for the
  /// simple-command completion latency budget.
  public let isSimpleCommand: Bool
  public let language: DialogueLanguage?
  public let turnContext: TurnContext?

  public init(
    planID: String,
    summary: String,
    hasSpokenResponse: Bool,
    isSimpleCommand: Bool = false,
    language: DialogueLanguage? = nil,
    turnContext: TurnContext? = nil
  ) {
    self.planID = planID
    self.summary = summary
    self.hasSpokenResponse = hasSpokenResponse
    self.isSimpleCommand = isSimpleCommand
    self.language = language
    self.turnContext = turnContext
  }
}
