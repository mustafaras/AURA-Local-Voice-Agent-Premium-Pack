import AuraCore
import Foundation

/// Result of analyzing a single audio frame for voice activity.
public struct VADResult: Sendable, Equatable {
  public let isSpeech: Bool
  public let energyDB: Double
  public let noiseFloorDB: Double
  public let frameCount: UInt64

  public init(
    isSpeech: Bool,
    energyDB: Double,
    noiseFloorDB: Double,
    frameCount: UInt64
  ) {
    self.isSpeech = isSpeech
    self.energyDB = energyDB
    self.noiseFloorDB = noiseFloorDB
    self.frameCount = frameCount
  }
}

/// Abstract voice-activity detector. Implementations must be `Sendable` and
/// are expected to be cheap enough to run on a background actor, not inside the
/// real-time AVAudioEngine tap.
public protocol VoiceActivityDetector: Sendable {
  /// Process one frame and return the current VAD decision.
  @Sendable func analyze(_ frame: AudioFrame) -> VADResult

  /// Reset any internal state (e.g. after a wake activation or device change).
  @Sendable func reset()
}

/// Deterministic, energy-based VAD with a slow-moving adaptive noise floor.
///
/// This is intentionally simple: it keeps analysis off the realtime audio path,
/// supports reproducible synthetic tests, and provides a stable baseline that
/// more advanced detectors can replace via the `VoiceActivityDetector` protocol.
public actor EnergyVAD: VoiceActivityDetector {
  /// Smoothing factor for the exponential moving average noise floor.
  public let adaptationRate: Double
  /// Threshold offset above the adaptive noise floor (dB).
  public let thresholdOffsetDB: Double
  /// Number of consecutive silent frames before speech ends.
  public let silenceFrames: UInt32
  /// Hard lower bound on the noise floor to avoid tracking absolute silence.
  public let minimumNoiseFloorDB: Double

  public init(
    adaptationRate: Double = 0.05,
    thresholdOffsetDB: Double = 12.0,
    silenceFrames: UInt32 = 20,
    minimumNoiseFloorDB: Double = -80.0
  ) {
    self.adaptationRate = adaptationRate
    self.thresholdOffsetDB = thresholdOffsetDB
    self.silenceFrames = silenceFrames
    self.minimumNoiseFloorDB = minimumNoiseFloorDB
  }

  public nonisolated func analyze(_ frame: AudioFrame) -> VADResult {
    return lock.withLock {
      var energyDB = Self.energyDB(of: frame.samples)
      localFrameCount += 1

      // Update the adaptive noise floor only when the signal looks quiet.
      // Speech is assumed to exceed the current noise floor by a margin.
      let threshold = localNoiseFloorDB + thresholdOffsetDB
      let isSpeechNow = energyDB >= threshold

      if isSpeechNow {
        localSpeechCounter += 1
        localSilenceCounter = 0
      } else {
        localSilenceCounter += 1
        if localSilenceCounter >= silenceFrames {
          localSpeechCounter = 0
        }
      }

      let isActive = localSpeechCounter > 0

      if !isActive {
        let target = max(energyDB, minimumNoiseFloorDB)
        localNoiseFloorDB = (1 - adaptationRate) * localNoiseFloorDB + adaptationRate * target
        energyDB = localNoiseFloorDB
      }

      return VADResult(
        isSpeech: isActive,
        energyDB: energyDB,
        noiseFloorDB: localNoiseFloorDB,
        frameCount: localFrameCount
      )
    }
  }

  public nonisolated func reset() {
    lock.withLock {
      localNoiseFloorDB = -90.0
      localSpeechCounter = 0
      localSilenceCounter = 0
      localFrameCount = 0
    }
  }

  private let lock = NSLock()
  nonisolated(unsafe) private var localNoiseFloorDB: Double = -90.0
  nonisolated(unsafe) private var localSpeechCounter: UInt32 = 0
  nonisolated(unsafe) private var localSilenceCounter: UInt32 = 0
  nonisolated(unsafe) private var localFrameCount: UInt64 = 0

  /// Compute root-mean-square energy and convert to dBFS.
  private static func energyDB(of samples: [Float]) -> Double {
    guard !samples.isEmpty else { return -120.0 }
    var sum: Float = 0
    for sample in samples {
      sum += sample * sample
    }
    let mean = sum / Float(samples.count)
    guard mean > 0 else { return -120.0 }
    return 10.0 * log10(Double(mean))
  }
}
