import AuraCore
import Foundation

struct MandatoryContextInput {
  let utterance: String
  let conversationState: ConversationState
  let pendingConfirmation: PolicyConfirmationChallenge?
  let pendingTask: TaskStatus?
  let activeWorkspace: ActiveWorkspaceSnapshot?
  let referenceDate: Date
}

extension ContextEngine {
  func mandatoryItems(_ input: MandatoryContextInput) -> [ContextItem] {
    var items = [
      ContextItem(
        stage: .currentUtterance, sourceID: .utterance, summary: input.utterance,
        authority: .userStated, confidence: 1.0, observedAt: input.referenceDate,
        hasDirectEvidence: true, scopeMatch: true, sensitivity: .sensitive),
      ContextItem(
        stage: .conversationState, sourceID: .conversationState,
        summary: "conversation state: \(input.conversationState.rawValue)",
        authority: .systemDerived, confidence: 1.0, observedAt: input.referenceDate,
        hasDirectEvidence: true, scopeMatch: true, sensitivity: .internalLevel),
    ]
    if let pendingConfirmation = input.pendingConfirmation {
      items.append(
        ContextItem(
          stage: .pendingConfirmationOrTask,
          sourceID: .pendingConfirmation(requestID: pendingConfirmation.requestID),
          summary: "pending confirmation: \(pendingConfirmation.requestedAction.identifier) "
            + "on \(pendingConfirmation.targetSummary)", authority: .systemDerived, confidence: 1.0,
          observedAt: pendingConfirmation.issuedAt, hasDirectEvidence: true, scopeMatch: true,
          sensitivity: .sensitive))
    }
    if let pendingTask = input.pendingTask {
      items.append(
        ContextItem(
          stage: .pendingConfirmationOrTask, sourceID: .pendingTask(taskID: pendingTask.id),
          summary: "pending task (\(pendingTask.state.rawValue)): \(pendingTask.objective)",
          authority: .systemDerived, confidence: 1.0, observedAt: pendingTask.updatedAt,
          hasDirectEvidence: true, scopeMatch: true, sensitivity: .sensitive))
    }
    if let activeWorkspace = input.activeWorkspace {
      items.append(
        ContextItem(
          stage: .activeAppOrWorkspace, sourceID: .activeWorkspace,
          summary: activeWorkspace.summary,
          authority: .observed, confidence: 1.0, observedAt: activeWorkspace.capturedAt,
          hasDirectEvidence: true, scopeMatch: true, sensitivity: .sensitive))
    }
    return items
  }
}
