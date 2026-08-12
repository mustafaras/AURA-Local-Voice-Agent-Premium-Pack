import Foundation

/// Emitted when a wake-word detector hypothesizes a detection.
public struct WakeWordHypothesisEvent: EventPayload {
  public static let eventType = "audio.wake.hypothesis"

  /// Detector-assigned confidence in [0, 1].
  public let confidence: Double

  /// Phrase that was matched (may differ from configured phrase for model-based detectors).
  public let matchedPhrase: String

  /// True if the detector flagged the hypothesis as self-triggered and suppressed.
  public let suppressedAsAntiTrigger: Bool

  public init(confidence: Double, matchedPhrase: String, suppressedAsAntiTrigger: Bool) {
    self.confidence = confidence
    self.matchedPhrase = matchedPhrase
    self.suppressedAsAntiTrigger = suppressedAsAntiTrigger
  }
}
