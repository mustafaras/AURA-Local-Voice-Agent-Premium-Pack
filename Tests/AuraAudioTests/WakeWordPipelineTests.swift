import AuraAudio
import AuraCore
import Foundation
import Testing

struct WakeWordPipelineTests {

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
    let bus = AuraEventBus(logger: AuraLogger(subsystem: "test", category: "bus"))
    let logger = AuraLogger(subsystem: "test", category: "pipeline")
    let config = WakeWordConfiguration(
      phrase: "hey aura",
      vadEnergyThresholdDB: -40.0,
      vadSilenceFrames: 5,
      wakeConfidenceThreshold: 0.8,
      wakeDebounceSeconds: 0.1,
      enableAntiTriggerProtection: true,
      speakerVerificationEnabled: false,
      speakerVerificationThreshold: 0.80,
      privacyModeKeyboardShortcut: "",
      privacyModeRequiresKeyboardShortcut: true
    )
    let vad = EnergyVAD(
      adaptationRate: 0.1,
      thresholdOffsetDB: 10.0,
      silenceFrames: 5
    )
    let detector = MarkerWakeWordDetector(
      phrase: "hey aura",
      confidenceThreshold: 0.8,
      markerFrequency: 1000.0,
      markerWindowHz: 50.0
    )

    let activationsBox = MutexBox<[Bool]>([])
    await bus.subscribe(WakeActivationEvent.self) { envelope in
      activationsBox.withLock { $0.append(envelope.payload.isActive) }
    }

    let clockBox = MutexBox<UInt64>(0)
    let clock: @Sendable () -> TimeInterval = {
      clockBox.withLock { count in
        count += 1
        return TimeInterval(count) * 0.1
      }
    }

    let pipeline = WakeWordPipeline(
      configuration: config,
      eventBus: bus,
      logger: logger,
      vad: vad,
      wakeDetector: detector,
      speakerVerifier: nil,
      monotonicClock: clock
    )

    await pipeline.start()

    // Lead-in silence lets the VAD adapt, then a marker tone should wake.
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

    for frame in silenceFrames + markerFrames {
      await pipeline.ingestSampleFrame(frame)
      let event = AudioFrameEvent(
        sampleCount: frame.samples.count,
        timestamp: frame.timestamp,
        sequenceIndex: frame.sequenceIndex,
        isDiscontinuity: frame.isDiscontinuity
      )
      await bus.emit(
        EventEnvelope(
          correlationID: UUID(),
          causationID: UUID(),
          actor: .audio,
          sensitivity: .internalLevel,
          payload: event
        )
      )
    }

    // Allow the subscribed handler to run on the bus.
    try? await Task.sleep(nanoseconds: 200_000_000)

    let metrics = await pipeline.currentMetrics()
    #expect(metrics.totalHypotheses > 0)
    #expect(metrics.acceptedActivations > 0)

    let activations = activationsBox.withLock { $0 }
    #expect(activations.contains(true))

    await pipeline.stop()
  }

  @Test func antiTriggerSuppressesWakeDuringOutput() async {
    let bus = AuraEventBus(logger: AuraLogger(subsystem: "test", category: "bus"))
    let logger = AuraLogger(subsystem: "test", category: "pipeline")
    let config = WakeWordConfiguration(
      phrase: "hey aura",
      vadEnergyThresholdDB: -40.0,
      vadSilenceFrames: 5,
      wakeConfidenceThreshold: 0.8,
      wakeDebounceSeconds: 0.0,
      enableAntiTriggerProtection: true,
      speakerVerificationEnabled: false,
      speakerVerificationThreshold: 0.80,
      privacyModeKeyboardShortcut: "",
      privacyModeRequiresKeyboardShortcut: true
    )
    let vad = EnergyVAD(
      adaptationRate: 0.1,
      thresholdOffsetDB: 10.0,
      silenceFrames: 5
    )
    let detector = MarkerWakeWordDetector(
      phrase: "hey aura",
      confidenceThreshold: 0.8,
      markerFrequency: 1000.0,
      markerWindowHz: 50.0
    )

    let activationsBox = MutexBox<[Bool]>([])
    await bus.subscribe(WakeActivationEvent.self) { envelope in
      activationsBox.withLock { $0.append(envelope.payload.isActive) }
    }

    let pipeline = WakeWordPipeline(
      configuration: config,
      eventBus: bus,
      logger: logger,
      vad: vad,
      wakeDetector: detector,
      speakerVerifier: nil,
      monotonicClock: { 0.0 }
    )

    await pipeline.start()
    await pipeline.setOutputActive(true)

    let markerFrames = SyntheticAudio.toneBurst(
      frequency: 1000,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 15
    )
    for frame in markerFrames {
      await pipeline.ingestSampleFrame(frame)
      await bus.emit(
        EventEnvelope(
          correlationID: UUID(),
          causationID: UUID(),
          actor: .audio,
          sensitivity: .internalLevel,
          payload: AudioFrameEvent(
            sampleCount: frame.samples.count,
            timestamp: frame.timestamp,
            sequenceIndex: frame.sequenceIndex,
            isDiscontinuity: frame.isDiscontinuity
          )
        )
      )
    }

    try? await Task.sleep(nanoseconds: 100_000_000)

    let metrics = await pipeline.currentMetrics()
    #expect(metrics.antiTriggerSuppressions > 0)
    #expect(metrics.acceptedActivations == 0)

    let activations = activationsBox.withLock { $0 }
    #expect(!activations.contains(true))

    await pipeline.stop()
  }

  @Test func privacyModeRequiresShortcut() async {
    let bus = AuraEventBus(logger: AuraLogger(subsystem: "test", category: "bus"))
    let logger = AuraLogger(subsystem: "test", category: "pipeline")
    let config = WakeWordConfiguration(
      phrase: "hey aura",
      vadEnergyThresholdDB: -40.0,
      vadSilenceFrames: 5,
      wakeConfidenceThreshold: 0.8,
      wakeDebounceSeconds: 0.0,
      enableAntiTriggerProtection: true,
      speakerVerificationEnabled: false,
      speakerVerificationThreshold: 0.80,
      privacyModeKeyboardShortcut: "⇧⌘L",
      privacyModeRequiresKeyboardShortcut: true
    )

    let pipeline = WakeWordPipeline(
      configuration: config,
      eventBus: bus,
      logger: logger,
      vad: EnergyVAD(),
      wakeDetector: MarkerWakeWordDetector(),
      speakerVerifier: nil,
      monotonicClock: { 0.0 }
    )

    await pipeline.start()
    #expect(await pipeline.currentState() == .listening)

    await pipeline.setPrivacyMode(true, triggeredByKeyboardShortcut: false)
    #expect(await pipeline.currentState() == .privacyArmed)

    let markerFrames = SyntheticAudio.toneBurst(
      frequency: 1000,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 15
    )
    for frame in markerFrames {
      await pipeline.ingestSampleFrame(frame)
      await bus.emit(
        EventEnvelope(
          correlationID: UUID(),
          causationID: UUID(),
          actor: .audio,
          sensitivity: .internalLevel,
          payload: AudioFrameEvent(
            sampleCount: frame.samples.count,
            timestamp: frame.timestamp,
            sequenceIndex: frame.sequenceIndex,
            isDiscontinuity: frame.isDiscontinuity
          )
        )
      )
    }

    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(await pipeline.currentMetrics().acceptedActivations == 0)

    await pipeline.privacyShortcutPressed()
    #expect(await pipeline.currentState() == .listening)

    await pipeline.stop()
  }

  @Test func speakerVerifierEnrollsAndRecognizesMarkerVoice() async {
    let verifier = MarkerSpeakerVerifier(
      markerFrequency: 1500.0,
      markerWindowHz: 50.0,
      matchThreshold: 0.70
    )

    let enrollmentFrames = SyntheticAudio.toneBurst(
      frequency: 1500,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 10
    )
    await verifier.enroll(profileID: "owner", samples: enrollmentFrames)

    let matchFrame = SyntheticAudio.toneBurst(
      frequency: 1500,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 1
    )[0]
    let matchHint = await verifier.verify(matchFrame)
    #expect(matchHint.profileID == "owner")
    #expect(matchHint.score >= 0.70)

    let strangerFrame = SyntheticAudio.toneBurst(
      frequency: 800,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 1
    )[0]
    let strangerHint = await verifier.verify(strangerFrame)
    #expect(strangerHint.profileID == nil)
  }
}

/// Simple non-actor container used only in tests to collect values across
/// `@Sendable` handlers without capturing a `var`.
private final class MutexBox<T>: @unchecked Sendable {
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
