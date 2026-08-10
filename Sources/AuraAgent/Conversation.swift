import AuraAudio
import AuraCore
import Foundation

/// Conversation state machine and TTS scheduler.
///
/// This actor owns the canonical turn state, handles barge-in, timeout, and
/// deterministic voice commands, and coordinates with the TTS adapter. It does
/// not execute tools or access LLM output directly; it consumes typed intent
/// and response-plan events and emits typed conversation and TTS events.
public actor Conversation {
  public private(set) var state: ConversationState = .idle

  private let configuration: ConversationConfiguration
  private let ttsConfiguration: TTSConfiguration
  private let eventBus: AuraEventBus
  private let logger: AuraLogger
  private let sessionID: UUID

  /// The active TTS engine. In a full build this would be selected from the
  /// adapter chain by the orchestrator; for the Phase 4 slice the engine is
  /// injected directly so tests can use the mock.
  private let ttsEngine: any TTSEngine

  /// Queue of prompts awaiting speech. The first prompt is the active one.
  private var speechQueue: [TTSPrompt] = []
  private var activeSpeechTask: Task<Void, Never>?
  private var bargeInGraceUntil: TimeInterval = 0
  private var bargeInStopping: Bool = false

  /// Timer for the listening timeout. Cancelled on state change.
  private var timeoutTask: Task<Void, Never>?
  private var continuationTask: Task<Void, Never>?
  private var pendingContinuation: (event: STTStableSegmentEvent, context: TurnContext?, id: UUID)?

  /// Accumulated transcript text for the current listening turn.
  private var currentTurnText: String = ""
  private var currentTurnConfidence: Double = 0
  private var activeTurnContext: TurnContext?

  /// Monotonic clock source used for all latency math in this actor.
  private let monotonicClock: () -> TimeInterval

  /// Timestamp of the most recent accepted wake activation, measured with
  /// `monotonicClock`. Nil when not in an active turn.
  private var wakeStartTime: TimeInterval?

  /// Set to true once the first spoken response plan of the current turn has
  /// been used to emit a wake-to-ack latency measurement.
  private var wakeToAckRecorded: Bool = false

  /// Set to true when the current turn carries a deterministic command that
  /// does not require a remote model, so `onSpeechFinished()` can record the
  /// simple-command completion latency.
  private var simpleCommandTurn: Bool = false

  public init(
    configuration: ConversationConfiguration,
    ttsConfiguration: TTSConfiguration,
    ttsEngine: any TTSEngine,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    monotonicClock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() },
    sessionID: UUID = UUID()
  ) {
    self.configuration = configuration
    self.ttsConfiguration = ttsConfiguration
    self.ttsEngine = ttsEngine
    self.eventBus = eventBus
    self.logger = logger
    self.sessionID = sessionID
    self.monotonicClock = monotonicClock
  }

  // MARK: - Public state transitions

  /// Call when a wake activation starts (user said wake word or pressed the
  /// privacy-mode shortcut). Moves from idle/speaking/interrupted to listening.
  public func wakeActivationStarted(
    privacyMode: Bool,
    turnContext: TurnContext? = nil
  ) async {
    await cancelTimeout()
    if state == .speaking, ttsConfiguration.enableBargeIn {
      await stopSpeaking(reason: .interrupted)
    }
    // Always clear TTS queue on a fresh wake so stale prompts don't play.
    speechQueue.removeAll()
    continuationTask?.cancel()
    continuationTask = nil
    pendingContinuation = nil
    activeTurnContext =
      turnContext
      ?? TurnContext(
        sessionID: sessionID,
        activationSource: .pushToTalk,
        actor: .user,
        authority: .userUtterance,
        sensitivity: privacyMode ? .sensitive : .internalLevel,
        timingOrigin: monotonicClock())
    transition(
      to: .listening, reason: privacyMode ? "privacy-mode activation" : "wake-word activation")
    currentTurnText = ""
    currentTurnConfidence = 0
    wakeStartTime = monotonicClock()
    wakeToAckRecorded = false
    simpleCommandTurn = false
    scheduleTimeout(for: .listening, after: configuration.listenTimeoutSeconds)
  }

  /// Call when voice activity ends while listening. This does not complete
  /// the turn; STT stable segment completion does.
  public func voiceActivityEnded() async {
    guard state == .listening else { return }
    await logger.debug("Voice activity ended while listening", actor: .audio)
  }

  /// Submit a typed turn through the same intent/response spine as speech.
  public func submitTextTurn(_ text: String, context: TurnContext) async {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    await cancelTimeout()
    if state == .speaking {
      await stopSpeaking(reason: .interrupted)
    }
    speechQueue.removeAll()
    activeTurnContext = context
    currentTurnText = trimmed
    currentTurnConfidence = 1
    transition(to: .thinking, reason: "text turn submitted")
    emit(
      TurnCompletedEvent(
        text: trimmed,
        confidence: 1,
        isFinal: true,
        requiresPolicyReview: true,
        turnContext: context))
    scheduleTimeout(for: .thinking, after: configuration.thinkTimeoutSeconds)
  }

  /// Process a stable STT segment during a listening turn.
  public func stableSegmentReceived(
    _ event: STTStableSegmentEvent,
    turnContext: TurnContext? = nil
  ) async {
    guard state == .listening || state == .interrupted else { return }

    currentTurnText = event.text
    currentTurnConfidence = event.confidence
    if let turnContext {
      activeTurnContext = turnContext
    }

    if let command = event.deterministicCommand {
      await handleDeterministicCommand(command)
      return
    }

    if TurnCompletionHeuristics.likelyIncomplete(event.text) {
      let id = UUID()
      pendingContinuation = (event: event, context: turnContext, id: id)
      continuationTask?.cancel()
      continuationTask = Task { [weak self] in
        guard let self else { return }
        try? await Task.sleep(for: .seconds(configuration.continuationWindowSeconds))
        guard !Task.isCancelled else { return }
        await self.completePendingContinuation(id: id)
      }
      await logger.debug(
        "Stable transcript looks incomplete; waiting for continuation",
        actor: .audio)
      return
    }

    await completeStableSegment(event, turnContext: turnContext)
  }

  private func completePendingContinuation(id: UUID) async {
    guard let pendingContinuation, pendingContinuation.id == id else { return }
    self.pendingContinuation = nil
    continuationTask = nil
    await completeStableSegment(
      pendingContinuation.event,
      turnContext: pendingContinuation.context)
  }

  private func completeStableSegment(
    _ event: STTStableSegmentEvent,
    turnContext: TurnContext?
  ) async {
    // Semantic turn completion: stable segment ends the listening phase.
    let completed = TurnCompletedEvent(
      text: event.text,
      confidence: event.confidence,
      isFinal: true,
      deterministicCommand: nil,
      requiresPolicyReview: true,
      turnContext: activeTurnContext
    )
    await cancelTimeout()
    transition(to: .thinking, reason: "stable STT segment received")
    emit(completed)
    scheduleTimeout(for: .thinking, after: configuration.thinkTimeoutSeconds)
  }

  /// Process a partial STT result. Does not change state; used only for UI.
  public func partialTranscriptReceived(
    _ event: STTPartialEvent,
    turnContext: TurnContext? = nil
  ) async {
    guard state == .listening || state == .interrupted else { return }
    if let turnContext {
      activeTurnContext = turnContext
    }
    await logger.debug("Partial transcript: \(event.text)", actor: .audio)
  }

  /// End the active listening turn with the concrete local STT failure.
  public func recognitionFailed(detail: String, turnContext: TurnContext? = nil) async {
    guard state == .listening || state == .interrupted else { return }
    if let turnContext {
      activeTurnContext = turnContext
    }
    await cancelTimeout()
    transition(to: .error, reason: detail)
  }

  /// Call when the intent engine has produced a response plan. The plan may
  /// or may not include a spoken response. If it does, the TTS queue is scheduled.
  public func responsePlanReceived(_ event: ResponsePlanEvent) async {
    guard state == .thinking || state == .speaking else { return }
    await cancelTimeout()
    if let context = event.turnContext ?? activeTurnContext {
      activeTurnContext = context.withBackendIDs(
        TurnBackendIDs(
          stt: context.backendIDs.stt,
          tts: ttsEngine.engineID,
          model: context.backendIDs.model,
          tool: context.backendIDs.tool))
    }
    emit(event)

    if ProcessInfo.processInfo.environment["AURA_LOG_RESPONSE_TEXT"] == "1" {
      await logger.info(
        "TEXT_DEMO response [act=\(event.hasSpokenResponse ? "spoken" : "silent")]: \(event.summary)",
        actor: .system)
    }

    // A response plan from a local/no-remote-model intent qualifies this turn
    // for the simple-command completion latency budget.
    if event.isSimpleCommand {
      simpleCommandTurn = true
    }

    if event.hasSpokenResponse, !event.summary.isEmpty {
      recordWakeToAckLatencyIfNeeded()

      let prompt = TTSPrompt(
        text: event.summary,
        locale: event.language?.ttsLocale ?? ttsConfiguration.defaultLocale,
        rate: ttsConfiguration.defaultRate,
        interruptible: ttsConfiguration.enableBargeIn
      )
      let wasEmpty = speechQueue.isEmpty
      speechQueue.append(prompt)

      // If we are already speaking, the active task will drain the queue.
      // Otherwise, start the first prompt now.
      if state != .speaking {
        transition(to: .speaking, reason: "response plan has spoken response")
      } else {
        transition(to: .speaking, reason: "response plan appended to queue")
      }

      if wasEmpty || state != .speaking {
        await scheduleNextSpeech()
      }
    } else if speechQueue.isEmpty {
      recordSimpleCommandCompletionLatencyIfNeeded()
      transition(to: .idle, reason: "response plan has no spoken response")
    }
  }

  /// Call when new user speech is detected during thinking or speaking. This
  /// is a barge-in; TTS is stopped and the machine returns to listening.
  public func bargeInDetected(reason: String) async {
    let now = currentTime()
    guard now >= bargeInGraceUntil else {
      await logger.debug("Barge-in suppressed during grace window", actor: .audio)
      return
    }

    switch state {
    case .speaking:
      await cancelTimeout()
      // Capture state and emit the event before any await so a racing
      // TTS task cannot transition to idle underneath us.
      let capturedState = state
      let barge = BargeInEvent(atState: capturedState, reason: reason)
      emit(barge)
      // Suppress the active speech task's onSpeechFinished transition.
      bargeInStopping = true
      await stopSpeaking(reason: .interrupted)
      speechQueue.removeAll()
      bargeInGraceUntil = now + TimeInterval(configuration.bargeInGraceMilliseconds) / 1000.0
      transition(to: .listening, reason: "barge-in: \(reason)")
      bargeInStopping = false
      scheduleTimeout(for: .listening, after: configuration.listenTimeoutSeconds)
    case .thinking:
      await cancelTimeout()
      let barge = BargeInEvent(atState: state, reason: reason)
      emit(barge)
      bargeInGraceUntil = now + TimeInterval(configuration.bargeInGraceMilliseconds) / 1000.0
      transition(to: .listening, reason: "barge-in while thinking: \(reason)")
      scheduleTimeout(for: .listening, after: configuration.listenTimeoutSeconds)
    default:
      break
    }
  }

  /// Stop the assistant deterministically from any state. Clears the TTS queue.
  public func stop() async {
    await cancelTimeout()
    continuationTask?.cancel()
    continuationTask = nil
    pendingContinuation = nil
    speechQueue.removeAll()
    await stopSpeaking(reason: .interrupted)
    currentTurnText = ""
    currentTurnConfidence = 0
    activeTurnContext = nil
    transition(to: .idle, reason: "deterministic stop command")
  }

  /// Pause/resume speaking. If not currently speaking, this is a no-op.
  public func pauseResumeToggled() async {
    switch state {
    case .speaking:
      await ttsEngine.pauseSpeaking()
    default:
      await ttsEngine.resumeSpeaking()
    }
  }

  // MARK: - Internal TTS scheduling

  private func scheduleNextSpeech() async {
    guard !speechQueue.isEmpty else {
      transition(to: .idle, reason: "speech queue empty")
      return
    }

    let prompt = speechQueue.removeFirst()
    let promptID = UUID().uuidString
    emit(TTSStartedEvent(engineID: ttsEngine.engineID, promptID: promptID, text: prompt.text))

    let speechTimeoutSeconds = configuration.speechTimeoutSeconds
    activeSpeechTask = Task { [weak self] in
      guard let self = self else { return }
      let stream = self.ttsEngine.speak(prompt)

      await self.runSpeechStream(
        stream,
        promptID: promptID,
        speechTimeoutSeconds: speechTimeoutSeconds,
        timedOutRef: SentValueBox(initial: false)
      )
    }
  }

  private func runSpeechStream(
    _ stream: AsyncStream<TTSChunk>,
    promptID: String,
    speechTimeoutSeconds: Double,
    timedOutRef: SentValueBox<Bool>
  ) async {
    let timeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(speechTimeoutSeconds * 1_000_000_000))
      timedOutRef.value = true
      await self?.stopSpeaking(reason: .timeout)
    }

    for await chunk in stream {
      if Task.isCancelled { break }
      emit(TTSChunkEvent(promptID: promptID, chunk: chunk))
      if case .failed(let detail) = chunk {
        await logger.error("TTS failed: \(detail)", actor: .audio)
        emit(TTSStoppedEvent(promptID: promptID, reason: .error))
        timeoutTask.cancel()
        break
      }
    }

    if timedOutRef.value {
      emit(TTSStoppedEvent(promptID: promptID, reason: .timeout))
    } else if !Task.isCancelled {
      emit(TTSStoppedEvent(promptID: promptID, reason: .completed))
    }

    timeoutTask.cancel()
    await onSpeechFinished()
  }

  private func onSpeechFinished() async {
    // A barge-in cancels the active speech task and clears the queue. Guard
    // so we do not transition back to idle or start the next queued prompt.
    guard !bargeInStopping, state != .listening else {
      bargeInStopping = false
      return
    }
    if speechQueue.isEmpty {
      recordSimpleCommandCompletionLatencyIfNeeded()
      transition(to: .idle, reason: "speech complete")
    } else {
      await scheduleNextSpeech()
    }
  }

  // MARK: - Latency measurement

  private func recordWakeToAckLatencyIfNeeded() {
    guard let start = wakeStartTime, !wakeToAckRecorded else { return }
    let latency = monotonicClock() - start
    wakeToAckRecorded = true
    emit(
      LatencyMeasuredEvent(
        kind: .wakeToAck,
        latencySeconds: latency,
        budgetSeconds: 0.5,
        turnContext: activeTurnContext))
  }

  private func recordSimpleCommandCompletionLatencyIfNeeded() {
    guard simpleCommandTurn, let start = wakeStartTime else { return }
    emit(
      LatencyMeasuredEvent(
        kind: .simpleCommandCompletion,
        latencySeconds: monotonicClock() - start,
        budgetSeconds: 1.5,
        turnContext: activeTurnContext))
  }

  private func stopSpeaking(reason: TTSStopReason) async {
    activeSpeechTask?.cancel()
    activeSpeechTask = nil
    await ttsEngine.stopSpeaking()
    // Any in-flight stream will finish; the task loop emits TTSStoppedEvent.
  }

  // MARK: - Deterministic commands

  private func handleDeterministicCommand(_ command: String) async {
    let normalized = command.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    if configuration.deterministicStopCommands.contains(normalized) {
      await stop()
      return
    }

    if configuration.deterministicPauseResumeCommands.contains(normalized) {
      await pauseResumeToggled()
      return
    }

    // Otherwise treat it as a completed turn carrying the command.
    simpleCommandTurn = true
    let completed = TurnCompletedEvent(
      text: currentTurnText,
      confidence: currentTurnConfidence,
      isFinal: true,
      deterministicCommand: normalized,
      requiresPolicyReview: false,
      turnContext: activeTurnContext
    )
    emit(completed)
    await cancelTimeout()
    transition(to: .thinking, reason: "deterministic command: \(normalized)")
    scheduleTimeout(for: .thinking, after: configuration.thinkTimeoutSeconds)
  }

  // MARK: - Timeout handling

  private func scheduleTimeout(for targetState: ConversationState, after seconds: Double) {
    timeoutTask?.cancel()
    timeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      guard let self = self else { return }
      await self.timeoutReached(target: targetState)
    }
  }

  private func timeoutReached(target targetState: ConversationState) async {
    guard state == targetState else { return }
    await cancelTimeout()
    await stopSpeaking(reason: .timeout)
    emit(
      ConversationTimeoutEvent(
        stateAtTimeout: targetState, timeoutKind: "\(targetState.rawValue) timeout"))
    transition(to: .timeout, reason: "\(targetState.rawValue) timeout")
  }

  private func cancelTimeout() async {
    timeoutTask?.cancel()
    timeoutTask = nil
  }

  // MARK: - Helpers

  private func transition(to newState: ConversationState, reason: String) {
    let oldState = state
    state = newState
    if newState != oldState {
      emit(ConversationStateEvent(state: newState, previousState: oldState, reason: reason))
    }
    Task {
      await logger.debug("Conversation -> \(newState.rawValue): \(reason)", actor: .audio)
    }
  }

  private func emit<P: EventPayload>(_ payload: P) {
    let envelope: EventEnvelope<P>
    if let context = activeTurnContext {
      envelope = context.envelope(
        actor: .system, sensitivity: .internalLevel, payload: payload)
    } else {
      envelope = EventEnvelope(
        correlationID: UUID(),
        causationID: UUID(),
        actor: .system,
        sensitivity: .internalLevel,
        payload: payload)
    }
    Task {
      await eventBus.emit(envelope)
    }
  }

  private func currentTime() -> TimeInterval {
    Date().timeIntervalSince1970
  }
}

// MARK: - Thread-safe mutable box for isolated non-Sendable state

/// Holds a mutable value in a `@unchecked Sendable` box. Used inside an actor
/// task boundary to avoid capturing non-Sendable state across `Task` closures.
private final class SentValueBox<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: T

  init(initial value: T) {
    self._value = value
  }

  var value: T {
    get {
      lock.withLock { _value }
    }
    set {
      lock.withLock { _value = newValue }
    }
  }
}
