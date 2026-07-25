import Foundation

// MARK: - Codex CLI adapter event payloads
//
// "Approval need" in this normalized model is the upfront, per-run
// `PolicyConfirmationChallenge`/`submitConfirmation` cycle evaluated before a
// process is ever spawned — `codex exec` always runs with `-a never`, so no
// Codex-native mid-run approval prompt exists to normalize.

/// Emitted when a Codex CLI run is about to be spawned, after policy allows it.
public struct CodexRunStartedEvent: EventPayload {
  public static let eventType = "codex.run.started"

  public let runID: UUID
  public let sandbox: String
  public let model: String?
  public let workingDirectory: String
  public let ephemeral: Bool
  public let startedAt: Date

  public init(
    runID: UUID,
    sandbox: String,
    model: String? = nil,
    workingDirectory: String,
    ephemeral: Bool,
    startedAt: Date = Date()
  ) {
    self.runID = runID
    self.sandbox = sandbox
    self.model = model
    self.workingDirectory = workingDirectory
    self.ephemeral = ephemeral
    self.startedAt = startedAt
  }
}

/// Emitted when a run requires explicit user confirmation before it may proceed.
public struct CodexApprovalRequestedEvent: EventPayload {
  public static let eventType = "codex.approval.requested"

  public let requestID: UUID
  public let sessionID: UUID
  public let riskTier: PermissionRiskTier
  public let targetSummary: String
  public let expiresAt: Date
  public let requestedAt: Date

  public init(
    requestID: UUID,
    sessionID: UUID,
    riskTier: PermissionRiskTier,
    targetSummary: String,
    expiresAt: Date,
    requestedAt: Date = Date()
  ) {
    self.requestID = requestID
    self.sessionID = sessionID
    self.riskTier = riskTier
    self.targetSummary = targetSummary
    self.expiresAt = expiresAt
    self.requestedAt = requestedAt
  }
}

/// Emitted once a policy confirmation challenge has been resolved.
public struct CodexApprovalDecisionEvent: EventPayload {
  public static let eventType = "codex.approval.decision"

  public enum Decision: String, Codable, Sendable, Equatable {
    case allow
    case deny
  }

  public let requestID: UUID
  public let decision: Decision
  public let reason: String?
  public let decidedAt: Date

  public init(
    requestID: UUID,
    decision: Decision,
    reason: String? = nil,
    decidedAt: Date = Date()
  ) {
    self.requestID = requestID
    self.decision = decision
    self.reason = reason
    self.decidedAt = decidedAt
  }
}

/// Emitted for a normalized plan-update item observed in the JSONL stream.
///
/// `rawItemType`/`summary` are verbatim passthrough from Codex's own item
/// payload; exact field names beyond the verified top-level discriminator are
/// not part of the public Codex CLI schema, so this type intentionally does
/// not attempt fine-grained structured extraction.
public struct CodexPlanUpdateEvent: EventPayload {
  public static let eventType = "codex.plan.update"

  public let runID: UUID
  public let rawItemType: String
  public let summary: String
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    rawItemType: String,
    summary: String,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.rawItemType = rawItemType
    self.summary = summary
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for a normalized file-change item observed in the JSONL stream.
public struct CodexFileChangeEvent: EventPayload {
  public static let eventType = "codex.file.change"

  public let runID: UUID
  public let rawItemType: String
  public let filePathHint: String?
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    rawItemType: String,
    filePathHint: String? = nil,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.rawItemType = rawItemType
    self.filePathHint = filePathHint
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for a normalized command-execution item that looks like a test run.
public struct CodexTestRunEvent: EventPayload {
  public static let eventType = "codex.test.run"

  public let runID: UUID
  public let rawItemType: String
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    rawItemType: String,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.rawItemType = rawItemType
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted when a Codex turn completes (successfully or not).
public struct CodexTurnCompletedEvent: EventPayload {
  public static let eventType = "codex.turn.completed"

  public enum Outcome: String, Codable, Sendable, Equatable {
    case succeeded
    case failed
  }

  public let runID: UUID
  public let outcome: Outcome
  public let durationSeconds: Double

  /// Raw token-usage counters as reported by `turn.completed`'s `usage`
  /// object. Intentionally untyped: the exact key names are not part of the
  /// documented public schema, so this is a deliberate exception to the
  /// plain-typed-field convention used elsewhere in this file.
  public let observedTokenUsage: [String: Int]

  public let addedFileCount: Int
  public let removedFileCount: Int
  public let modifiedFileCount: Int
  public let filesystemDiffDigest: String?
  public let completedAt: Date

  public init(
    runID: UUID,
    outcome: Outcome,
    durationSeconds: Double,
    observedTokenUsage: [String: Int] = [:],
    addedFileCount: Int = 0,
    removedFileCount: Int = 0,
    modifiedFileCount: Int = 0,
    filesystemDiffDigest: String? = nil,
    completedAt: Date = Date()
  ) {
    self.runID = runID
    self.outcome = outcome
    self.durationSeconds = durationSeconds
    self.observedTokenUsage = observedTokenUsage
    self.addedFileCount = addedFileCount
    self.removedFileCount = removedFileCount
    self.modifiedFileCount = modifiedFileCount
    self.filesystemDiffDigest = filesystemDiffDigest
    self.completedAt = completedAt
  }
}

/// Emitted whenever a Codex run fails for any reason.
public struct CodexErrorEvent: EventPayload {
  public static let eventType = "codex.error"

  public enum Category: String, Codable, Sendable, Equatable {
    case cliLaunchFailed
    case decodeFailed
    case budgetExceeded
    case policyDenied
    case timedOut
    case cancelled
    case processExitedNonZero
    case unknown
  }

  public let runID: UUID
  public let category: Category
  public let message: String
  public let occurredAt: Date

  public init(
    runID: UUID,
    category: Category,
    message: String,
    occurredAt: Date = Date()
  ) {
    self.runID = runID
    self.category = category
    self.message = message
    self.occurredAt = occurredAt
  }
}

/// Emitted when a run is cancelled because it exceeded a configured budget.
public struct CodexBudgetExceededEvent: EventPayload {
  public static let eventType = "codex.budget.exceeded"

  public enum Kind: String, Codable, Sendable, Equatable {
    case time
    case fileWrites
    case tokens
    case costUSD
  }

  public let runID: UUID
  public let kind: Kind
  public let limit: Double
  public let observed: Double
  public let exceededAt: Date

  public init(
    runID: UUID,
    kind: Kind,
    limit: Double,
    observed: Double,
    exceededAt: Date = Date()
  ) {
    self.runID = runID
    self.kind = kind
    self.limit = limit
    self.observed = observed
    self.exceededAt = exceededAt
  }
}
