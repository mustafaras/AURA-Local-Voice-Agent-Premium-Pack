import AuraAudio
import AuraCore
import AuraSTT
import Foundation
import Testing

@testable import AURA

/// SP-016 (OPEN-08/R7) deterministic coverage for the R7-required *turn-end
/// latency* metric and the fail-closed invariant that a bad transcript never
/// becomes a successful command.
///
/// The R7/R2 evaluation protocol explicitly requires a "turn-end latency"
/// measurement. The production `STTPipeline` did not record one: its metrics
/// tracked first-partial and last-stable latency but never exposed the elapsed
/// time from activation to the first stable segment. This suite proves that
/// metric is recorded and reset per turn, and that a non-stable or error result
/// is never promoted into a stable (command-eligible) segment.
///
/// **Scope / authority:** edit-only, deterministic, no microphone, TCC, model,
/// provider, signing, release, or delivery action. The live bilingual
/// microphone/WER corpus and the hardware recovery matrix remain open R7 gates
/// owned by SP-016's live legs; this suite closes only the deterministic
/// metric/fail-closed slice.
@Suite("SP-016 turn-end latency and fail-closed transcript gating")
struct SP016TurnEndLatencyTests {

  @Test("turn-end latency records elapsed activation-to-stable time")
  func turnEndLatencyIsRecordedOnStableSegment() async throws {
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "sp016-metric"))
    let recorder = StableRecorder()
    await bus.subscribe(STTStableSegmentEvent.self) { envelope in
      await recorder.record(envelope.payload)
    }

    // Deterministic monotonic clock. The pipeline reads the clock at
    // activation, at the first partial, and at the stable result. Queue:
    // activation=100, partial=101.5, stable=103.5.
    let activation: TimeInterval = 100
    let clock = TickClock([100, 101.5, 103.5])

    let pipeline = STTPipeline(
      engine: DeterministicMockSTTEngine(
        engineID: "sp016-metric", locale: Locale(identifier: "tr-TR"),
        script: [.init(text: "bugün hava nasıl", expectedFrameCount: 6)],
        partialBoundaryFrames: 3, stabilizationDelayFrames: 2),
      vocabulary: UserVocabulary(),
      eventBus: bus,
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "sp016"),
      monotonicClock: { clock.next() },
      sessionID: UUID())
    try await pipeline.start()

    let context = TurnContext(
      sessionID: UUID(), activationSource: .pushToTalk, actor: .user,
      authority: .userUtterance, sensitivity: .sensitive, timingOrigin: activation)
    await bus.emit(
      EventEnvelope(
        correlationID: context.correlationID, causationID: context.causationID,
        actor: .user, sensitivity: .sensitive,
        payload: WakeActivationEvent(isActive: true, privacyMode: false, turnContext: context)))

    // Feed the frames that stabilize the deterministic engine, then finalize.
    for index in 0..<6 {
      await pipeline.ingestSampleFrame(
        AudioFrame(samples: [Float(index)], timestamp: Double(index), sequenceIndex: UInt64(index)))
    }
    await bus.emit(
      EventEnvelope(
        correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
        payload: WakeActivationEvent(isActive: false, privacyMode: false)))

    var attempts = 0
    while await recorder.stableCount < 1, attempts < 50 {
      try await Task.sleep(for: .milliseconds(10))
      attempts += 1
    }

    let metrics = await pipeline.currentMetrics()
    #expect(await recorder.stableCount == 1)
    // stable (103.5) - activation (100) = 3.5 seconds.
    #expect(metrics.turnEndLatencySeconds == 3.5)
    #expect(metrics.stableSegmentsEmitted == 1)
  }

  @Test("turn-end latency resets to zero at the start of a new turn")
  func turnEndMetricResetsAcrossTurns() async throws {
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "sp016-reset"))
    let recorder = StableRecorder()
    await bus.subscribe(STTStableSegmentEvent.self) { envelope in
      await recorder.record(envelope.payload)
    }

    // Two turns: turn1 activation 10/stable 12; turn2 activation 20/stable 21.
    let clock = TickClock([10, 12, 20, 21])
    let pipeline = STTPipeline(
      engine: DeterministicTurnSTEngine(),
      vocabulary: UserVocabulary(),
      eventBus: bus,
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "sp016-reset"),
      monotonicClock: { clock.next() },
      sessionID: UUID())
    try await pipeline.start()

    // First turn: activation -> stable.
    await driveOneTurn(pipeline, bus: bus, timingOrigin: 10)
    var attempts = 0
    while await recorder.stableCount < 1, attempts < 50 {
      try await Task.sleep(for: .milliseconds(10))
      attempts += 1
    }
    #expect(await pipeline.currentMetrics().turnEndLatencySeconds == 2)

    // Second turn: the metric resets to 0 until a new stable segment lands.
    await driveOneTurn(pipeline, bus: bus, timingOrigin: 20)
    attempts = 0
    while await recorder.stableCount < 2, attempts < 50 {
      try await Task.sleep(for: .milliseconds(10))
      attempts += 1
    }
    #expect(await recorder.stableCount == 2)
    #expect(await pipeline.currentMetrics().turnEndLatencySeconds == 1)
  }

  @Test("a non-stable or error result is never promoted to a stable command segment")
  func badTranscriptIsNeverPromotedToStable() async throws {
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "sp016-failclosed"))
    let recorder = StableRecorder()
    await bus.subscribe(STTStableSegmentEvent.self) { envelope in
      await recorder.record(envelope.payload)
    }

    // Engine that yields only a synthetic error transcript, never a genuine
    // stable segment.
    let pipeline = STTPipeline(
      engine: DeterministicTurnSTEngine(onlyError: true),
      vocabulary: UserVocabulary(),
      eventBus: bus,
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "sp016-failclosed"),
      monotonicClock: { 1 },
      sessionID: UUID())
    try await pipeline.start()

    let context = TurnContext(
      sessionID: UUID(), activationSource: .pushToTalk, actor: .user,
      authority: .userUtterance, sensitivity: .sensitive, timingOrigin: 1)
    await bus.emit(
      EventEnvelope(
        correlationID: context.correlationID, causationID: context.causationID,
        actor: .user, sensitivity: .sensitive,
        payload: WakeActivationEvent(isActive: true, privacyMode: false, turnContext: context)))
    await bus.emit(
      EventEnvelope(
        correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
        payload: WakeActivationEvent(isActive: false, privacyMode: false)))

    var attempts = 0
    while await recorder.stableCount == 0, attempts < 50 {
      try await Task.sleep(for: .milliseconds(10))
      attempts += 1
    }
    // No stable segment may be emitted from a non-stable/error transcript.
    #expect(await recorder.stableCount == 0)
  }
}

// MARK: - Deterministic helpers

private actor StableRecorder {
  private(set) var stableCount = 0
  private(set) var stableTexts: [String] = []

  func record(_ event: STTStableSegmentEvent) {
    stableCount += 1
    stableTexts.append(event.text)
  }
}

/// A monotonic-clock stub that returns queued values in order. The
/// STTPipeline invokes `monotonicClock()` once at activation and once when a
/// stable segment lands, so a two-value queue per turn yields a deterministic
/// latency.
private final class TickClock: @unchecked Sendable {
  private let lock = NSLock()
  private var queue: [TimeInterval]
  init(_ values: [TimeInterval]) {
    queue = values
  }
  func next() -> TimeInterval {
    lock.lock()
    defer { lock.unlock() }
    return queue.isEmpty ? 0 : queue.removeFirst()
  }
}

/// Drive one Push-to-Talk turn: activate, ingest one frame, then deactivate so
/// the engine finalizes and emits its result.
private func driveOneTurn(
  _ pipeline: STTPipeline, bus: AuraEventBus, timingOrigin: TimeInterval
) async {
  let context = TurnContext(
    sessionID: UUID(), activationSource: .pushToTalk, actor: .user,
    authority: .userUtterance, sensitivity: .sensitive, timingOrigin: timingOrigin)
  await bus.emit(
    EventEnvelope(
      correlationID: context.correlationID, causationID: context.causationID,
      actor: .user, sensitivity: .sensitive,
      payload: WakeActivationEvent(isActive: true, privacyMode: false, turnContext: context)))
  await pipeline.ingestSampleFrame(
    AudioFrame(samples: [0.5], timestamp: timingOrigin, sequenceIndex: 0))
  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
      payload: WakeActivationEvent(isActive: false, privacyMode: false)))
}

/// A reusable turn engine that emits a stable "turn N" (or an error result)
/// on finalization, mirroring the integration test's `ReusableTurnSTTEngine`.
private final class DeterministicTurnSTEngine: STTEngine, @unchecked Sendable {
  let engineID = "sp016-turn"
  let locale = Locale(identifier: "tr-TR")
  let results: AsyncStream<STTTranscriptResult>
  private let continuation: AsyncStream<STTTranscriptResult>.Continuation
  private let lock = NSLock()
  private var completedTurns = 0
  private let onlyError: Bool

  init(onlyError: Bool = false) {
    self.onlyError = onlyError
    (results, continuation) = AsyncStream.makeStream()
  }

  func start() async throws -> STTHealth {
    STTHealth(ready: true, status: "ready", detail: "sp016")
  }

  func ingest(_ frame: AudioFrame, activationTime: TimeInterval) async {}

  func finalizeSession() async {
    let turn = lock.withLock { completedTurns += 1; return completedTurns }
    continuation.yield(
      STTTranscriptResult(
        resultID: UUID(),
        isStable: onlyError ? false : true,
        text: onlyError ? "No speech detected" : "turn \(turn)",
        confidence: onlyError ? 0 : 0.95,
        metadata: onlyError ? ["error": "true"] : [:]))
  }

  func cancel() async {}

  func health() -> STTHealth {
    STTHealth(ready: true, status: "ready", detail: "sp016")
  }
}
