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
    let isSimpleCommand = isSimpleLocalCommand(intent: intent, outcome: outcome)
    await conversation.responsePlanReceived(responsePlan(for: outcome, isSimpleCommand: isSimpleCommand))
  }

  /// A "simple command" is a local intent that resolves to a single tool
  /// outcome without calling a remote model. In the v1 vocabulary this is
  /// `.appActivate`, `.appTerminate`, `.shellExecute`, and `.converse` (the
  /// templated reply is deterministic). `.codingAgentRun` and blocked paths
  /// are excluded because they may involve long-running CLI agents or policy
  /// review that should not be held against the simple-command budget.
  private func isSimpleLocalCommand(intent: TypedIntent, outcome: IntentExecutionOutcome) -> Bool {
    let localKinds: [IntentKind] = [.converse, .appActivate, .appTerminate, .shellExecute]
    guard localKinds.contains(intent.kind) else { return false }
    switch outcome {
    case .executed, .acknowledgedAsync:
      return true
    case .blockedByPolicy, .blockedPendingConfirmationDenied, .ambiguous, .failed:
      return false
    }
  }

  private func responsePlan(
    for outcome: IntentExecutionOutcome, isSimpleCommand: Bool
  ) -> ResponsePlanEvent {
    let summary: String
    let hasSpokenResponse: Bool
    switch outcome {
    case .executed(let text, let spoken):
      summary = text
      hasSpokenResponse = spoken
    case .acknowledgedAsync(let text):
      summary = text
      hasSpokenResponse = true
    case .blockedByPolicy(let reason):
      summary = "I can't do that: \(reason)"
      hasSpokenResponse = true
    case .blockedPendingConfirmationDenied:
      summary =
        "That needs explicit confirmation, and I don't have a way to get it from you yet."
      hasSpokenResponse = true
    case .ambiguous(let clarifyingQuestion):
      summary = clarifyingQuestion
      hasSpokenResponse = true
    case .failed(let reason):
      summary = "Something went wrong: \(reason)"
      hasSpokenResponse = true
    }
    return ResponsePlanEvent(
      planID: UUID().uuidString, summary: summary, hasSpokenResponse: hasSpokenResponse,
      isSimpleCommand: isSimpleCommand)
  }
}
