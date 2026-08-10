import AuraAudio
import AuraCore
import Foundation

/// Ends an explicit Push-to-Talk turn after speech followed by configured
/// silence, with a hard deadline below the conversation listening timeout.
///
/// The detector receives only volatile in-memory frames. It emits one matching
/// inactive `WakeActivationEvent`; `STTPipeline` owns the actual STT
/// finalization in response to that event.
actor PushToTalkSessionFinalizer {
  private let vad: any VoiceActivityDetector
  private let eventBus: AuraEventBus
  private let maxDurationSeconds: Double
  private let sessionID: UUID

  private var isActive = false
  private var heardSpeech = false
  private var activeTurnContext: TurnContext?
  private var generation = UUID()
  private var deadlineTask: Task<Void, Never>?
  private var subscribed = false

  init(
    vad: any VoiceActivityDetector,
    eventBus: AuraEventBus,
    maxDurationSeconds: Double,
    sessionID: UUID = UUID()
  ) {
    self.vad = vad
    self.eventBus = eventBus
    self.maxDurationSeconds = max(0.05, maxDurationSeconds)
    self.sessionID = sessionID
  }

  func start() async {
    guard !subscribed else { return }
    subscribed = true
    await eventBus.subscribe(WakeActivationEvent.self) { [weak self] envelope in
      await self?.handleActivation(envelope)
    }
  }

  func stop() {
    deadlineTask?.cancel()
    deadlineTask = nil
    isActive = false
    heardSpeech = false
    activeTurnContext = nil
    generation = UUID()
    vad.reset()
  }

  func ingest(_ frame: AudioFrame) async {
    guard isActive else { return }
    let result = vad.analyze(frame)
    if result.isSpeech {
      heardSpeech = true
      return
    }
    guard heardSpeech else { return }
    await finishCurrentTurn()
  }

  private func handleActivation(_ envelope: EventEnvelope<WakeActivationEvent>) {
    let event = envelope.payload
    guard event.isActive else {
      deadlineTask?.cancel()
      deadlineTask = nil
      isActive = false
      heardSpeech = false
      activeTurnContext = nil
      return
    }

    deadlineTask?.cancel()
    vad.reset()
    isActive = true
    heardSpeech = false
    activeTurnContext =
      event.turnContext
      ?? TurnContext(
        sessionID: sessionID,
        correlationID: envelope.correlationID,
        causationID: envelope.id,
        activationSource: .pushToTalk,
        actor: envelope.actor,
        authority: .userUtterance,
        sensitivity: envelope.sensitivity)
    generation = UUID()
    let armedGeneration = generation
    deadlineTask = Task { [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: .seconds(self.maxDurationSeconds))
      guard !Task.isCancelled else { return }
      await self.finishCurrentTurn(expectedGeneration: armedGeneration)
    }
  }

  private func finishCurrentTurn(expectedGeneration: UUID? = nil) async {
    guard isActive else { return }
    if let expectedGeneration, expectedGeneration != generation { return }

    isActive = false
    heardSpeech = false
    deadlineTask?.cancel()
    deadlineTask = nil

    let context = activeTurnContext
    let envelope =
      context?.envelope(
        actor: .user,
        sensitivity: .sensitive,
        payload: WakeActivationEvent(
          isActive: false, privacyMode: false, turnContext: context))
      ?? EventEnvelope(
        correlationID: sessionID,
        causationID: sessionID,
        actor: .user,
        sensitivity: .sensitive,
        payload: WakeActivationEvent(isActive: false, privacyMode: false))
    await eventBus.emit(envelope)
    activeTurnContext = nil
  }
}
