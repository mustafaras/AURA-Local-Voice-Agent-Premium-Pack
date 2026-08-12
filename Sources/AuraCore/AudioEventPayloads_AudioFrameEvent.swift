import Foundation

/// Emitted for each captured frame after format conversion.
public struct AudioFrameEvent: EventPayload {
  public static let eventType = "audio.frame"

  /// Number of samples in the frame.
  public let sampleCount: Int

  /// Host monotonic timestamp of the first sample (seconds).
  public let timestamp: TimeInterval

  /// Sequence index of the frame since capture started.
  public let sequenceIndex: UInt64

  /// True if a discontinuity was detected before this frame.
  public let isDiscontinuity: Bool

  public init(
    sampleCount: Int,
    timestamp: TimeInterval,
    sequenceIndex: UInt64,
    isDiscontinuity: Bool = false
  ) {
    self.sampleCount = sampleCount
    self.timestamp = timestamp
    self.sequenceIndex = sequenceIndex
    self.isDiscontinuity = isDiscontinuity
  }
}
