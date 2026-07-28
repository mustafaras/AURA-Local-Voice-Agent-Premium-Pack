import Foundation

// MARK: - Context engine event payloads

/// Emitted after `ContextEngine.reconstruct` assembles a bundle.
public struct ContextBundleAssembledEvent: EventPayload {
  public static let eventType = "context.bundle.assembled"

  public let sessionID: UUID
  public let itemCount: Int
  public let consideredCandidateCount: Int
  public let droppedCandidateCount: Int
  public let assembledAt: Date

  public init(
    sessionID: UUID,
    itemCount: Int,
    consideredCandidateCount: Int,
    droppedCandidateCount: Int,
    assembledAt: Date = Date()
  ) {
    self.sessionID = sessionID
    self.itemCount = itemCount
    self.consideredCandidateCount = consideredCandidateCount
    self.droppedCandidateCount = droppedCandidateCount
    self.assembledAt = assembledAt
  }
}

/// Emitted after `ContextEngine.resolveReference` reaches an outcome.
///
/// `outcome == .blockedWeakEvidence` is the mechanically-enforced proof of
/// the acceptance gate '"it" never resolves to a destructive target on weak
/// evidence' — every time that gate would otherwise have been at risk of
/// tripping, this event fires instead of a silent resolution.
public struct ReferenceResolutionEvent: EventPayload {
  public static let eventType = "context.reference.resolved"

  public enum Outcome: String, Codable, Sendable, Equatable {
    case resolved
    case ambiguous
    case blockedWeakEvidence
    case none
  }

  public let reference: String
  public let outcome: Outcome
  public let candidateCount: Int
  public let targetSummary: String?
  public let riskTier: PermissionRiskTier?
  public let resolvedAt: Date

  public init(
    reference: String,
    outcome: Outcome,
    candidateCount: Int,
    targetSummary: String? = nil,
    riskTier: PermissionRiskTier? = nil,
    resolvedAt: Date = Date()
  ) {
    self.reference = reference
    self.outcome = outcome
    self.candidateCount = candidateCount
    self.targetSummary = targetSummary
    self.riskTier = riskTier
    self.resolvedAt = resolvedAt
  }
}

/// Audit/latency summary for one complete Phase 22 builder invocation.
public struct DeepContextBuiltEvent: EventPayload {
  public static let eventType = "context.deep.built"

  public let sessionID: UUID
  public let itemCount: Int
  public let estimatedTokenCount: Int
  public let tokenBudget: Int
  public let elapsedSeconds: Double
  public let latencyBudgetSeconds: Double
  public let metLatencyBudget: Bool

  public init(
    sessionID: UUID,
    itemCount: Int,
    estimatedTokenCount: Int,
    tokenBudget: Int,
    elapsedSeconds: Double,
    latencyBudgetSeconds: Double,
    metLatencyBudget: Bool
  ) {
    self.sessionID = sessionID
    self.itemCount = itemCount
    self.estimatedTokenCount = estimatedTokenCount
    self.tokenBudget = tokenBudget
    self.elapsedSeconds = elapsedSeconds
    self.latencyBudgetSeconds = latencyBudgetSeconds
    self.metLatencyBudget = metLatencyBudget
  }
}

public struct DeepContextBuildFailedEvent: EventPayload {
  public static let eventType = "context.deep.failed"

  public let sessionID: UUID
  public let reason: String
  public let failedAt: Date

  public init(sessionID: UUID, reason: String, failedAt: Date = Date()) {
    self.sessionID = sessionID
    self.reason = reason
    self.failedAt = failedAt
  }
}
