import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

extension ToolRouter {
  /// The one place an `IntentKind` maps to a registry capability ID.
  func capabilityID(for kind: IntentKind) -> String? {
    switch kind {
    case .converse: return InitialCapabilitySet.converse.id
    case .appActivate: return InitialCapabilitySet.appActivate.id
    case .appTerminate: return InitialCapabilitySet.appTerminate.id
    case .shellExecute: return InitialCapabilitySet.shellExecuteTyped.id
    case .codingAgentRun: return InitialCapabilitySet.codingAgentRun.id
    case .unknown: return nil
    }
  }

  /// Route using the immutable turn context so every backend call inherits
  /// the original session, actor, correlation, and causation metadata.
  /// This overload retains the pre-context call shape for compatibility with
  /// adversarial fixtures; it immediately creates the same immutable context.
  public func route(
    _ intent: TypedIntent,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    dialogueContext: [DialogueContextItem] = []
  ) async -> IntentExecutionOutcome {
    let context = TurnContext(
      sessionID: sessionID, correlationID: correlationID, causationID: causationID,
      activationSource: .text, actor: actor, authority: .userUtterance,
      sensitivity: .sensitive)
    return await route(intent, context: context, dialogueContext: dialogueContext)
  }

  public func route(
    _ intent: TypedIntent,
    context: TurnContext, dialogueContext: [DialogueContextItem] = []
  ) async -> IntentExecutionOutcome {
    let contract = await resolveContract(for: intent.kind)
    let routingContext = context.withBackendIDs(
      TurnBackendIDs(
        stt: context.backendIDs.stt,
        tts: context.backendIDs.tts,
        model: context.backendIDs.model,
        tool: contract?.id))
    let executionContext = ToolExecutionContext(
      actor: context.actor,
      sessionID: context.sessionID,
      correlationID: routingContext.correlationID,
      causationID: routingContext.causationID
    )
    let outcome = await route(
      intent.withTurnContext(routingContext),
      executionContext: executionContext,
      dialogueContext: dialogueContext)
    let verified = outcome.isVerifiedExecution
    _ = await policyEngine.completeAuthorizedExecution(
      context: routingContext,
      verified: verified,
      summary: outcome.summaryForVerification)
    return outcome
  }

  func route(
    _ intent: TypedIntent,
    executionContext: ToolExecutionContext,
    dialogueContext: [DialogueContextItem] = []
  ) async -> IntentExecutionOutcome {
    guard !intent.isAmbiguous, intent.kind != .unknown else {
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "ambiguous"),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .ambiguous(clarifyingQuestion: clarifyingQuestion(for: intent))
    }

    guard let contract = await resolveContract(for: intent.kind) else {
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "noToolRegistered"),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .failed(reason: "no tool registered for \(intent.kind.rawValue)")
    }

    await emit(
      IntentPlanGeneratedEvent(
        intentID: intent.id, toolID: contract.id,
        capabilityIdentifier: contract.requiredCapability.identifier),
      correlationID: executionContext.correlationID,
      causationID: executionContext.causationID)

    switch intent.kind {
    case .converse:
      return await handleConverse(
        intent,
        executionContext: executionContext,
        dialogueContext: dialogueContext)
    case .appActivate:
      return await handleAppLifecycle(
        intent, contract: contract, terminate: false, executionContext: executionContext)
    case .appTerminate:
      return await handleAppLifecycle(
        intent, contract: contract, terminate: true, executionContext: executionContext)
    case .shellExecute:
      return await handleShellExecute(
        intent,
        actor: executionContext.actor,
        sessionID: executionContext.sessionID,
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
    case .codingAgentRun:
      return await handleCodingAgentRun(
        intent,
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
    case .unknown:
      return .ambiguous(clarifyingQuestion: clarifyingQuestion(for: intent))
    }
  }
}
