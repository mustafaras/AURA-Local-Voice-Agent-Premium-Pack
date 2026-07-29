import AuraAudio
import AuraCore
import AuraSTT
import Foundation
import Testing

@testable import AURA

/// Confirms `AudioSampleBridge` actually bridges captured samples to
/// `WakeWordPipeline`/`STTPipeline`'s `ingestSampleFrame(_:)` seam — the gap
/// this phase closed: `AudioFrameEvent` carries no sample data itself, and
/// nothing called `ingestSampleFrame` in production before this phase.
///
/// `RecordingSTTEngine` records every ingested frame's real content so the
/// bridge's contribution is directly observable.
///
/// Deliberately does not depend on live `AVAudioEngine` capture timing:
/// this project's own precedent (`AuraAudioTests.startIgnoredWhenNotIdle`,
/// documented in `ledger/CURRENT_STATE.md` as a known hardware-timing-
/// dependent flaky test) explicitly calls for injecting a fake/seeded audio
/// backend instead. `AuraAudio.init(ringBuffer:)` already accepts an
/// externally-constructed `AudioRingBuffer`, so a known frame is seeded
/// there and a matching `AudioFrameEvent` is emitted directly — this still
/// exercises the real, production `AudioSampleBridge`/`AuraAudio.frame
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

  // sequenceIndex 999 does not match the seeded frame's index (7), so the
  // bridge must skip forwarding.
  await fixture.bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: AudioFrameEvent(
        sampleCount: fixture.knownFrame.samples.count, timestamp: fixture.knownFrame.timestamp,
        sequenceIndex: 999, isDiscontinuity: false)))

  #expect(fixture.engine.ingestedFrames().isEmpty)
}

@Test
func audioSampleBridgeDisablesSyntheticWakeDetectionButStillForwardsSTTSamples() async throws {
  let fixture = makeFixture()
  let bridge = AudioSampleBridge(
    audio: fixture.audio, wakeWordPipeline: fixture.wakeWordPipeline,
    sttPipeline: fixture.sttPipeline, eventBus: fixture.bus, enableWakeDetection: false)

  await bridge.start()
  await fixture.wakeWordPipeline.start()
  try await fixture.sttPipeline.start()
  await fixture.bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))
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

  #expect(
    fixture.engine.ingestedFrames().contains { $0.samples == fixture.knownFrame.samples },
    "push-to-talk STT must retain real audio samples when synthetic wake detection is disabled")
  let wakeMetrics = await fixture.wakeWordPipeline.currentMetrics()
  #expect(wakeMetrics.totalHypotheses == 0)
  #expect(wakeMetrics.acceptedActivations == 0)
}
