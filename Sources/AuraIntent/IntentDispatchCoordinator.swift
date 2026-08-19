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

  /// Build a bounded plan through `CapabilityPlanner` and execute it through
  /// the same `ToolRouter` this coordinator dispatches single intents to.
  ///
  /// The coordinator owns the router privately, so this is the seam through
  /// which the kernel reaches multi-step execution — rather than widening the
  /// router's ownership, which would let a caller reach `routePlan` with a
  /// plan the planner never validated.
  public func executePlan(
    steps: [PlanStepRequest],
    context: TurnContext
  ) async throws(AuraError) -> PlanExecutionReport {
    let planner = CapabilityPlanner(registry: await toolRouter.capabilityRegistry)
    switch await planner.buildPlan(steps: steps) {
    case .failure(let failure):
      throw AuraError.invalidConfiguration("plan rejected: \(failure.blockedReason)")
    case .success(let plan):
      return await toolRouter.routePlan(plan, context: context)
    }
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
    let context =
      envelope.payload.turnContext
      ?? TurnContext(
        sessionID: sessionID,
        correlationID: envelope.correlationID,
        causationID: envelope.id,
        activationSource: .text,
        actor: envelope.actor,
        authority: .userUtterance,
        sensitivity: envelope.sensitivity)
    let intent = await intentEngine.classify(
      envelope.payload, context: context.advancing(causationID: envelope.id))
    let dialogueContext = await intentEngine.dialogueContextItems()
    let outcome = await toolRouter.route(
      intent,
      context: intent.turnContext ?? context,
      dialogueContext: dialogueContext)
    let isSimpleCommand = isSimpleLocalCommand(intent: intent, outcome: outcome)
    let responseContext = (intent.turnContext ?? context).withBackendIDs(
      TurnBackendIDs(
        stt: intent.turnContext?.backendIDs.stt,
        tts: intent.turnContext?.backendIDs.tts,
        model: intent.turnContext?.backendIDs.model,
        tool: toolID(for: intent)))
    await conversation.responsePlanReceived(
      responsePlan(
        for: outcome,
        isSimpleCommand: isSimpleCommand,
        language: intent.language,
        context: responseContext))
  }

  private func toolID(for intent: TypedIntent) -> String? {
    switch intent.kind {
    case .converse: return "aura.converse"
    case .appActivate: return "automation.appActivate"
    case .appTerminate: return "automation.appTerminate"
    case .shellExecute: return "shell.execute"
    case .codingAgentRun: return "agent.codingAgentRun"
    case .fileOpen: return "filesystem.open_file"
    case .fileReveal: return "filesystem.reveal"
    case .urlOpen: return "url.open"
    case .browserRead: return "browser.read"
    case .mailRead: return "mail.read"
    case .calendarRead: return "calendar.read"
    case .contactsLookup: return "contacts.lookup"
    case .unknown: return nil
    }
  }

  /// A "simple command" is a local intent that resolves to a single tool
  /// outcome without calling a remote model. In the v1 vocabulary this is
  /// `.appActivate`, `.appTerminate`, `.shellExecute`, `.converse` (the
  /// templated reply is deterministic), and the SP-005 filesystem/URL
  /// capabilities (local, reversible, deterministic). `.codingAgentRun` and
  /// blocked paths are excluded because they may involve long-running CLI
  /// agents or policy review that should not be held against the
  /// simple-command budget.
  private func isSimpleLocalCommand(intent: TypedIntent, outcome: IntentExecutionOutcome) -> Bool {
    // SP-010: the three device-local reads join this list; `.mailRead` does
    // not. Mail is the one read that leaves the machine, so holding a
    // provider round trip to the simple-command budget would mean reporting a
    // normal network wait as a latency regression.
    let localKinds: [IntentKind] = [
      .converse, .appActivate, .appTerminate, .shellExecute,
      .fileOpen, .fileReveal, .urlOpen,
      .browserRead, .calendarRead, .contactsLookup,
    ]
    guard localKinds.contains(intent.kind) else { return false }
    switch outcome {
    case .executed, .acknowledgedAsync:
      return true
    case .blockedByPolicy, .blockedPendingConfirmationDenied, .ambiguous, .failed:
      return false
    }
  }

  private func responsePlan(
    for outcome: IntentExecutionOutcome,
    isSimpleCommand: Bool,
    language: DialogueLanguage,
    context: TurnContext
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
      isSimpleCommand: isSimpleCommand,
      language: language,
      turnContext: context)
  }
}
