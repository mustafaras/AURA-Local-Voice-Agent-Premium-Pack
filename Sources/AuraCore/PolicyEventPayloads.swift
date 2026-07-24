import Foundation

/// Emitted when a policy evaluation is requested.
///
/// The payload intentionally avoids request arguments and environment values;
/// subscribers receive only capability, target summary, and audit IDs.
public struct PolicyEvaluationRequestedEvent: EventPayload {
  public static let eventType = "policy.evaluation.requested"

  public let requestID: UUID
  public let capabilityIdentifier: String
  public let targetSummary: String
  public let riskTier: PermissionRiskTier
  public let actor: ActorID

  public init(
    requestID: UUID,
    capabilityIdentifier: String,
    targetSummary: String,
    riskTier: PermissionRiskTier,
    actor: ActorID
  ) {
    self.requestID = requestID
    self.capabilityIdentifier = capabilityIdentifier
    self.targetSummary = targetSummary
    self.riskTier = riskTier
    self.actor = actor
  }
}

/// Emitted when a policy evaluation reaches an `allow` or `deny` decision.
public struct PolicyDecisionEvent: EventPayload {
  public static let eventType = "policy.decision"

  public let auditID: UUID
  public let requestID: UUID
  public let decision: String
  public let reason: String
  public let capabilityIdentifier: String
  public let targetSummary: String

  public init(
    auditID: UUID,
    requestID: UUID,
    decision: String,
    reason: String,
    capabilityIdentifier: String,
    targetSummary: String
  ) {
    self.auditID = auditID
    self.requestID = requestID
    self.decision = decision
    self.reason = reason
    self.capabilityIdentifier = capabilityIdentifier
    self.targetSummary = targetSummary
  }
}

/// Emitted when a confirmation challenge is issued to the user or caller.
public struct PolicyConfirmationRequestedEvent: EventPayload {
  public static let eventType = "policy.confirmation.requested"

  public let challenge: PolicyConfirmationChallenge
  public let auditID: UUID

  public init(challenge: PolicyConfirmationChallenge, auditID: UUID) {
    self.challenge = challenge
    self.auditID = auditID
  }
}

/// Emitted when a confirmation response is received and verified.
public struct PolicyConfirmationRespondedEvent: EventPayload {
  public static let eventType = "policy.confirmation.responded"

  public let requestID: UUID
  public let accepted: Bool
  public let verified: Bool
  public let auditID: UUID

  public init(requestID: UUID, accepted: Bool, verified: Bool, auditID: UUID) {
    self.requestID = requestID
    self.accepted = accepted
    self.verified = verified
    self.auditID = auditID
  }
}

/// Emitted when a grant is issued or revoked, or a deny rule is added/removed.
public struct PolicyRuleMutationEvent: EventPayload {
  public static let eventType = "policy.rule.mutation"

  public let mutation: String
  public let ruleID: UUID
  public let capabilityIdentifier: String?
  public let actor: ActorID

  public init(
    mutation: String,
    ruleID: UUID,
    capabilityIdentifier: String?,
    actor: ActorID
  ) {
    self.mutation = mutation
    self.ruleID = ruleID
    self.capabilityIdentifier = capabilityIdentifier
    self.actor = actor
  }
}
