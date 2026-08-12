import AuraAudio
import AuraCore
import Foundation
import Testing

struct WakeWordPipelineTests {

  @Test func disabledWakeDetectorNeverClaimsProductionActivation() {
    let detector = DisabledWakeWordDetector()
    let frame = AudioFrame(
      samples: Array(repeating: 1.0, count: 512),
      timestamp: 0,
      sequenceIndex: 1,
      isDiscontinuity: false)

    let result = detector.analyze(frame, vadResult: nil)
    #expect(!result.detected)
    #expect(result.confidence == 0)
    #expect(result.matchedPhrase.isEmpty)
    #expect(detector.reason.contains("Push to Talk"))
  }

  @Test func energyVADDetectsToneAndResets() {
    let vad = EnergyVAD(
      adaptationRate: 0.1,
      thresholdOffsetDB: 10.0,
      silenceFrames: 5,
      minimumNoiseFloorDB: -80.0
    )

    let silenceFrames = SyntheticAudio.silence(frameLength: 512, frameCount: 10)
    for frame in silenceFrames {
      _ = vad.analyze(frame)
    }

    let burstFrames = SyntheticAudio.toneBurst(
      frequency: 1000,
      amplitude: 0.5,
      frameLength: 512,
      burstFrames: 10,
      leadingSilenceFrames: 0
    )
    let results = burstFrames.map { vad.analyze($0) }
    #expect(results.last?.isSpeech == true)

    vad.reset()
    let afterReset = vad.analyze(burstFrames[0])
    #expect(afterReset.frameCount == 1)
  }

  @Test func markerWakeDetectorMatchesToneAndIgnoresOffMarker() {
    let detector = MarkerWakeWordDetector(
      phrase: "hey aura",
      confidenceThreshold: 0.8,
      energyThresholdDB: -40.0,
      markerFrequency: 1000.0,
      markerWindowHz: 50.0
    )

    let markerFrames = SyntheticAudio.toneBurst(
      frequency: 1000,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 5
    )
    let vad = EnergyVAD()
    let markerResult = detector.analyze(markerFrames[2], vadResult: vad.analyze(markerFrames[2]))
    #expect(markerResult.detected == true)
    #expect(markerResult.matchedPhrase == "hey aura")
    #expect(markerResult.confidence >= 0.8)

    let offMarkerFrames = SyntheticAudio.toneBurst(
      frequency: 400,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 5
    )
    let offResult = detector.analyze(offMarkerFrames[2], vadResult: vad.analyze(offMarkerFrames[2]))
    #expect(offResult.detected == false)
  }

  @Test func wakePipelineAcceptsWakeAndReportsMetrics() async {
    let clockBox = WakeMutexBox<UInt64>(0)
    let fixture = await makeWakePipelineFixture(
      debounceSeconds: 0.1,
      monotonicClock: {
        clockBox.withLock { count in
          count += 1
          return TimeInterval(count) * 0.1
        }
      })
    await fixture.pipeline.start()
    let silenceFrames = SyntheticAudio.silence(
      frameLength: 512, frameCount: 10, startingSequence: 0)
    let markerFrames = SyntheticAudio.toneBurst(
      frequency: 1000,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 15,
      leadingSilenceFrames: 0,
      startingSequence: UInt64(silenceFrames.count)
    )

    await feedWakeFrames(silenceFrames + markerFrames, fixture: fixture)

    // Allow the subscribed handler to run on the bus.
    try? await Task.sleep(nanoseconds: 200_000_000)

    let metrics = await fixture.pipeline.currentMetrics()
    #expect(metrics.totalHypotheses > 0)
    #expect(metrics.acceptedActivations > 0)

    let activations = fixture.activationsBox.withLock { $0 }
    #expect(activations.contains(true))

    await fixture.pipeline.stop()
  }

  @Test func antiTriggerSuppressesWakeDuringOutput() async {
    let fixture = await makeWakePipelineFixture(
      debounceSeconds: 0.0, monotonicClock: { 0.0 })
    await fixture.pipeline.start()
    await fixture.pipeline.setOutputActive(true)

    let markerFrames = SyntheticAudio.toneBurst(
      frequency: 1000,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 15
    )
    await feedWakeFrames(markerFrames, fixture: fixture)

    try? await Task.sleep(nanoseconds: 100_000_000)

    let metrics = await fixture.pipeline.currentMetrics()
    #expect(metrics.antiTriggerSuppressions > 0)
    #expect(metrics.acceptedActivations == 0)

    let activations = fixture.activationsBox.withLock { $0 }
    #expect(!activations.contains(true))

    await fixture.pipeline.stop()
  }

}

struct WakePipelineFixture {
  let bus: AuraEventBus
  let pipeline: WakeWordPipeline
  let activationsBox: WakeMutexBox<[Bool]>
}

func makeWakePipelineFixture(
  debounceSeconds: TimeInterval,
  monotonicClock: @escaping @Sendable () -> TimeInterval,
  privacyShortcut: String = ""
) async -> WakePipelineFixture {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "test", category: "bus"))
  let config = WakeWordConfiguration(
    phrase: "hey aura", vadEnergyThresholdDB: -40.0, vadSilenceFrames: 5,
    wakeConfidenceThreshold: 0.8, wakeDebounceSeconds: debounceSeconds,
    enableAntiTriggerProtection: true, speakerVerificationEnabled: false,
    speakerVerificationThreshold: 0.80, privacyModeKeyboardShortcut: privacyShortcut,
    privacyModeRequiresKeyboardShortcut: true)
  let activationsBox = WakeMutexBox<[Bool]>([])
  await bus.subscribe(WakeActivationEvent.self) { envelope in
    activationsBox.withLock { $0.append(envelope.payload.isActive) }
  }
  let pipeline = WakeWordPipeline(
    configuration: config, eventBus: bus,
    logger: AuraLogger(subsystem: "test", category: "pipeline"),
    vad: EnergyVAD(adaptationRate: 0.1, thresholdOffsetDB: 10.0, silenceFrames: 5),
    wakeDetector: MarkerWakeWordDetector(
      phrase: "hey aura", confidenceThreshold: 0.8,
      markerFrequency: 1000.0, markerWindowHz: 50.0),
    speakerVerifier: nil, monotonicClock: monotonicClock)
  return WakePipelineFixture(bus: bus, pipeline: pipeline, activationsBox: activationsBox)
}

func feedWakeFrames(_ frames: [AudioFrame], fixture: WakePipelineFixture) async {
  for frame in frames {
    await fixture.pipeline.ingestSampleFrame(frame)
    await fixture.bus.emit(
      EventEnvelope(
        correlationID: UUID(), causationID: UUID(), actor: .audio,
        sensitivity: .internalLevel,
        payload: AudioFrameEvent(
          sampleCount: frame.samples.count, timestamp: frame.timestamp,
          sequenceIndex: frame.sequenceIndex, isDiscontinuity: frame.isDiscontinuity)))
  }
}

/// Simple non-actor container used only in tests to collect values across
/// `@Sendable` handlers without capturing a `var`.
final class WakeMutexBox<T>: @unchecked Sendable {
  private var value: T
  private let lock = NSLock()

  init(_ value: T) {
    self.value = value
  }

  func withLock<R>(_ body: (inout T) -> R) -> R {
    lock.lock()
    defer { lock.unlock() }
    return body(&value)
  }
}
