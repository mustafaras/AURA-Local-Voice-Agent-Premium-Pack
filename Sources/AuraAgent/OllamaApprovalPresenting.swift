import AuraCore
import Foundation

/// Pluggable approval gate for the upfront per-request policy confirmation
/// that gates cloud-proxied Ollama inference (`.agentOllamaCloudInference`).
/// Local inference (`.agentOllamaLocalInference`, `.reversible`) is allowed
/// by default and never reaches this presenter. Mirrors
/// `CodexApprovalPresenting`/`ClaudeApprovalPresenting`/`CopilotApprovalPresenting`.
public protocol OllamaApprovalPresenting: Sendable {
  func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse
}

/// Approval presenter that always denies (safe default).
public struct OllamaAlwaysDenyApprovalPresenter: OllamaApprovalPresenting {
  public init() {}

  public func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse {
    PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: challenge.nonce,
      responseHash: challenge.expectedHash,
      accepted: false
    )
  }
}

/// Approval presenter that always allows (for deterministic test fixtures).
public struct OllamaAlwaysAllowApprovalPresenter: OllamaApprovalPresenting {
  public init() {}

  public func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse {
    PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: challenge.nonce,
      responseHash: challenge.expectedHash,
      accepted: true
    )
  }
}
