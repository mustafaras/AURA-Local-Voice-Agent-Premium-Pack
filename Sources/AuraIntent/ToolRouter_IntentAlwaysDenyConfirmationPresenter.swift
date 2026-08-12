import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

/// Confirmation presenter that always denies (safe default — this phase
/// has no real interactive voice/UI confirmation surface yet).
public struct IntentAlwaysDenyConfirmationPresenter: IntentConfirmationPresenting {
  public init() {}

  public func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse {
    PolicyConfirmationResponse(
      requestID: challenge.requestID, nonce: challenge.nonce, responseHash: challenge.expectedHash,
      accepted: false)
  }
}
