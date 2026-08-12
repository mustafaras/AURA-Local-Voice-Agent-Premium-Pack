import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

extension ToolRouter {
  // MARK: - Shared policy resolution

  enum PolicyResolution {
    case allowed
    case blocked(IntentExecutionOutcome)
  }

  /// Evaluate policy for one router-enforced branch, resolve a `.confirm`
  /// challenge through `confirmationPresenter`, and — regardless of how
  /// `.allow` was reached — apply the hard, non-bypassable mandatory-
  /// confirmation guard. Mirrors `ComputerUseControlLoop`'s placement of
  /// `step.semanticIntent.requiresMandatoryConfirmation` immediately after
  /// receiving `.allow` (`ComputerUseControlLoop.swift:280`).
  func resolvePolicy(
    _ intent: TypedIntent,
    capability: Capability,
    target: PolicyTarget,
    executionContext: ToolExecutionContext
  ) async -> PolicyResolution {
    let request = policyRequest(
      for: intent, capability: capability, target: target, context: executionContext)
    let decision = await policyEngine.evaluate(request)
    var confirmationSatisfied = false

    switch decision {
    case .allow:
      break
    case .deny(let reason, _):
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "policyDenied: \(reason)"),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .blocked(.blockedByPolicy(reason: reason))
    case .confirm(let challenge, _):
      let response = await confirmationPresenter.present(challenge: challenge)
      let resolved = await policyEngine.submitConfirmation(response)
      guard case .allow = resolved else {
        await emit(
          IntentBlockedEvent(intentID: intent.id, reason: "confirmationDenied"),
          correlationID: executionContext.correlationID,
          causationID: executionContext.causationID)
        return .blocked(.blockedPendingConfirmationDenied)
      }
      confirmationSatisfied = true
    }

    if intent.requiresMandatoryConfirmation && !confirmationSatisfied {
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "mandatoryConfirmationRequired"),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .blocked(.blockedPendingConfirmationDenied)
    }

    if let context = intent.turnContext {
      let planHash = PolicyPlanHasher.hash(
        capability: capability,
        actor: executionContext.actor,
        target: target)
      _ = await policyEngine.beginAuthorizedExecution(context: context, planHash: planHash)
    }

    return .allowed
  }

  private func policyRequest(
    for intent: TypedIntent,
    capability: Capability,
    target: PolicyTarget,
    context: ToolExecutionContext
  ) -> PolicyEvaluationRequest {
    let turnContext =
      intent.turnContext
      ?? TurnContext(
        sessionID: context.sessionID,
        correlationID: context.correlationID,
        causationID: context.causationID,
        activationSource: .text,
        actor: context.actor,
        authority: .userUtterance,
        sensitivity: .sensitive)
    return PolicyEvaluationRequest(
      capability: capability,
      actor: context.actor,
      target: target,
      sessionID: context.sessionID,
      correlationID: context.correlationID,
      causationID: context.causationID,
      turnContext: turnContext)
  }
}
