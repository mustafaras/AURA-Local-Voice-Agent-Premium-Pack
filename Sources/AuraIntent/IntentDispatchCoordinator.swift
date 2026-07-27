import AuraAgent
import AuraCore
import Foundation

/// Bridges `Conversation`'s `TurnCompletedEvent` (emitted on the event bus,
/// with no subscriber before this phase) through `IntentEngine`/
/// `ToolRouter` and back into `Conversation.responsePlanReceived(_:)` — a
/// direct actor method call, since `Conversation` itself never subscribes
/// to the bus for its response plan (confirmed: no `eventBus.subscribe`
/// call anywhere in `Conversation.swift`). This actor is what makes
/// `Conversation`'s own doc comment true for the first time: "it consumes
/// typed intent and response-plan events" — something had to actually
/// produce them.
public actor IntentDispatchCoordinator {
  private let intentEngine: IntentEngine
  private let toolRouter: ToolRouter
  private let conversation: Conversation
  private let eventBus: AuraEventBus
  private let sessionID: UUID
  private var subscribed = false

  public init(
    intentEngine: IntentEngine,
    toolRouter: ToolRouter,
    conversation: Conversation,
    eventBus: AuraEventBus,
    sessionID: UUID
  ) {
    self.intentEngine = intentEngine
    self.toolRouter = toolRouter
    self.conversation = conversation
    self.eventBus = eventBus
    self.sessionID = sessionID
  }

  /// Subscribe to `TurnCompletedEvent`. Must be called before `AuraAudio
  /// .start()` in `AuraKernel`'s construction sequence — `AuraEventBus`
  /// does not replay history to a late subscriber.
  public func start() async {
    guard !subscribed else { return }
    subscribed = true
    await eventBus.subscribe(TurnCompletedEvent.self) { [weak self] envelope in
      await self?.handle(envelope)
    }
  }

  private func handle(_ envelope: EventEnvelope<TurnCompletedEvent>) async {
    let intent = await intentEngine.classify(
      envelope.payload, correlationID: envelope.correlationID, causationID: envelope.id)
    let outcome = await toolRouter.route(
      intent, actor: .intent, sessionID: sessionID, correlationID: envelope.correlationID,
      causationID: envelope.id)
    await conversation.responsePlanReceived(responsePlan(for: outcome))
  }

  private func responsePlan(for outcome: IntentExecutionOutcome) -> ResponsePlanEvent {
    let summary: String
    switch outcome {
    case .executed(let text, _), .acknowledgedAsync(let text):
      summary = text
    case .blockedByPolicy(let reason):
      summary = "I can't do that: \(reason)"
    case .blockedPendingConfirmationDenied:
      summary =
        "That needs explicit confirmation, and I don't have a way to get it from you yet."
    case .ambiguous(let clarifyingQuestion):
      summary = clarifyingQuestion
    case .failed(let reason):
      summary = "Something went wrong: \(reason)"
    }
    return ResponsePlanEvent(planID: UUID().uuidString, summary: summary, hasSpokenResponse: true)
  }
}
