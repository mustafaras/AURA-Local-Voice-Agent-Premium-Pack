import AuraAudio
import AuraCore
import Foundation

extension Conversation {
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
      pendingContinuation = PendingConversationContinuation(
        event: event, context: turnContext, id: id)
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

  func completePendingContinuation(id: UUID) async {
    guard let pendingContinuation, pendingContinuation.id == id else { return }
    self.pendingContinuation = nil
    continuationTask = nil
    await completeStableSegment(
      pendingContinuation.event,
      turnContext: pendingContinuation.context)
  }

  func completeStableSegment(
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
    await logger.debug(
      "Partial transcript received [textPresent=\(!event.text.isEmpty)]",
      actor: .audio
    )
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
        "TEXT_DEMO response [act=\(event.hasSpokenResponse ? "spoken" : "silent"), "
          + "summaryPresent=\(!event.summary.isEmpty)]",
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
}
