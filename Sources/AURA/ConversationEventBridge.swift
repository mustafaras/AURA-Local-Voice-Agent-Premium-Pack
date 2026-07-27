import AuraAgent
import AuraCore
import Foundation

/// Bridges `WakeActivationEvent`/`STTStableSegmentEvent`/`STTPartialEvent`
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
  private var subscribed = false

  init(conversation: Conversation, eventBus: AuraEventBus) {
    self.conversation = conversation
    self.eventBus = eventBus
  }

  /// Subscribe to all three events. Must be called before `AuraAudio
  /// .start()` in `AuraKernel`'s construction sequence.
  func start() async {
    guard !subscribed else { return }
    subscribed = true
    await eventBus.subscribe(WakeActivationEvent.self) { [weak self] envelope in
      guard envelope.payload.isActive else { return }
      await self?.conversation.wakeActivationStarted(privacyMode: envelope.payload.privacyMode)
    }
    await eventBus.subscribe(STTStableSegmentEvent.self) { [weak self] envelope in
      await self?.conversation.stableSegmentReceived(envelope.payload)
    }
    await eventBus.subscribe(STTPartialEvent.self) { [weak self] envelope in
      await self?.conversation.partialTranscriptReceived(envelope.payload)
    }
  }
}
