import CryptoKit
import Foundation

/// Tamper-evident challenge issued when a request requires confirmation.
public struct PolicyConfirmationChallenge: Codable, Sendable, Equatable {
  /// ID of the originating `PolicyEvaluationRequest`.
  public let requestID: UUID
  /// Session-scoped identifier for per-session confirmation tracking.
  public let sessionID: UUID
  public let nonce: String
  public let issuedAt: Date
  public let requestedAction: Capability
  public let targetSummary: String
  public let riskTier: PermissionRiskTier
  public let expiresAt: Date
  public let expectedHash: String
  public let planHash: String?
  public let turnContext: TurnContext?
  public let transactionID: UUID?

  public init(
    requestID: UUID,
    sessionID: UUID,
    nonce: String,
    issuedAt: Date,
    requestedAction: Capability,
    targetSummary: String,
    riskTier: PermissionRiskTier,
    expiresAt: Date,
    expectedHash: String,
    planHash: String? = nil,
    turnContext: TurnContext? = nil,
    transactionID: UUID? = nil
  ) {
    self.requestID = requestID
    self.sessionID = sessionID
    self.nonce = nonce
    self.issuedAt = issuedAt
    self.requestedAction = requestedAction
    self.targetSummary = targetSummary
    self.riskTier = riskTier
    self.expiresAt = expiresAt
    self.expectedHash = expectedHash
    self.planHash = planHash
    self.turnContext = turnContext
    self.transactionID = transactionID
  }
}
