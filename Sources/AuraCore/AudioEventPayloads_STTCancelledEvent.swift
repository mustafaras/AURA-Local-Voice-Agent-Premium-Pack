import Foundation

/// Emitted when an STT session is cancelled.
public struct STTCancelledEvent: EventPayload {
  public static let eventType = "stt.cancelled"
  public let turnContext: TurnContext?

  public init(turnContext: TurnContext? = nil) {
    self.turnContext = turnContext
  }
}
