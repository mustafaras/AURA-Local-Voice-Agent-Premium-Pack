import Foundation

/// Emitted when the privacy-visible indicator state changes.
public struct AudioIndicatorEvent: EventPayload {
  public static let eventType = "audio.indicator"

  public let isActive: Bool

  public init(isActive: Bool) {
    self.isActive = isActive
  }
}
