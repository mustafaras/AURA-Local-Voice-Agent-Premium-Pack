import AuraCore
import Foundation

/// Pluggable approval gate for the upfront per-run policy confirmation.
/// Mirrors `CodexApprovalPresenting`.
public protocol ClaudeApprovalPresenting: Sendable {
  func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse
}

/// Approval presenter that always denies (safe default).
public struct ClaudeAlwaysDenyApprovalPresenter: ClaudeApprovalPresenting {
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
public struct ClaudeAlwaysAllowApprovalPresenter: ClaudeApprovalPresenting {
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
