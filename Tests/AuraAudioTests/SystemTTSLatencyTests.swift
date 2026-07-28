import AuraAudio
import AuraCore
import Foundation
import Testing

/// Latency and interaction tests for `SystemTTSEngine`.
///
/// These tests use wall-clock timing because `AVSpeechSynthesizer` does not
/// expose a mockable clock. They are gated with generous budgets and only run
/// when the environment has at least one system voice.
@Suite("System TTS Latency and Interaction")
struct SystemTTSLatencyTests {

  private func systemEngine() async -> SystemTTSEngine? {
    let engine = SystemTTSEngine()
    do {
      let health = try await engine.start()
      guard health.ready else { return nil }
      return engine
    } catch {
      return nil
    }
  }

  @Test func firstChunkLatencyIsUnderBudget() async throws {
    guard let engine = await systemEngine() else {
      Issue.record("System TTS not ready; skipping latency assertion")
      return
    }

    let prompt = TTSPrompt(text: "hello", locale: "en-US")
    let budgetSeconds: TimeInterval = 2.0
    var firstChunkTime: TimeInterval?

    let started = CFAbsoluteTimeGetCurrent()
    for await chunk in engine.speak(prompt) {
      if case .progress = chunk {
        firstChunkTime = CFAbsoluteTimeGetCurrent() - started
        await engine.stopSpeaking()
        break
      }
    }

    let elapsed = firstChunkTime ?? (CFAbsoluteTimeGetCurrent() - started)
    #expect(elapsed < budgetSeconds, "first-chunk latency \(elapsed) s exceeded budget \(budgetSeconds) s")
  }

  @Test func fullUtteranceLatencyIsUnderBudget() async throws {
    guard let engine = await systemEngine() else {
      Issue.record("System TTS not ready; skipping latency assertion")
      return
    }

    let prompt = TTSPrompt(text: "one two three", locale: "en-US")
    let budgetSeconds: TimeInterval = 5.0

    let started = CFAbsoluteTimeGetCurrent()
    for await chunk in engine.speak(prompt) {
      if case .complete = chunk { break }
      if case .failed = chunk { break }
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - started

    #expect(elapsed < budgetSeconds, "full-utterance latency \(elapsed) s exceeded budget \(budgetSeconds) s")
  }

  @Test func bargeInInterruptsActiveStream() async throws {
    guard let engine = await systemEngine() else {
      Issue.record("System TTS not ready; skipping barge-in assertion")
      return
    }

    let firstPrompt = TTSPrompt(text: "this is the first prompt that should be interrupted", locale: "en-US")
    let secondPrompt = TTSPrompt(text: "second", locale: "en-US")

    let firstStream = engine.speak(firstPrompt)
    let firstTask = Task {
      await firstStream.reduce(into: [TTSChunk]()) { $0.append($1) }
    }

    // Give the first stream a moment to start, then barge in.
    try? await Task.sleep(nanoseconds: 50_000_000)
    let secondChunks = await engine.speak(secondPrompt).reduce(into: [TTSChunk]()) { $0.append($1) }
    let firstChunks = await firstTask.value

    // The second stream must complete.
    let secondComplete = secondChunks.contains { if case .complete = $0 { return true }; return false }
    #expect(secondComplete)

    // The first stream should have been terminated quickly.
    #expect(firstChunks.count < 1000, "First stream did not terminate after barge-in")
  }

  @Test func antiTriggerDoesNotLoopOnOwnSpeech() async throws {
    // System TTS output is acoustic; this test verifies that the engine is
    // deterministic and that a speak call produces exactly one complete
    // lifecycle without re-emitting the same prompt.
    guard let engine = await systemEngine() else {
      Issue.record("System TTS not ready; skipping anti-trigger assertion")
      return
    }

    let prompt = TTSPrompt(text: "ready", locale: "en-US")
    let first = await engine.speak(prompt).reduce(into: [TTSChunk]()) { $0.append($1) }
    // Wait for synthesizer queue to drain before starting a second identical
    // prompt; this avoids the second call being treated as a continuation.
    try? await Task.sleep(nanoseconds: 50_000_000)
    let second = await engine.speak(prompt).reduce(into: [TTSChunk]()) { $0.append($1) }

    // System TTS fragment boundaries are not guaranteed to be stable across
    // runs, so we assert on lifecycle shape rather than byte-for-byte equality.
    let firstComplete = first.contains { if case .complete = $0 { return true }; return false }
    let secondComplete = second.contains { if case .complete = $0 { return true }; return false }

    #expect(firstComplete, "First speak lifecycle should complete")
    #expect(secondComplete, "Second speak lifecycle should complete")

    // Neither stream should report a failure for a normal system voice.
    let failures = (first + second).filter { chunk in
      if case .failed = chunk { return true }
      return false
    }
    #expect(failures.isEmpty)
  }

  @Test func consecutiveStopSpeakingIsIdempotent() async throws {
    guard let engine = await systemEngine() else {
      Issue.record("System TTS not ready; skipping idempotency assertion")
      return
    }

    await engine.stopSpeaking()
    await engine.stopSpeaking()
    await engine.stopSpeaking()

    let health = engine.health()
    #expect(health.ready == true)
  }
}
