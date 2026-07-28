import AuraAudio
import AuraCore
import Foundation
import Testing

/// Unit tests for the boundary-only Chatterbox TTS adapter.
///
/// The adapter does not contain model weights, so these tests exercise the
/// `TTSEngine` contract and the fail-closed readiness behavior.
@Suite("Chatterbox TTS Engine")
struct ChatterboxTTSEngineTests {

  @Test func engineIDIsChatterbox() {
    let engine = ChatterboxTTSEngine()
    #expect(engine.engineID == "chatterbox")
  }

  @Test func startReportsNotReadyByDefault() async throws {
    let engine = ChatterboxTTSEngine()
    let health = try await engine.start()
    #expect(health.ready == false)
    #expect(health.status == "not-ready")
    #expect(health.detail.contains("not configured"))
  }

  @Test func startReportsReadyWhenConfigured() async throws {
    let engine = ChatterboxTTSEngine(
      configuration: .init(helperPath: "/tmp/chatterbox-helper", modelPath: "/tmp/chatterbox-model"))
    let health = try await engine.start()
    #expect(health.ready == true)
    #expect(health.status == "ready")
    #expect(health.detail.contains("helper configured"))
  }

  @Test func healthReflectsConfiguration() {
    let unconfigured = ChatterboxTTSEngine()
    #expect(unconfigured.health().ready == false)

    let configured = ChatterboxTTSEngine(
      configuration: .init(helperPath: "/tmp/helper", modelPath: "/tmp/model"))
    #expect(configured.health().ready == true)
  }

  @Test func speakFailsWhenNotReady() async throws {
    let engine = ChatterboxTTSEngine()
    let prompt = TTSPrompt(text: "hello", locale: "en-US")
    let chunks = await engine.speak(prompt).reduce(into: [TTSChunk]()) { $0.append($1) }

    #expect(chunks.count == 2)
    if case .failed(let detail) = chunks.first {
      #expect(detail.contains("not ready"))
    } else {
      Issue.record("Expected first chunk to be .failed")
    }
    if case .complete = chunks.last {
      // Stream finishes after the failure marker.
    } else {
      Issue.record("Expected last chunk to be .complete")
    }
  }

  @Test func speakEmitsProgressAndCompleteWhenReady() async throws {
    let engine = ChatterboxTTSEngine(
      configuration: .init(helperPath: "/tmp/helper", modelPath: "/tmp/model"))
    let prompt = TTSPrompt(text: "hello world", locale: "en-US")
    let chunks = await engine.speak(prompt).reduce(into: [TTSChunk]()) { $0.append($1) }

    let progress = chunks.compactMap { chunk -> String? in
      if case .progress(let fragment, _) = chunk { return fragment }
      return nil
    }
    #expect(progress == ["hello", "world"])

    let completeFound = chunks.contains { chunk in
      if case .complete = chunk { return true }
      return false
    }
    #expect(completeFound)
  }

  @Test func stopSpeakingIsIdempotent() async throws {
    let engine = ChatterboxTTSEngine(
      configuration: .init(helperPath: "/tmp/helper", modelPath: "/tmp/model"))
    // Calling stop before/after a stream is safe and does not corrupt later
    // synthesis.
    await engine.stopSpeaking()
    let prompt = TTSPrompt(text: "stop safe", locale: "en-US")
    let chunks = await engine.speak(prompt).reduce(into: [TTSChunk]()) { $0.append($1) }
    await engine.stopSpeaking()

    let progress = chunks.compactMap { chunk -> String? in
      if case .progress(let fragment, _) = chunk { return fragment }
      return nil
    }
    #expect(progress == ["stop", "safe"])

    let completeFound = chunks.contains { chunk in
      if case .complete = chunk { return true }
      return false
    }
    #expect(completeFound)
  }

  @Test func pauseAndResumeAreIdempotent() async throws {
    let engine = ChatterboxTTSEngine()
    await engine.pauseSpeaking()
    await engine.resumeSpeaking()
    let health = engine.health()
    #expect(health.ready == false)
  }
}
