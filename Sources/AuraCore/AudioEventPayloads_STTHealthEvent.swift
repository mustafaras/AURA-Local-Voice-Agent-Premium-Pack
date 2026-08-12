import Foundation

/// Emitted when the STT engine health changes or is polled.
public struct STTHealthEvent: EventPayload {
  public static let eventType = "stt.health"

  public let ready: Bool
  public let status: String
  public let detail: String
  public let turnContext: TurnContext?

  public init(
    ready: Bool,
    status: String,
    detail: String,
    turnContext: TurnContext? = nil
  ) {
    self.ready = ready
    self.status = status
    self.detail = detail
    self.turnContext = turnContext
  }
}
