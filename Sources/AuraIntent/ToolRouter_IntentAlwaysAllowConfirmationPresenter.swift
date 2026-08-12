import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

/// Confirmation presenter that always allows — deterministic test fixture
/// only, never the production default.
public struct IntentAlwaysAllowConfirmationPresenter: IntentConfirmationPresenting {
  public init() {}

  public func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse {
    PolicyConfirmationResponse(
      requestID: challenge.requestID, nonce: challenge.nonce, responseHash: challenge.expectedHash,
      accepted: true)
  }
}
