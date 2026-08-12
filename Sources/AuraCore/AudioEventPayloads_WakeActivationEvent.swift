import Foundation

/// Emitted when the system enters or leaves a listening activation.
public struct WakeActivationEvent: EventPayload {
  public static let eventType = "audio.wake.activation"

  public let isActive: Bool
  public let privacyMode: Bool
  public let turnContext: TurnContext?

  public init(
    isActive: Bool,
    privacyMode: Bool,
    turnContext: TurnContext? = nil
  ) {
    self.isActive = isActive
    self.privacyMode = privacyMode
    self.turnContext = turnContext
  }
}
