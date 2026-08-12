import Foundation

// MARK: - Audio capture event payloads

/// Emitted when the audio service has started capturing.
public struct AudioCaptureStartedEvent: EventPayload {
  public static let eventType = "audio.capture.started"

  public let deviceID: String?
  public let sampleRate: Double
  public let channelCount: UInt32

  public init(deviceID: String?, sampleRate: Double, channelCount: UInt32) {
    self.deviceID = deviceID
    self.sampleRate = sampleRate
    self.channelCount = channelCount
  }
}
