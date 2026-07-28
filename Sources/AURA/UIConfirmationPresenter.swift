import AuraAgent
import AuraCore
import AuraIntent
import Foundation

protocol AuraConfirmationPresenting:
  IntentConfirmationPresenting, CodexApprovalPresenting, ClaudeApprovalPresenting,
  CopilotApprovalPresenting, OllamaApprovalPresenting
{}

struct SafeDenyConfirmationPresenter: AuraConfirmationPresenting {
  func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse {
    PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: challenge.nonce,
      responseHash: challenge.expectedHash,
      accepted: false)
  }
}

actor UIConfirmationPresenter: AuraConfirmationPresenting {
  typealias Handler = @Sendable (PolicyConfirmationChallenge) async -> Bool
  private var handler: Handler?

  func setHandler(_ handler: @escaping Handler) {
    self.handler = handler
  }

  func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse {
    let accepted: Bool
    if challenge.expiresAt <= Date() {
      accepted = false
    } else {
      accepted = await handler?(challenge) ?? false
    }
    return PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: challenge.nonce,
      responseHash: challenge.expectedHash,
      accepted: accepted && challenge.expiresAt > Date())
  }
}
