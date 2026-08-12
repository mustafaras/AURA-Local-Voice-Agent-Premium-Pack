import AuraAudio
import AuraCore
import Foundation

extension Conversation {
  // MARK: - Helpers

  func transition(to newState: ConversationState, reason: String) {
    let oldState = state
    state = newState
    if newState != oldState {
      emit(ConversationStateEvent(state: newState, previousState: oldState, reason: reason))
    }
    Task {
      await logger.debug(
        "Conversation transition [state=\(newState.rawValue), reasonPresent=\(!reason.isEmpty)]",
        actor: .audio)
    }
  }

  func emit<P: EventPayload>(_ payload: P) {
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

  func currentTime() -> TimeInterval {
    Date().timeIntervalSince1970
  }
}
