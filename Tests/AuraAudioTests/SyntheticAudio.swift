import AuraAudio
import AuraCore
import Foundation

/// Deterministic synthetic audio generator for Phase 2 wake-word/VAD tests.
///
/// Signals are generated offline and never touch the microphone, so tests can
/// run in CI and still exercise the audio pipeline logic.
enum SyntheticAudio {
  /// Sample rate used by the synthetic generator and the default AURA config.
  static let sampleRate: Double = 16_000

  /// Generate `count` frames of silence at the given frame length.
  static func silence(
    frameLength: Int = 512,
    frameCount: Int,
    startingSequence: UInt64 = 0
  ) -> [AudioFrame] {
    var frames: [AudioFrame] = []
    frames.reserveCapacity(frameCount)
    for index in 0..<frameCount {
      frames.append(
        AudioFrame(
          samples: Array(repeating: Float(0), count: frameLength),
          timestamp: Double(index) * Double(frameLength) / sampleRate,
          sequenceIndex: startingSequence + UInt64(index),
          isDiscontinuity: false
        )
      )
    }
    return frames
  }

  /// Generate a sine tone at `frequency` Hz with the given peak amplitude,
  /// optionally preceded and followed by silence.
  static func toneBurst(
    frequency: Double,
    amplitude: Float,
    frameLength: Int = 512,
    burstFrames: Int,
    leadingSilenceFrames: Int = 0,
    trailingSilenceFrames: Int = 0,
    startingSequence: UInt64 = 0
  ) -> [AudioFrame] {
    var frames: [AudioFrame] = []
    let totalFrames = leadingSilenceFrames + burstFrames + trailingSilenceFrames
    frames.reserveCapacity(totalFrames)

    let angularFrequency = 2.0 * .pi * frequency / sampleRate

    for frameIndex in 0..<totalFrames {
      var samples = [Float](repeating: 0, count: frameLength)
      let isBurst =
        frameIndex >= leadingSilenceFrames && frameIndex < leadingSilenceFrames + burstFrames
      if isBurst {
        let globalOffset = frameIndex * frameLength
        for sampleIndex in 0..<frameLength {
          let samplePosition = Double(globalOffset + sampleIndex)
          samples[sampleIndex] = Float(sin(samplePosition * angularFrequency)) * amplitude
        }
      }
      frames.append(
        AudioFrame(
          samples: samples,
          timestamp: Double(frameIndex) * Double(frameLength) / sampleRate,
          sequenceIndex: startingSequence + UInt64(frameIndex),
          isDiscontinuity: false
        )
      )
    }

    return frames
  }

  /// Generate an intermittent tone pattern (speech-like) with random
  /// amplitude variation. Uses a deterministic seed so tests are repeatable.
  static func intermittentTone(
    frequency: Double,
    baseAmplitude: Float,
    frameLength: Int = 512,
    totalFrames: Int,
    seed: UInt64 = 1
  ) -> [AudioFrame] {
    var generator = DeterministicNoiseGenerator(seed: seed)
    var frames: [AudioFrame] = []
    frames.reserveCapacity(totalFrames)
    let angularFrequency = 2.0 * .pi * frequency / sampleRate

    for frameIndex in 0..<totalFrames {
      let isActive = generator.nextBool(probability: 0.3)
      let amplitude: Float =
        isActive ? baseAmplitude * Float(0.7 + 0.3 * generator.nextDouble()) : 0
      var samples = [Float](repeating: 0, count: frameLength)
      let globalOffset = frameIndex * frameLength
      for sampleIndex in 0..<frameLength {
        let samplePosition = Double(globalOffset + sampleIndex)
        samples[sampleIndex] = Float(sin(samplePosition * angularFrequency)) * amplitude
      }
      frames.append(
        AudioFrame(
          samples: samples,
          timestamp: Double(frameIndex) * Double(frameLength) / sampleRate,
          sequenceIndex: UInt64(frameIndex),
          isDiscontinuity: false
        )
      )
    }
    return frames
  }

  /// Generate `frameCount` frames of deterministic Gaussian-ish noise at the
  /// given RMS amplitude.
  static func noise(
    rmsAmplitude: Float,
    frameLength: Int = 512,
    frameCount: Int,
    seed: UInt64 = 42
  ) -> [AudioFrame] {
    var generator = DeterministicNoiseGenerator(seed: seed)
    var frames: [AudioFrame] = []
    frames.reserveCapacity(frameCount)
    for index in 0..<frameCount {
      var samples = [Float](repeating: 0, count: frameLength)
      for sampleIndex in 0..<frameLength {
        samples[sampleIndex] = generator.nextNormal() * rmsAmplitude
      }
      frames.append(
        AudioFrame(
          samples: samples,
          timestamp: Double(index) * Double(frameLength) / sampleRate,
          sequenceIndex: UInt64(index),
          isDiscontinuity: false
        )
      )
    }
    return frames
  }
}

/// Tiny deterministic pseudo-random generator for repeatable synthetic audio.
private struct DeterministicNoiseGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed
  }

  mutating func nextUInt64() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var mixedState = state
    mixedState = (mixedState ^ (mixedState >> 30)) &* 0xBF58_476D_1CE4_E5B9
    mixedState = (mixedState ^ (mixedState >> 27)) &* 0x94D0_49BB_1331_11EB
    return mixedState ^ (mixedState >> 31)
  }

  mutating func nextDouble() -> Double {
    Double(nextUInt64()) / Double(UInt64.max)
  }

  mutating func nextBool(probability: Double) -> Bool {
    nextDouble() < probability
  }

  /// Box-Muller transform, returns a standard normal sample.
  mutating func nextNormal() -> Float {
    let firstUniform = nextDouble()
    let secondUniform = nextDouble()
    let radius = sqrt(-2.0 * log(max(firstUniform, .leastNonzeroMagnitude)))
    let angle = 2.0 * .pi * secondUniform
    return Float(radius * cos(angle))
  }
}
