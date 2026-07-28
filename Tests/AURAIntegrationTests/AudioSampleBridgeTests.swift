@testable import AURA
import AuraAudio
import AuraCore
import AuraSTT
import Foundation
import Testing

/// Confirms `AudioSampleBridge` actually bridges captured samples to
/// `WakeWordPipeline`/`STTPipeline`'s `ingestSampleFrame(_:)` seam — the gap
/// this phase closed: `AudioFrameEvent` carries no sample data itself, and
/// nothing called `ingestSampleFrame` in production before this phase.
///
/// A precise test requires distinguishing the bridge's contribution from
/// `STTPipeline`'s own pre-existing, independent `AudioFrameEvent`
/// subscription (`STTPipeline.handleAudioFrame`, `Sources/AuraSTT/
/// STTPipeline.swift`) — which *also* calls `engine.ingest(_:)` on every
/// frame event, but always with an empty-`samples` placeholder frame built
/// only from the event's metadata. `DeterministicMockSTTEngine` cannot
/// distinguish real samples from that placeholder (it only counts `ingest`
/// calls), so a test using it alone cannot tell whether the bridge's own
/// forwarding ever actually ran. `RecordingSTTEngine` below records every
/// ingested frame's real content instead, making the bridge's contribution
/// directly observable: only the bridge's `ingestSampleFrame(_:)` path ever
/// delivers a frame with non-empty `samples`.
///
/// Deliberately does not depend on live `AVAudioEngine` capture timing:
/// this project's own precedent (`AuraAudioTests.startIgnoredWhenNotIdle`,
/// documented in `ledger/CURRENT_STATE.md` as a known hardware-timing-
/// dependent flaky test) explicitly calls for injecting a fake/seeded audio
/// backend instead. `AuraAudio.init(ringBuffer:)` already accepts an
/// externally-constructed `AudioRingBuffer`, so a known frame is seeded
/// there and a matching `AudioFrameEvent` is emitted directly — this still
/// exercises the real, production `AudioSampleBridge`/`AuraAudio.latestFrame
/// ()` seam via `@testable import`, just without waiting on real hardware.
final class RecordingSTTEngine: STTEngine, @unchecked Sendable {
  let engineID = "recording-stt"
  let locale = Locale(identifier: "en-US")
  let results: AsyncStream<STTTranscriptResult>
  private let continuation: AsyncStream<STTTranscriptResult>.Continuation
  private let lock = NSLock()
  private var recordedFrames: [AudioFrame] = []

  init() {
    let (stream, continuation) = AsyncStream<STTTranscriptResult>.makeStream()
    self.results = stream
    self.continuation = continuation
  }

  func start() async throws -> STTHealth {
    STTHealth(ready: true, status: "ready", detail: "recording engine")
  }

  func ingest(_ frame: AudioFrame, activationTime: TimeInterval) async {
    lock.withLock { recordedFrames.append(frame) }
  }

  func finalizeSession() async {}

  func cancel() async {
    continuation.finish()
  }

  func health() -> STTHealth {
    STTHealth(ready: true, status: "ready", detail: "recording engine")
  }

  func ingestedFrames() -> [AudioFrame] {
    lock.withLock { recordedFrames }
  }
}

private func makeFixture() -> (
  bus: AuraEventBus, audio: AuraAudio, wakeWordPipeline: WakeWordPipeline,
  sttPipeline: STTPipeline, engine: RecordingSTTEngine, knownFrame: AudioFrame
) {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "bridge"))
  let knownFrame = AudioFrame(
    samples: [0.42, 0.24], timestamp: 1.0, sequenceIndex: 7, isDiscontinuity: false)
  let ringBuffer = AudioRingBuffer(capacity: 4)
  ringBuffer.append(knownFrame)
  let audio = AuraAudio(
    configuration: AudioConfiguration(), eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "audio"),
    ringBuffer: ringBuffer)
  let wakeWordPipeline = WakeWordPipeline(
    configuration: WakeWordConfiguration(), eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "wake"),
    vad: EnergyVAD(), wakeDetector: MarkerWakeWordDetector())
  let engine = RecordingSTTEngine()
  let sttPipeline = STTPipeline(
    engine: engine, vocabulary: UserVocabulary(), eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt"))
  return (bus, audio, wakeWordPipeline, sttPipeline, engine, knownFrame)
}

@Test
func audioSampleBridgeForwardsRealSamplesOnSequenceIndexMatch() async throws {
  let fixture = makeFixture()
  let bridge = AudioSampleBridge(
    audio: fixture.audio, wakeWordPipeline: fixture.wakeWordPipeline,
    sttPipeline: fixture.sttPipeline, eventBus: fixture.bus)

  // Subscribe-before-publish, matching AuraKernel's real ordering.
  await bridge.start()
  await fixture.wakeWordPipeline.start()
  try await fixture.sttPipeline.start()

  await fixture.bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))

  // No real AVAudioEngine capture: emit an AudioFrameEvent whose
  // sequenceIndex matches the frame already seeded into the ring buffer.
  await fixture.bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: AudioFrameEvent(
        sampleCount: fixture.knownFrame.samples.count, timestamp: fixture.knownFrame.timestamp,
        sequenceIndex: fixture.knownFrame.sequenceIndex, isDiscontinuity: false)))

  var attempts = 0
  while fixture.engine.ingestedFrames().allSatisfy({ $0.samples.isEmpty }), attempts < 25 {
    try await Task.sleep(nanoseconds: 20_000_000)
    attempts += 1
  }

  let realSampleFrames = fixture.engine.ingestedFrames().filter { !$0.samples.isEmpty }
  #expect(
    realSampleFrames.contains { $0.samples == fixture.knownFrame.samples },
    "expected AudioSampleBridge to deliver the real, non-empty-sample frame to STTPipeline.ingestSampleFrame"
  )
}

@Test
func audioSampleBridgeNeverForwardsRealSamplesOnSequenceIndexMismatch() async throws {
  let fixture = makeFixture()
  let bridge = AudioSampleBridge(
    audio: fixture.audio, wakeWordPipeline: fixture.wakeWordPipeline,
    sttPipeline: fixture.sttPipeline, eventBus: fixture.bus)

  await bridge.start()
  await fixture.wakeWordPipeline.start()
  try await fixture.sttPipeline.start()

  await fixture.bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))

  // sequenceIndex 999 does not match the seeded frame's index (7) — the
  // bridge's staleness check must skip forwarding. STTPipeline's own,
  // separate direct AudioFrameEvent subscription still fires (it doesn't
  // depend on the bridge), but only ever with an empty-samples placeholder.
  await fixture.bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: AudioFrameEvent(
        sampleCount: fixture.knownFrame.samples.count, timestamp: fixture.knownFrame.timestamp,
        sequenceIndex: 999, isDiscontinuity: false)))

  var attempts = 0
  while fixture.engine.ingestedFrames().isEmpty, attempts < 25 {
    try await Task.sleep(nanoseconds: 20_000_000)
    attempts += 1
  }

  let frames = fixture.engine.ingestedFrames()
  #expect(!frames.isEmpty, "expected STTPipeline's own direct subscription to still fire")
  #expect(
    frames.allSatisfy { $0.samples.isEmpty },
    "expected no real-sample frame to reach the engine when the bridge's sequence index check fails"
  )
}
