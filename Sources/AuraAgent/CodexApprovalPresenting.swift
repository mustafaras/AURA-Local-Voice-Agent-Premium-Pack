import AuraCore
import Foundation

/// Pluggable approval gate for the upfront per-run policy confirmation.
///
/// A real implementation surfaces a system dialog or voice confirmation and
/// echoes back `challenge.expectedHash`/`nonce` only if the user actually
/// accepted; tests provide a fixed value. Mirrors
/// `VSCodeDirtyEditorConfirmation`.
public protocol CodexApprovalPresenting: Sendable {
  func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse
}

/// Approval presenter that always denies (safe default).
public struct CodexAlwaysDenyApprovalPresenter: CodexApprovalPresenting {
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
public struct CodexAlwaysAllowApprovalPresenter: CodexApprovalPresenting {
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
