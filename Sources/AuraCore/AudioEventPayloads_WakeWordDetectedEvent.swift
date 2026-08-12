import Foundation

/// Emitted when a wake-word detection passes thresholds and debounce.
public struct WakeWordDetectedEvent: EventPayload {
  public static let eventType = "audio.wake.detected"

  public let confidence: Double
  public let matchedPhrase: String
  public let preRollFrames: UInt64

  public init(confidence: Double, matchedPhrase: String, preRollFrames: UInt64) {
    self.confidence = confidence
    self.matchedPhrase = matchedPhrase
    self.preRollFrames = preRollFrames
  }
}
