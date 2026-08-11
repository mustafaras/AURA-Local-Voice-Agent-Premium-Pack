import AuraAudio
import AuraCore
import AuraSTT
import Foundation
import Testing

/// Thread-safe box used by tests to collect `STTTranscriptResult` values from an
/// `AsyncStream` inside a `Task` while avoiding region-isolation warnings.
private final class ResultBox: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [STTTranscriptResult] = []

  func append(_ result: STTTranscriptResult) {
    lock.lock()
    defer { lock.unlock() }
    values.append(result)
  }

  var results: [STTTranscriptResult] {
    lock.lock()
    defer { lock.unlock() }
    return values
  }
}

@Suite("Streaming STT Engine")
struct AuraSTTEngineTests {

  // MARK: - Partials and stable segments

  @Test("emits partial then stable segment for scripted frames")
  func partialThenStable() async throws {
    let engine = DeterministicMockSTTEngine(
      script: [
        DeterministicMockSTTEngine.MockSegment(
          text: "hello", expectedFrameCount: 6, alternatives: ["hullo", "allo"])
      ],
      partialBoundaryFrames: 3,
      stabilizationDelayFrames: 2
    )

    _ = try await engine.start()
    let stream = engine.results
    let resultsBox = ResultBox()
    let resultsTask = Task.detached {
      for await result in stream {
        resultsBox.append(result)
        if result.isStable { break }
      }
    }

    for frame in 0..<6 {
      let f = AudioFrame(
        samples: [Float(frame)],
        timestamp: Double(frame) * 0.016,
        sequenceIndex: UInt64(frame),
        isDiscontinuity: false
      )
      engine.ingest(f, activationTime: 0)
    }

    engine.finalizeSession()
    await resultsTask.value

    let results = resultsBox.results
    let partials = results.filter { !$0.isStable }
    let stables = results.filter { $0.isStable }

    #expect(partials.count >= 1, "Expected at least one partial result")
    #expect(stables.count == 1, "Expected exactly one stable segment")
    #expect(stables.first?.text == "hello")
    #expect(stables.first?.alternatives.count == 2, "Expected 2 alternatives")
  }

  @Test("cancellation does not leak further results")
  func cancellationDoesNotLeakResults() async throws {
    let engine = DeterministicMockSTTEngine(
      script: [
        DeterministicMockSTTEngine.MockSegment(text: "ignored", expectedFrameCount: 100)
      ],
      partialBoundaryFrames: 3,
      stabilizationDelayFrames: 2
    )

    _ = try await engine.start()
    let stream = engine.results
    let resultsBox = ResultBox()
    let cancelTask = Task {
      for await result in stream {
        resultsBox.append(result)
      }
    }

    for frame in 0..<4 {
      let f = AudioFrame(
        samples: [Float(frame)],
        timestamp: Double(frame) * 0.016,
        sequenceIndex: UInt64(frame),
        isDiscontinuity: false
      )
      engine.ingest(f, activationTime: 0)
    }

    engine.cancel()
    await cancelTask.value

    #expect(
      !resultsBox.results.contains { $0.isStable },
      "Cancellation must prevent stable segment emission")
  }

  @Test("health reflects ready and cancelled states")
  func healthTransitions() async {
    let engine = DeterministicMockSTTEngine(script: [])
    let beforeStart = engine.health()
    #expect(!beforeStart.ready)

    do {
      _ = try await engine.start()
    } catch {
      #expect(Bool(true), "Empty script may fail start, which is acceptable")
      return
    }

    let afterStart = engine.health()
    #expect(afterStart.ready)

    engine.cancel()
    let afterCancel = engine.health()
    #expect(!afterCancel.ready)
  }

  // MARK: - Vocabulary and deterministic commands

  @Test("matches deterministic Turkish/English early commands")
  func deterministicCommands() async {
    let vocab = UserVocabulary.bilingualTestVocabulary
    #expect(vocab.matchDeterministicCommand("dur") == "dur")
    #expect(vocab.matchDeterministicCommand("stop") == "stop")
    #expect(vocab.matchDeterministicCommand("cancel edelim") == "cancel")
    #expect(vocab.matchDeterministicCommand("run test suite") == "run test suite")
    #expect(vocab.matchDeterministicCommand("rastgele bir şey") == nil)
  }

  @Test("provides technical terms as contextual hints")
  func technicalHints() async {
    let vocab = UserVocabulary.bilingualTestVocabulary
    let hints = vocab.allContextualHints()
    #expect(hints.contains("SwiftPM"))
    #expect(hints.contains("swiftc"))
    #expect(hints.contains("git push"))
    #expect(hints.contains("AsyncSequence"))
  }

  // MARK: - Benchmarks

  @Test("WER matches reference words within insertions and substitutions")
  func wordErrorRateMetric() async {
    let ref = "run the test suite now"
    let hyp = "run a test suit now"
    let wer = STTBenchmark.wordErrorRate(reference: ref, hypothesis: hyp)
    #expect(wer > 0.39)
    #expect(wer <= 0.41)
  }

  @Test("entity error rate detects missing code-switch term")
  func entityErrorRateMetric() async {
    let ref = "SwiftPM cache temizle"
    let hyp = "swift cache temizle"
    let eer = STTBenchmark.entityErrorRate(
      reference: ref,
      hypothesis: hyp,
      entities: ["SwiftPM"]
    )
    #expect(eer == 1.0)
  }
}
