import AuraCore
import Foundation

extension WakeWordPipeline {
  // MARK: - Event handling

  func handleFrameEvent(_ event: AudioFrameEvent) async {
    guard state == .listening || state == .activated || state == .speakerVerifying else { return }

    // Resolve the exact captured frame by sequence. A "latest frame" lookup
    // is unsafe here because the realtime producer may advance before this
    // asynchronous subscriber handles the event.
    guard let frame = retainedFrames.removeValue(forKey: event.sequenceIndex) else {
      await logger.warning(
        "Wake frame \(event.sequenceIndex) was no longer retained; dropping metadata-only input",
        actor: .audio)
      return
    }

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

  /// Retain the real frame until its matching metadata event is consumed. The
  /// map is bounded so a stalled subscriber cannot retain ambient audio.
  public func ingestSampleFrame(_ frame: AudioFrame) {
    retainedFrames[frame.sequenceIndex] = frame
    if retainedFrames.count > 8, let oldest = retainedFrames.keys.min() {
      retainedFrames.removeValue(forKey: oldest)
    }
  }

  func scheduleActivationEnd() {
    activationEndTask?.cancel()
    activationEndTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      guard let self = self, !Task.isCancelled else { return }
      await self.finalizeActivation()
    }
  }

  func finalizeActivation() async {
    state = privacyMode ? .privacyArmed : .listening
    await emitWakeActivationEvent(active: false, privacyMode: privacyMode)
  }
}
