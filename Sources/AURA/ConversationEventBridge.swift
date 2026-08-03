import AuraAgent
import AuraCore
import Foundation

/// Bridges wake, transcript, and STT-health events
/// (all emitted on the event bus by `WakeWordPipeline`/`STTPipeline`) into
/// `Conversation`'s direct actor methods.
///
/// `Conversation` never subscribes to the event bus itself (confirmed: no
/// `eventBus.subscribe` call anywhere in `Sources/AuraAgent/Conversation
/// .swift`) — every transition is a method call a caller must make. Before
/// this phase, nothing made these three calls in production; `STTPipeline`
/// already self-subscribes to `WakeActivationEvent` for its own purposes
/// (starting/stopping transcription), so the wake→STT leg needed no bridge,
/// but the wake→`Conversation` and STT-result→`Conversation` legs did.
///
/// Composition-root-local glue, not a reusable library type.
actor ConversationEventBridge {
  private let conversation: Conversation
  private let eventBus: AuraEventBus
  private let sessionID: UUID
  private var subscribed = false

  init(conversation: Conversation, eventBus: AuraEventBus, sessionID: UUID = UUID()) {
    self.conversation = conversation
    self.eventBus = eventBus
    self.sessionID = sessionID
  }

  /// Subscribe to all three events. Must be called before `AuraAudio
  /// .start()` in `AuraKernel`'s construction sequence.
  func start() async {
    guard !subscribed else { return }
    subscribed = true
    await eventBus.subscribe(WakeActivationEvent.self) { [weak self] envelope in
      guard envelope.payload.isActive else { return }
      guard let self else { return }
      let context = envelope.payload.turnContext ?? TurnContext(
        sessionID: self.sessionID,
        correlationID: envelope.correlationID,
        causationID: envelope.id,
        activationSource: .wakeWord,
        actor: envelope.actor,
        authority: .userUtterance,
        sensitivity: envelope.sensitivity)
      await self.conversation.wakeActivationStarted(
        privacyMode: envelope.payload.privacyMode,
        turnContext: context.advancing(causationID: envelope.id))
    }
    await eventBus.subscribe(STTStableSegmentEvent.self) { [weak self] envelope in
      await self?.conversation.stableSegmentReceived(
        envelope.payload, turnContext: envelope.payload.turnContext)
    }
    await eventBus.subscribe(STTPartialEvent.self) { [weak self] envelope in
      await self?.conversation.partialTranscriptReceived(
        envelope.payload, turnContext: envelope.payload.turnContext)
    }
    await eventBus.subscribe(STTHealthEvent.self) { [weak self] envelope in
      guard !envelope.payload.ready else { return }
      await self?.conversation.recognitionFailed(
        detail: envelope.payload.detail, turnContext: envelope.payload.turnContext)
    }
  }
}
