import CryptoKit
import Foundation

// MARK: - Decision and confirmation types

/// Result of a policy evaluation.
public enum PolicyDecision: Codable, Sendable, Equatable {
  case allow(auditID: UUID, grantID: UUID?)
  case deny(reason: String, auditID: UUID)
  case confirm(challenge: PolicyConfirmationChallenge, auditID: UUID)
}
