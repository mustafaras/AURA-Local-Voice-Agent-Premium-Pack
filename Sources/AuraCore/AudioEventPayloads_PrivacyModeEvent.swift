import Foundation

/// Emitted when privacy mode toggles.
public struct PrivacyModeEvent: EventPayload {
  public static let eventType = "privacy.mode.changed"

  public let enabled: Bool
  public let triggeredByKeyboardShortcut: Bool

  public init(enabled: Bool, triggeredByKeyboardShortcut: Bool) {
    self.enabled = enabled
    self.triggeredByKeyboardShortcut = triggeredByKeyboardShortcut
  }
}
