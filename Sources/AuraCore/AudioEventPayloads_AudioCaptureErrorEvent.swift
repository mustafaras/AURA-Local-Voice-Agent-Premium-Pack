import Foundation

/// Emitted when a capture or device error occurs.
public struct AudioCaptureErrorEvent: EventPayload {
  public static let eventType = "audio.capture.error"

  public let errorMessage: String
  public let recoverable: Bool

  public init(errorMessage: String, recoverable: Bool) {
    self.errorMessage = errorMessage
    self.recoverable = recoverable
  }
}
