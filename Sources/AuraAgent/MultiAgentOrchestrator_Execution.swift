import AuraCore
import AuraPolicy
import AuraShell
import Foundation

extension MultiAgentOrchestrator {
  // MARK: - Role agent execution

  enum RoleRunResult {
    case succeeded(text: String)
    case failed(reason: String)
  }

  static func runToCompletion(
    agent: any OrchestratedAgentRunning,
    request: OrchestratedAgentRunRequest
  ) async -> RoleRunResult {
    let stream = await agent.run(request)

    var textParts: [String] = []
    var failureReason: String?
    var sawTurnCompleted = false

    do {
      for try await event in stream {
        switch event {
        case .text(_, let content):
          textParts.append(content)
        case .approvalDenied(let reason):
          failureReason = "denied by policy: \(reason ?? "no reason given")"
        case .turnCompleted:
          sawTurnCompleted = true
        case .turnFailed(let message):
          failureReason = message ?? "turn failed"
        case .budgetExceeded(let kind, let limit, let observed):
          failureReason = "budget exceeded: \(kind) limit=\(limit) observed=\(observed)"
        }
      }
    } catch {
      failureReason = "\(error)"
    }

    if let failureReason {
      return .failed(reason: failureReason)
    }
    guard sawTurnCompleted else {
      return .failed(reason: "agent stream ended without a completion signal")
    }
    return .succeeded(text: textParts.joined(separator: "\n"))
  }

  // MARK: - Completion audit

  func completeRun(
    runID: UUID, outcome: OrchestrationOutcome, iterations: Int, actor: ActorID
  ) async {
    let outcomeType: OrchestrationRunCompletedEvent.Outcome
    let summary: String
    switch outcome {
    case .approved(let path, let branch, _):
      outcomeType = .approved
      summary = "approved: \(path) (\(branch))"
    case .escalated(let path, let branch, _, let conflicts):
      outcomeType = .escalated
      summary = "escalated after \(conflicts.count) conflict(s): \(path) (\(branch))"
    case .failed(let reason):
      outcomeType = .failed
      summary = reason
    case .budgetExceeded(let reason):
      outcomeType = .budgetExceeded
      summary = reason
    }
    await emit(
      OrchestrationRunCompletedEvent(
        runID: runID, outcome: outcomeType, iterations: iterations, summary: summary),
      actor: actor, correlationID: runID, causationID: runID)
  }

  func emit<Payload: EventPayload>(
    _ payload: Payload,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}
