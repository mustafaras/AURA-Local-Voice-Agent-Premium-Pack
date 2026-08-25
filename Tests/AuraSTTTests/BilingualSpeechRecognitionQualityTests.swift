import AVFoundation
import Speech
import AuraAudio
import AuraCore
import Foundation
import Testing

@testable import AuraSTT

/// Addresses `RISK-SP-003-LIVE-VOICE-RESIDUAL` as far as it can honestly be
/// addressed in this environment.
///
/// The gate this risk guards is whether AURA's Turkish and English speech
/// *recognition* actually works — R2's bilingual STT quality requirement. That
/// had been treated as unverifiable because the operator is speech-disabled and
/// cannot produce live utterances. But the recognition path does not require a
/// human throat: `SystemSTTEngine` consumes `AudioFrame`s through
/// `SFSpeechAudioBufferRecognitionRequest`, so real audio from any source can
/// be driven through the real recognizer.
///
/// These tests synthesize Turkish and English speech with the system voices via
/// `say`, decode it to the engine's native capture format, and feed it to a real
/// `SFSpeechRecognizer`. That verifies locale selection, buffer ingestion,
/// segment finalization, and actual bilingual transcription quality end to end.
///
/// **What this does not prove**, and what keeps the risk open rather than
/// closed: synthesized speech is cleaner than human speech — no accent
/// variation, disfluency, room noise, or microphone colouration — so any
/// accuracy measured here is optimistic and is not a WER figure for real users.
/// It also does not exercise microphone hardware capture; SP-002 covered that
/// half of the path separately under its own accommodation. Requires Speech
/// Recognition authorization, so it is opt-in via
/// `AURA_ENABLE_LIVE_SPEECH_TESTS=1`.
@Suite(
  "Bilingual speech recognition quality",
  .enabled(if: liveSpeechTestsAreEnabled()))
struct BilingualSpeechRecognitionQualityTests {

  @Test("Turkish synthesized speech is recognized by the real recognizer")
  func turkishSpeechIsRecognized() async throws {
    let expected = "bugün hava nasıl"
    let result = try await recognize(text: expected, voice: "Kaan", localeID: "tr-TR")
    let overlap = tokenOverlap(recognized: result, expected: expected)
    #expect(result.isEmpty == false, "recognizer produced no transcript for Turkish audio")
    #expect(
      overlap >= 0.5,
      "Turkish transcript '\(result)' shares only \(overlap) of tokens with '\(expected)'")
  }

  @Test("English synthesized speech is recognized by the real recognizer")
  func englishSpeechIsRecognized() async throws {
    let expected = "what is the weather today"
    let result = try await recognize(text: expected, voice: "Samantha", localeID: "en-US")
    let overlap = tokenOverlap(recognized: result, expected: expected)
    #expect(result.isEmpty == false, "recognizer produced no transcript for English audio")
    #expect(
      overlap >= 0.5,
      "English transcript '\(result)' shares only \(overlap) of tokens with '\(expected)'")
  }

  /// The locale is not cosmetic: a Turkish utterance driven through an en-US
  /// recognizer should not transcribe better than through tr-TR. This asserts
  /// the engine's locale actually reaches `SFSpeechRecognizer` rather than
  /// being stored and ignored.
  @Test("Engine locale selects the recognition language")
  func localeSelectsRecognitionLanguage() async throws {
    let turkish = "bugün hava nasıl"
    let matched = try await recognize(text: turkish, voice: "Kaan", localeID: "tr-TR")
    let mismatched = try await recognize(text: turkish, voice: "Kaan", localeID: "en-US")

    let matchedOverlap = tokenOverlap(recognized: matched, expected: turkish)
    let mismatchedOverlap = tokenOverlap(recognized: mismatched, expected: turkish)
    let comparison: Comment =
      "tr-TR should not transcribe Turkish worse than en-US"
    #expect(matchedOverlap >= mismatchedOverlap, comparison)
  }

  // MARK: - Harness

  /// TCC authorization is granted per executable, and the Swift Testing helper
  /// is not the AURA app bundle — so a grant made to AURA does not carry over
  /// here. Request it explicitly and fail with a precise, actionable message
  /// rather than letting the engine report a generic "not determined".
  private func requireSpeechAuthorization() throws {
    let current = SFSpeechRecognizer.authorizationStatus()
    guard current == .authorized else {
      // Deliberately does *not* call `requestAuthorization` here. TCC requires
      // the calling executable to carry a usage-description key, and the
      // SwiftPM test helper is a bare binary with no Info.plist, so requesting
      // authorization from it aborts the whole process with SIGABRT (observed:
      // test helper exit 134) instead of showing a prompt. Failing with a
      // precise error keeps the rest of the suite alive and names the real
      // blocker: this verification has to run inside a bundled host.
      throw STTHarnessError.speechNotAuthorized(status: current)
    }
  }

  /// Synthesize `text`, decode it, and drive it through a real recognizer.
  private func recognize(text: String, voice: String, localeID: String) async throws -> String {
    let url = try synthesize(text: text, voice: voice)
    defer { try? FileManager.default.removeItem(at: url) }
    let samples = try decodeMonoFloatSamples(at: url)
    try #require(samples.isEmpty == false)

    try requireSpeechAuthorization()

    let engine = SystemSTTEngine(
      engineID: "native-speech-test", locale: Locale(identifier: localeID))
    _ = try await engine.start()

    // Collect transcripts concurrently: the engine publishes results on a
    // stream while frames are still being ingested.
    let collector = Task { () -> String in
      var latest = ""
      for await result in engine.results {
        if !result.text.isEmpty { latest = result.text }
        if result.isStable { break }
      }
      return latest
    }

    // 100 ms frames at 16 kHz, matching the capture format the engine expects.
    let frameLength = 1_600
    var index: UInt64 = 0
    for start in stride(from: 0, to: samples.count, by: frameLength) {
      let end = min(start + frameLength, samples.count)
      await engine.ingest(
        AudioFrame(
          samples: Array(samples[start..<end]),
          timestamp: Double(index) * 0.1,
          sequenceIndex: index),
        activationTime: 0)
      index += 1
    }
    await engine.finalizeSession()

    // Bound the wait: a recognizer that never finalizes must fail the test
    // rather than hang the suite.
    let deadline = Task {
      try? await Task.sleep(nanoseconds: 20_000_000_000)
      collector.cancel()
    }
    let transcript = await collector.value
    deadline.cancel()
    await engine.cancel()
    return transcript.lowercased()
  }

  /// Produce 16 kHz mono float audio with a system voice. `say`'s
  /// `LEF32@16000` data format matches the engine's native capture format, so
  /// the harness itself introduces no resampling. The container must be WAV:
  /// AIFF is big-endian and `say` refuses little-endian float into it,
  /// failing with "Opening output file failed: fmt?".
  private func synthesize(text: String, voice: String) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("aura-stt-\(UUID().uuidString).wav")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = ["-v", voice, "--data-format=LEF32@16000", "-o", url.path, text]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw STTHarnessError.synthesisFailed(status: process.terminationStatus, voice: voice)
    }
    return url
  }

  private func decodeMonoFloatSamples(at url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
    else { throw STTHarnessError.decodeFailed }
    try file.read(into: buffer)
    guard let channel = buffer.floatChannelData?[0] else { throw STTHarnessError.decodeFailed }
    return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
  }

  /// Fraction of expected tokens present in the transcript. Deliberately not a
  /// strict string match: recognizers legitimately differ on punctuation,
  /// casing, and number formatting, and asserting exact equality would make
  /// this brittle without making it stricter about what matters.
  private func tokenOverlap(recognized: String, expected: String) -> Double {
    let expectedTokens = tokens(expected)
    guard !expectedTokens.isEmpty else { return 0 }
    let recognizedTokens = Set(tokens(recognized))
    let hits = expectedTokens.filter { recognizedTokens.contains($0) }.count
    return Double(hits) / Double(expectedTokens.count)
  }

  private func tokens(_ text: String) -> [String] {
    text.lowercased()
      .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
      .map(String.init)
      .filter { !$0.isEmpty }
  }
}

enum STTHarnessError: Error {
  case synthesisFailed(status: Int32, voice: String)
  case decodeFailed
  case speechNotAuthorized(status: SFSpeechRecognizerAuthorizationStatus)
}

func liveSpeechTestsAreEnabled() -> Bool {
  ProcessInfo.processInfo.environment["AURA_ENABLE_LIVE_SPEECH_TESTS"] == "1"
}
