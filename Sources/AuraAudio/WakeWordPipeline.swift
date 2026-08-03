import AuraCore
import Foundation

/// Coordinates voice-activity detection, wake-word detection, optional speaker
/// verification, privacy mode, and anti-trigger suppression.
///
/// The pipeline consumes `AudioFrameEvent` from the event bus, never the raw
/// realtime tap. It is isolated on its own actor so that detector work does not
/// block audio capture.
public actor WakeWordPipeline {
  public enum State: String, Sendable, Equatable, CaseIterable {
    case idle
    case listening
    case privacyArmed
    case activated
    case speakerVerifying
  }

  public struct Metrics: Sendable, Equatable {
    public var falseAccepts: UInt64 = 0
    public var falseRejects: UInt64 = 0
    public var antiTriggerSuppressions: UInt64 = 0
    public var totalHypotheses: UInt64 = 0
    public var acceptedActivations: UInt64 = 0

    public init() {}
  }

  private let configuration: WakeWordConfiguration
  private let eventBus: AuraEventBus
  private let logger: AuraLogger
  private let vad: any VoiceActivityDetector
  private let wakeDetector: any WakeWordDetector
  private let speakerVerifier: (any SpeakerVerifier)?
  private let sessionID: UUID

  private var state: State = .idle
  private var activeTurnContext: TurnContext?
  private var privacyMode: Bool = false
  private var privacyModeRequiresShortcut: Bool = true
  private var lastAcceptedWakeTimestamp: TimeInterval = 0
  private var isOutputActive: Bool = false
  private var metrics: Metrics = Metrics()
  private var subscriptionTask: Task<Void, Never>?
  private var activationEndTask: Task<Void, Never>?
  private let monotonicClock: () -> TimeInterval

  /// Create a wake-word pipeline.
  ///
  /// - Parameters:
  ///   - configuration: Wake/VAD/speaker/privacy settings.
  ///   - eventBus: Bus to consume frame events from and emit pipeline events to.
  ///   - logger: Privacy-aware logger.
  ///   - vad: Voice-activity detector implementation.
  ///   - wakeDetector: Wake-word detector implementation.
  ///   - speakerVerifier: Optional speaker verifier; its output is treated as
  ///     an identity hint, not an authorization decision.
  ///   - monotonicClock: Injectible clock for tests.
  public init(
    configuration: WakeWordConfiguration,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    vad: any VoiceActivityDetector,
    wakeDetector: any WakeWordDetector,
    speakerVerifier: (any SpeakerVerifier)? = nil,
    monotonicClock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() },
    sessionID: UUID = UUID()
  ) {
    self.configuration = configuration
    self.eventBus = eventBus
    self.logger = logger
    self.vad = vad
    self.wakeDetector = wakeDetector
    self.speakerVerifier = speakerVerifier
    self.monotonicClock = monotonicClock
    self.sessionID = sessionID
    self.privacyModeRequiresShortcut = configuration.privacyModeRequiresKeyboardShortcut
  }

  deinit {
    subscriptionTask?.cancel()
    activationEndTask?.cancel()
  }

  /// Start listening to audio frame events.
  public func start() async {
    guard subscriptionTask == nil else { return }
    state = privacyMode ? .privacyArmed : .listening
    await eventBus.subscribe(AudioFrameEvent.self) { [weak self] envelope in
      guard let self = self, !Task.isCancelled else { return }
      await self.handleFrameEvent(envelope.payload)
    }
    subscriptionTask = Task {
      // Keep the task alive while subscribed; the handler closure is invoked by the bus.
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    await logger.info("Wake-word pipeline started", actor: .audio)
  }

  /// Stop listening and reset detectors.
  public func stop() async {
    subscriptionTask?.cancel()
    subscriptionTask = nil
    activationEndTask?.cancel()
    activationEndTask = nil
    state = privacyMode ? .privacyArmed : .idle
    activeTurnContext = nil
    vad.reset()
    wakeDetector.reset()
    await logger.info("Wake-word pipeline stopped", actor: .audio)
  }

  /// Enable or disable privacy mode. When enabled and keyboard-shortcut-only
  /// is required, wake-word detection is suppressed until the keyboard
  /// shortcut arms the pipeline.
  public func setPrivacyMode(_ enabled: Bool, triggeredByKeyboardShortcut: Bool = false) async {
    privacyMode = enabled
    await emitPrivacyModeEvent(
      enabled: enabled, triggeredByKeyboardShortcut: triggeredByKeyboardShortcut)
    if enabled {
      state =
        privacyModeRequiresShortcut && !triggeredByKeyboardShortcut ? .privacyArmed : .listening
    } else {
      state = .listening
    }
    await logger.info("Privacy mode \(enabled ? "enabled" : "disabled")", actor: .audio)
  }

  /// Arm privacy-mode listening when the user presses the configured keyboard
  /// shortcut. This is the only way to re-arm listening in shortcut-only mode.
  public func privacyShortcutPressed() async {
    guard privacyMode else { return }
    state = .listening
    await logger.info("Privacy mode listening armed by keyboard shortcut", actor: .audio)
  }

  /// Notify the pipeline that assistant output is currently playing. This is
  /// used by anti-trigger suppression to reject wake hypotheses caused by TTS
  /// or other system audio.
  public func setOutputActive(_ active: Bool) async {
    isOutputActive = active
  }

  /// Current metrics snapshot.
  public func currentMetrics() -> Metrics {
    metrics
  }

  /// Current pipeline state.
  public func currentState() -> State {
    state
  }

  // MARK: - Event handling

  private func handleFrameEvent(_ event: AudioFrameEvent) async {
    guard state == .listening || state == .activated || state == .speakerVerifying else { return }

    // Reconstruct a frame containing the actual sample data. The pipeline
    // stores the most recent frame emitted by the realtime path so tests and
    // downstream consumers operate on the captured sample data.
    let frame = AudioFrame(
      samples: latestSamples,
      timestamp: event.timestamp,
      sequenceIndex: event.sequenceIndex,
      isDiscontinuity: event.isDiscontinuity
    )

    let vadResult = vad.analyze(frame)
    await emitVoiceActivityEvent(vadResult)

    if !vadResult.isSpeech { return }

    let hypothesis = wakeDetector.analyze(frame, vadResult: vadResult)
    metrics.totalHypotheses += 1
    let suppressed = configuration.enableAntiTriggerProtection && isOutputActive
    await emitWakeHypothesisEvent(hypothesis, suppressed: suppressed)

    if !hypothesis.detected { return }

    if suppressed {
      metrics.antiTriggerSuppressions += 1
      await logger.info("Wake hypothesis suppressed as anti-trigger", actor: .audio)
      return
    }

    let now = monotonicClock()
    guard now - lastAcceptedWakeTimestamp >= configuration.wakeDebounceSeconds else {
      return
    }
    lastAcceptedWakeTimestamp = now

    let passesThreshold = hypothesis.confidence >= configuration.wakeConfidenceThreshold
    if !passesThreshold {
      metrics.falseRejects += 1
      return
    }

    metrics.acceptedActivations += 1
    activeTurnContext = TurnContext(
      sessionID: sessionID,
      activationSource: .wakeWord,
      actor: .user,
      authority: .userUtterance,
      sensitivity: privacyMode ? .sensitive : .internalLevel,
      timingOrigin: now)
    await emitWakeDetectedEvent(hypothesis)

    if let verifier = speakerVerifier, configuration.speakerVerificationEnabled {
      state = .speakerVerifying
      let hint = await verifier.verify(frame)
      await emitSpeakerVerificationEvent(hint)
    }

    state = .activated
    await emitWakeActivationEvent(active: true, privacyMode: privacyMode)
    scheduleActivationEnd()
  }

  /// Latest captured samples published by the realtime audio path. Tests can
  /// seed this via `ingestSampleFrame(_:)`. The buffer is intentionally bounded
  /// and overwritten on every frame so memory usage stays flat.
  private nonisolated(unsafe) var latestSamples: [Float] = []

  /// Ingest a frame with real sample data. The realtime audio service calls this
  /// for each captured frame *before* emitting the matching `AudioFrameEvent`.
  public func ingestSampleFrame(_ frame: AudioFrame) {
    latestSamples = frame.samples
  }

  private func scheduleActivationEnd() {
    activationEndTask?.cancel()
    activationEndTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      guard let self = self, !Task.isCancelled else { return }
      await self.finalizeActivation()
    }
  }

  private func finalizeActivation() async {
    state = privacyMode ? .privacyArmed : .listening
    await emitWakeActivationEvent(active: false, privacyMode: privacyMode)
  }

  // MARK: - Event emitters

  private func emitVoiceActivityEvent(_ result: VADResult) async {
    await emit(
      VoiceActivityEvent(
        isActive: result.isSpeech,
        energyDB: result.energyDB,
        frameCount: result.frameCount)
    )
  }

  private func emitWakeHypothesisEvent(_ hypothesis: WakeHypothesis, suppressed: Bool) async {
    await emit(
      WakeWordHypothesisEvent(
        confidence: hypothesis.confidence,
        matchedPhrase: hypothesis.matchedPhrase,
        suppressedAsAntiTrigger: suppressed)
    )
  }

  private func emitWakeDetectedEvent(_ hypothesis: WakeHypothesis) async {
    await emit(
      WakeWordDetectedEvent(
        confidence: hypothesis.confidence,
        matchedPhrase: hypothesis.matchedPhrase,
        preRollFrames: 0)
    )
  }

  private func emitSpeakerVerificationEvent(_ hint: SpeakerIdentityHint) async {
    await emit(
      SpeakerVerificationEvent(
        profileID: hint.profileID,
        score: hint.score,
        isMatch: hint.profileID != nil && hint.score >= configuration.speakerVerificationThreshold),
      sensitivity: .sensitive
    )
  }

  private func emitWakeActivationEvent(active: Bool, privacyMode: Bool) async {
    let context: TurnContext?
    if active {
      let current = activeTurnContext ?? TurnContext(
        sessionID: sessionID,
        activationSource: .wakeWord,
        actor: .user,
        authority: .userUtterance,
        sensitivity: privacyMode ? .sensitive : .internalLevel,
        timingOrigin: monotonicClock())
      activeTurnContext = current
      context = current
    } else {
      context = activeTurnContext
    }
    await emit(
      WakeActivationEvent(isActive: active, privacyMode: privacyMode, turnContext: context),
      context: context
    )
    if !active {
      activeTurnContext = nil
    }
  }

  private func emitPrivacyModeEvent(enabled: Bool, triggeredByKeyboardShortcut: Bool) async {
    await emit(
      PrivacyModeEvent(
        enabled: enabled,
        triggeredByKeyboardShortcut: triggeredByKeyboardShortcut)
    )
  }

  private func emit<Payload: EventPayload>(
    _ payload: Payload,
    context: TurnContext? = nil,
    sensitivity: SensitivityLevel = .internalLevel
  ) async {
    let traceContext = context ?? activeTurnContext
    let envelope = traceContext?.envelope(
      actor: .audio, sensitivity: sensitivity, payload: payload)
      ?? EventEnvelope(
        correlationID: sessionID,
        causationID: sessionID,
        actor: .audio,
        sensitivity: sensitivity,
        payload: payload)
    await eventBus.emit(envelope)
  }
}
