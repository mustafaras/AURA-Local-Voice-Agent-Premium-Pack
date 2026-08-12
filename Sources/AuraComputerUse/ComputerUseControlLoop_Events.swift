import AuraCore
import AuraPolicy
import AuraScreen
import Foundation

struct StepBlockInput {
  let runID: UUID
  let iteration: Int
  let step: ComputerUseActionStep
  let reason: ComputerUseStepBlockReason
}

extension ComputerUseControlLoop {
  // MARK: - Event helpers

  func emitStepBlocked(
    _ input: StepBlockInput,
    correlationID: UUID,
    actor: ActorID
  ) async {
    await emit(
      ComputerUseStepEvent(
        runID: input.runID,
        iteration: input.iteration,
        stepID: input.step.id,
        semanticIntent: input.step.semanticIntent,
        usedAccessibilityAnchor: false, executed: false, blockReason: input.reason),
      correlationID: correlationID, actor: actor)
  }

  func complete(runID: UUID, outcome: ComputerUseLoopOutcome, actor: ActorID) async {
    await emit(
      ComputerUseLoopCompletedEvent(
        runID: runID, outcomeDescription: Self.describe(outcome),
        iterations: Self.iterations(of: outcome)),
      correlationID: runID, actor: actor)
  }

  func emit<Payload: EventPayload>(_ payload: Payload, correlationID: UUID, actor: ActorID)
    async
  {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: correlationID, actor: actor,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }

  private static func describe(_ outcome: ComputerUseLoopOutcome) -> String {
    switch outcome {
    case .completed: return "completed"
    case .noProgress: return "noProgress"
    case .iterationBudgetExhausted: return "iterationBudgetExhausted"
    case .emergencyStopped: return "emergencyStopped"
    case .unexpectedModalDialog: return "unexpectedModalDialog"
    case .identityChanged: return "identityChanged"
    case .confirmationRequired: return "confirmationRequired"
    case .mandatoryConfirmationBlocked(let intent, _):
      return "mandatoryConfirmationBlocked(\(intent.rawValue))"
    case .invalidPlan(let reason, _): return "invalidPlan(\(reason))"
    case .failed(let reason, _): return "failed(\(reason))"
    }
  }

  private static func iterations(of outcome: ComputerUseLoopOutcome) -> Int {
    switch outcome {
    case .completed(let iterations): return iterations
    case .noProgress(let iterations): return iterations
    case .iterationBudgetExhausted(let iterations): return iterations
    case .emergencyStopped(let iterations): return iterations
    case .unexpectedModalDialog(let iterations): return iterations
    case .identityChanged(let iterations): return iterations
    case .confirmationRequired(_, let iterations): return iterations
    case .mandatoryConfirmationBlocked(_, let iterations): return iterations
    case .invalidPlan(_, let iterations): return iterations
    case .failed(_, let iterations): return iterations
    }
  }
}
