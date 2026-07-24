import Foundation

/// A single contiguous block of captured mono audio with timing metadata.
///
/// `buffer` is a copy of the audio data and is safe to pass across actors.
/// `timestamp` is a host-relative monotonic time in seconds; it is not an
/// absolute clock and must only be used for continuity and latency math.
public struct AudioFrame: Sendable, Equatable {
  /// Captured samples in the configured capture format (mono, float, 16 kHz by default).
  public let samples: [Float]

  /// Host monotonic time in seconds when the first sample in this frame was captured.
  public let timestamp: TimeInterval

  /// Sequential index of the frame; increments by one for each tap callback.
  public let sequenceIndex: UInt64

  /// True when a gap or overrun was detected before this frame.
  public let isDiscontinuity: Bool

  public init(
    samples: [Float],
    timestamp: TimeInterval,
    sequenceIndex: UInt64,
    isDiscontinuity: Bool = false
  ) {
    self.samples = samples
    self.timestamp = timestamp
    self.sequenceIndex = sequenceIndex
    self.isDiscontinuity = isDiscontinuity
  }
}
