import AuraAudio
import AuraCore
import AuraSTT
import Foundation
import Speech
import Testing

/// Unit tests for the native Speech.framework streaming STT adapter.
///
/// These tests avoid requiring microphone access or actual Speech.framework
/// recognition. They exercise authorization-failure paths, health reporting,
/// result mapping helpers (via the public interface), and cancellation. Tests
/// that depend on `SFSpeechRecognizer.authorizationStatus()` are guarded by the
/// current authorization state so they remain deterministic in CI.
@Suite("Native Speech STT Engine")
struct SystemSTTEngineTests {

  // MARK: - Lifecycle and health

  @Test("health is idle before start")
  func healthIsIdleBeforeStart() {
    let engine = SystemSTTEngine(
      engineID: "native-speech-test",
      locale: Locale(identifier: "en-GB"),
      vocabulary: nil,
      enableCustomVocabulary: false
    )
    let health = engine.health()
    #expect(!health.ready)
    #expect(health.status == "idle")
  }

  @Test("start returns not authorized when speech recognition is not denied")
  func startReflectsAuthorizationState() async {
    let currentStatus = SFSpeechRecognizer.authorizationStatus()

    let engine = SystemSTTEngine(
      engineID: "native-speech-test",
      locale: Locale(identifier: "en-GB"),
      vocabulary: nil,
      enableCustomVocabulary: false
    )

    switch currentStatus {
    case .authorized:
      let health = try? await engine.start()
      #expect(health?.ready == true)
    case .denied, .restricted, .notDetermined:
      await #expect(throws: (any Error).self) {
        _ = try await engine.start()
      }
    @unknown default:
      await #expect(throws: (any Error).self) {
        _ = try await engine.start()
      }
    }
  }

  @Test("cancel moves health to cancelled without crashing")
  func cancelMovesHealthToCancelled() async {
    let engine = SystemSTTEngine(
      engineID: "native-speech-test",
      locale: Locale(identifier: "en-GB"),
      vocabulary: nil,
      enableCustomVocabulary: false
    )

    await engine.cancel()

    let health = engine.health()
    #expect(!health.ready)
    #expect(health.status == "cancelled")
  }

  @Test("cancel stops the session without emitting a stable result")
  func cancelStopsSessionWithoutStableResult() async {
    let engine = SystemSTTEngine(
      engineID: "native-speech-test",
      locale: Locale(identifier: "en-GB"),
      vocabulary: nil,
      enableCustomVocabulary: false
    )

    let box = ResultBox()
    let task = Task.detached {
      for await result in engine.results {
        box.append(result)
      }
    }

    // Give the subscription a moment to register before cancellation.
    try? await Task.sleep(nanoseconds: 10_000_000)
    await engine.cancel()
    task.cancel()
    await task.value

    #expect(box.results.isEmpty || box.results.allSatisfy { !$0.isStable })
  }

  // MARK: - Audio ingestion path

  @Test("ingest before start is safe when recognizer is unavailable")
  func ingestBeforeStartIsSafeWhenUnavailable() async {
    let engine = SystemSTTEngine(
      engineID: "native-speech-test",
      locale: Locale(identifier: "en-GB"),
      vocabulary: nil,
      enableCustomVocabulary: false
    )

    let box = ResultBox()
    let task = Task.detached {
      for await result in engine.results {
        box.append(result)
      }
    }

    let frame = AudioFrame(
      samples: Array(repeating: 0.0, count: 160),
      timestamp: 0,
      sequenceIndex: 0,
      isDiscontinuity: false
    )

    await engine.ingest(frame, activationTime: 0)

    // Allow the engine's MainActor dispatch to complete.
    try? await Task.sleep(nanoseconds: 100_000_000)
    await engine.cancel()
    task.cancel()
    await task.value

    // The only required invariant: the adapter does not crash or leak a
    // continuation. Whether an error result is emitted depends on the runtime
    // authorization status, which is not under test control.
    #expect(engine.health().status == "cancelled")
  }

  // MARK: - Vocabulary wiring

  @Test("vocabulary hints are accepted without crashing")
  func vocabularyHintsAcceptedWithoutCrashing() {
    let vocabulary = UserVocabulary.bilingualTestVocabulary
    let engine = SystemSTTEngine(
      engineID: "native-speech-test",
      locale: Locale(identifier: "tr-TR"),
      vocabulary: vocabulary,
      enableCustomVocabulary: true
    )

    let health = engine.health()
    #expect(health.status == "idle")
  }

  @Test("engineID and locale are exposed correctly")
  func engineIDAndLocaleAreExposed() {
    let engine = SystemSTTEngine(
      engineID: "native-speech-test",
      locale: Locale(identifier: "tr-TR"),
      vocabulary: nil,
      enableCustomVocabulary: false
    )

    #expect(engine.engineID == "native-speech-test")
    #expect(engine.locale.identifier == "tr-TR")
  }
}

// MARK: - Test helpers

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
