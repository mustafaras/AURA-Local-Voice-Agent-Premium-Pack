import AVFoundation
import AuraCore
import Foundation
import Testing

@testable import AuraAudio

/// Unit tests for the on-device macOS System TTS fallback adapter.
///
/// These tests avoid making audible sound by keeping prompts short and
/// by interrupting synthesis where the framework permits. They verify the
/// public `TTSEngine` contract: start, speak, stop, pause/resume, and health.
/// Speech callbacks require an explicit user-present opt-in via
/// `AURA_ENABLE_SYSTEM_TTS_LIVE_TESTS=1`; installed voices alone do not prove
/// that a headless host can drive `AVSpeechSynthesizer`.
@Suite("System TTS Engine")
struct SystemTTSEngineTests {

  @Test func startReportsReadyWhenVoicesExist() async throws {
    let engine = SystemTTSEngine()
    let health = try await engine.start()
    #expect(health.ready == true)
    #expect(health.status == "ready")
    #expect(health.detail.contains("System TTS"))
  }

  @Test func healthAfterStartIsReady() async throws {
    let engine = SystemTTSEngine()
    _ = try await engine.start()
    let health = engine.health()
    #expect(health.ready == true)
    #expect(health.status == "ready")
  }

  @Test func speakEmitsProgressAndComplete() async throws {
    guard liveSystemTTSTestsAreEnabled() else { return }
    let engine = SystemTTSEngine()
    _ = try await engine.start()

    let prompt = TTSPrompt(text: "hi", locale: "en-US", rate: 1.0, emphasis: 0.0)
    let chunks = await engine.speak(prompt).reduce(into: [TTSChunk]()) { $0.append($1) }

    let progressChunks = chunks.compactMap { chunk -> TTSChunk? in
      if case .progress = chunk { return chunk }
      return nil
    }
    #expect(!progressChunks.isEmpty, "Expected at least one progress chunk")

    let completeFound = chunks.contains { chunk in
      if case .complete = chunk { return true }
      return false
    }
    #expect(completeFound, "Expected a complete chunk")
  }

  @Test func stopSpeakingInterruptsStream() async throws {
    guard liveSystemTTSTestsAreEnabled() else { return }
    let engine = SystemTTSEngine()
    _ = try await engine.start()

    let prompt = TTSPrompt(text: "this is a longer phrase to speak", locale: "en-US")
    let stream = engine.speak(prompt)

    // Consume concurrently while interrupting.
    let collectTask = Task {
      await stream.reduce(into: [TTSChunk]()) { $0.append($1) }
    }

    await engine.stopSpeaking()
    let chunks = await collectTask.value

    // The stream should terminate promptly; no infinite wait occurred.
    #expect(chunks.count < 1000, "Stream did not terminate after stopSpeaking")
  }

  @Test func pauseAndResumeAreIdempotent() async throws {
    guard liveSystemTTSTestsAreEnabled() else { return }
    let engine = SystemTTSEngine()
    _ = try await engine.start()
    await engine.pauseSpeaking()
    await engine.resumeSpeaking()
    let health = engine.health()
    #expect(health.ready == true)
  }

  @Test func engineIDIsSystem() {
    let engine = SystemTTSEngine()
    #expect(engine.engineID == "system")
  }

  @Test func normalMultiplierMapsToPlatformDefaultRate() {
    #expect(
      SystemTTSEngine.systemRate(forMultiplier: 1.0)
        == AVSpeechUtteranceDefaultSpeechRate)
    #expect(
      SystemTTSEngine.systemRate(forMultiplier: 0.5)
        < SystemTTSEngine.systemRate(forMultiplier: 1.0))
    #expect(
      SystemTTSEngine.systemRate(forMultiplier: 2.0)
        > SystemTTSEngine.systemRate(forMultiplier: 1.0))
  }

  @Test func bestTurkishVoiceUsesHighestInstalledQuality() {
    let voices = AVSpeechSynthesisVoice.speechVoices().filter {
      $0.language.replacingOccurrences(of: "_", with: "-").lowercased() == "tr-tr"
    }
    guard !voices.isEmpty else { return }

    let selected = SystemTTSEngine.bestVoice(for: "tr-TR", voices: voices)
    #expect(selected != nil)
    #expect(selected?.quality.rawValue == voices.map(\.quality.rawValue).max())
  }

  @Test func explicitPreferredVoiceOverridesQualityRanking() {
    let voices = AVSpeechSynthesisVoice.speechVoices()
    // The premium neural Kaan voice is the product's configured fallback.
    let kaanID = "com.apple.ttsbundle.gryphon-neural_Kaan_tr-TR_premium"
    guard voices.contains(where: { $0.identifier == kaanID }) else { return }

    let selected = SystemTTSEngine.bestVoice(
      for: "tr-TR",
      preferredIdentifier: kaanID,
      voices: voices)

    #expect(selected?.identifier == kaanID)
  }
}

private func liveSystemTTSTestsAreEnabled() -> Bool {
  ProcessInfo.processInfo.environment["AURA_ENABLE_SYSTEM_TTS_LIVE_TESTS"] == "1"
}
