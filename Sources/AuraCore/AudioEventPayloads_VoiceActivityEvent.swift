import Foundation

// MARK: - Wake word / VAD event payloads

/// Emitted when voice activity is detected or has ended.
public struct VoiceActivityEvent: EventPayload {
  public static let eventType = "audio.vad.activity"

  /// True when speech begins, false when the configured silence budget expires.
  public let isActive: Bool

  /// Estimated signal energy in dBFS.
  public let energyDB: Double

  /// Number of frames that contributed to the decision.
  public let frameCount: UInt64

  public init(isActive: Bool, energyDB: Double, frameCount: UInt64) {
    self.isActive = isActive
    self.energyDB = energyDB
    self.frameCount = frameCount
  }
}
