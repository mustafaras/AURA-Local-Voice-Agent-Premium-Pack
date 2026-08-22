import AVFoundation
import Foundation

/// Deterministic pseudo-random source.
///
/// Seeded explicitly so a noisy-band regression is reproducible: the same
/// utterance always gets the same noise realization, so a WER change between
/// two runs is a recognizer/pipeline change and never a different dice roll.
struct SeededGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    // Avoid the zero state, which is a fixed point for xorshift.
    self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
  }

  mutating func nextUniform() -> Double {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return Double(state >> 11) / Double(1 << 53)
  }

  /// Box-Muller normal sample; used for additive white Gaussian noise.
  mutating func nextGaussian() -> Double {
    let u1 = max(nextUniform(), .leastNormalMagnitude)
    let u2 = nextUniform()
    return (-2.0 * log(u1)).squareRoot() * cos(2.0 * .pi * u2)
  }
}

enum AudioConditioning {
  /// Signal-to-noise ratio used for the noisy band.
  static let noisySNRdB: Double = 10.0
  /// Direct-path attenuation used for the far-field band (~ -12 dB).
  static let farFieldGain: Float = 0.25
  /// Reflection delay in seconds, roughly a 10 m path difference.
  static let farFieldReflectionDelaySeconds: Double = 0.030
  static let farFieldReflectionGain: Float = 0.35

  static func apply(
    _ condition: AcousticCondition,
    to samples: [Float],
    sampleRate: Double,
    seed: UInt64
  ) -> [Float] {
    switch condition {
    case .clean:
      return samples
    case .noisy:
      return addWhiteNoise(to: samples, snrDB: noisySNRdB, seed: seed)
    case .farField:
      return simulateFarField(samples, sampleRate: sampleRate)
    }
  }

  /// Additive white Gaussian noise at a target SNR relative to signal RMS.
  static func addWhiteNoise(to samples: [Float], snrDB: Double, seed: UInt64) -> [Float] {
    let signalPower = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(max(samples.count, 1))
    guard signalPower > 0 else { return samples }
    let noisePower = signalPower / pow(10.0, snrDB / 10.0)
    let noiseAmplitude = noisePower.squareRoot()

    var generator = SeededGenerator(seed: seed)
    return samples.map { sample in
      let noisy = Double(sample) + generator.nextGaussian() * noiseAmplitude
      return Float(max(-1.0, min(1.0, noisy)))
    }
  }

  /// Crude far-field emulation: attenuate the direct path, add a single
  /// delayed reflection, and low-pass to mimic air/distance rolloff.
  ///
  /// This is deliberately simple. A convolution with a measured room impulse
  /// response would be more faithful, but no consented room recording is
  /// available and fabricating one would make the number less honest, not more.
  static func simulateFarField(_ samples: [Float], sampleRate: Double) -> [Float] {
    let delaySamples = Int(farFieldReflectionDelaySeconds * sampleRate)
    var output = [Float](repeating: 0, count: samples.count)

    for index in 0..<samples.count {
      var value = samples[index] * farFieldGain
      let reflectionIndex = index - delaySamples
      if reflectionIndex >= 0 {
        value += samples[reflectionIndex] * farFieldGain * farFieldReflectionGain
      }
      output[index] = value
    }

    return lowPass(output, windowSize: 3)
  }

  /// Moving-average low-pass. Window of 3 at 16 kHz rolls off the top octave
  /// without destroying the formants the recognizer needs.
  static func lowPass(_ samples: [Float], windowSize: Int) -> [Float] {
    guard windowSize > 1, samples.count > windowSize else { return samples }
    var output = samples
    var accumulator: Float = 0
    for index in 0..<samples.count {
      accumulator += samples[index]
      if index >= windowSize {
        accumulator -= samples[index - windowSize]
      }
      let divisor = Float(min(index + 1, windowSize))
      output[index] = accumulator / divisor
    }
    return output
  }

  /// Synthesize `text` with a system voice at the engine's native capture
  /// format. `say`'s `LEF32@16000` matches the capture format exactly, so the
  /// harness introduces no resampling of its own.
  static func synthesize(text: String, voice: String) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("aura-sp016-\(UUID().uuidString).wav")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = ["-v", voice, "--data-format=LEF32@16000", "-o", url.path, text]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw ProbeError.synthesisFailed(voice: voice, status: process.terminationStatus)
    }
    return url
  }

  static func decodeMonoFloatSamples(at url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
    else { throw ProbeError.decodeFailed }
    try file.read(into: buffer)
    guard let channel = buffer.floatChannelData?[0] else { throw ProbeError.decodeFailed }
    return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
  }
}

enum ProbeError: Error, CustomStringConvertible {
  case synthesisFailed(voice: String, status: Int32)
  case decodeFailed
  case speechNotAuthorized(status: String)
  case engineUnavailable(locale: String, detail: String)

  var description: String {
    switch self {
    case .synthesisFailed(let voice, let status):
      return "say failed for voice \(voice) with status \(status)"
    case .decodeFailed:
      return "could not decode synthesized audio"
    case .speechNotAuthorized(let status):
      return "speech recognition not authorized (status: \(status))"
    case .engineUnavailable(let locale, let detail):
      return "STT engine unavailable for \(locale): \(detail)"
    }
  }
}
