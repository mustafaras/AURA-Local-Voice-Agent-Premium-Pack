import Foundation

/// Emitted when the audio service stops capturing.
public struct AudioCaptureStoppedEvent: EventPayload {
  public static let eventType = "audio.capture.stopped"

  public let reason: String
  public let totalFrames: UInt64

  public init(reason: String, totalFrames: UInt64) {
    self.reason = reason
    self.totalFrames = totalFrames
  }
}
