import AuraCore
import Foundation

extension WakeWordPipeline {
  // MARK: - Event emitters

  func emitVoiceActivityEvent(_ result: VADResult) async {
    await emit(
      VoiceActivityEvent(
        isActive: result.isSpeech,
        energyDB: result.energyDB,
        frameCount: result.frameCount)
    )
  }

  func emitWakeHypothesisEvent(_ hypothesis: WakeHypothesis, suppressed: Bool) async {
    await emit(
      WakeWordHypothesisEvent(
        confidence: hypothesis.confidence,
        matchedPhrase: hypothesis.matchedPhrase,
        suppressedAsAntiTrigger: suppressed)
    )
  }

  func emitWakeDetectedEvent(_ hypothesis: WakeHypothesis) async {
    await emit(
      WakeWordDetectedEvent(
        confidence: hypothesis.confidence,
        matchedPhrase: hypothesis.matchedPhrase,
        preRollFrames: 0)
    )
  }

  func emitSpeakerVerificationEvent(_ hint: SpeakerIdentityHint) async {
    await emit(
      SpeakerVerificationEvent(
        profileID: hint.profileID,
        score: hint.score,
        isMatch: hint.profileID != nil && hint.score >= configuration.speakerVerificationThreshold),
      sensitivity: .sensitive
    )
  }

  func emitWakeActivationEvent(active: Bool, privacyMode: Bool) async {
    let context: TurnContext?
    if active {
      let current =
        activeTurnContext
        ?? TurnContext(
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

  func emitPrivacyModeEvent(enabled: Bool, triggeredByKeyboardShortcut: Bool) async {
    await emit(
      PrivacyModeEvent(
        enabled: enabled,
        triggeredByKeyboardShortcut: triggeredByKeyboardShortcut)
    )
  }

  func emit<Payload: EventPayload>(
    _ payload: Payload,
    context: TurnContext? = nil,
    sensitivity: SensitivityLevel = .internalLevel
  ) async {
    let traceContext = context ?? activeTurnContext
    let envelope =
      traceContext?.envelope(
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
