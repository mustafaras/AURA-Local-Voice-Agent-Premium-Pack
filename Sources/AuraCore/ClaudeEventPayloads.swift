import Foundation

// MARK: - Claude Code CLI adapter event payloads
//
// "Approval need" in this normalized model is the upfront, per-run
// `PolicyConfirmationChallenge`/`submitConfirmation` cycle evaluated before a
// process is ever spawned — `claude -p` always runs with
// `--permission-mode dontAsk`, which denies rather than prompts, so no
// mid-run interactive approval exists to normalize.

/// Emitted when a Claude Code run is about to be spawned, after policy allows it.
public struct ClaudeRunStartedEvent: EventPayload {
  public static let eventType = "claude.run.started"

  public let runID: UUID
  public let permissionMode: String
  public let model: String?
  public let workingDirectory: String
  public let ephemeral: Bool
  public let startedAt: Date

  public init(
    runID: UUID,
    permissionMode: String,
    model: String? = nil,
    workingDirectory: String,
    ephemeral: Bool,
    startedAt: Date = Date()
  ) {
    self.runID = runID
    self.permissionMode = permissionMode
    self.model = model
    self.workingDirectory = workingDirectory
    self.ephemeral = ephemeral
    self.startedAt = startedAt
  }
}

/// Emitted when a run requires explicit user confirmation before it may proceed.
public struct ClaudeApprovalRequestedEvent: EventPayload {
  public static let eventType = "claude.approval.requested"

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
public struct ClaudeApprovalDecisionEvent: EventPayload {
  public static let eventType = "claude.approval.decision"

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

/// Emitted for the confirmed `system`/`init` event: session metadata reported
/// once at the start of every run.
public struct ClaudeSessionInitEvent: EventPayload {
  public static let eventType = "claude.session.init"

  public let runID: UUID
  public let claudeSessionID: String
  public let model: String
  public let permissionMode: String
  public let toolCount: Int
  public let mcpServerCount: Int
  public let claudeCodeVersion: String
  public let apiKeySource: String
  public let observedAt: Date

  public init(
    runID: UUID,
    claudeSessionID: String,
    model: String,
    permissionMode: String,
    toolCount: Int,
    mcpServerCount: Int,
    claudeCodeVersion: String,
    apiKeySource: String,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.claudeSessionID = claudeSessionID
    self.model = model
    self.permissionMode = permissionMode
    self.toolCount = toolCount
    self.mcpServerCount = mcpServerCount
    self.claudeCodeVersion = claudeCodeVersion
    self.apiKeySource = apiKeySource
    self.observedAt = observedAt
  }
}

/// Emitted for a confirmed `assistant`/`user` message text block.
public struct ClaudeMessageEvent: EventPayload {
  public static let eventType = "claude.message"

  public let runID: UUID
  public let role: String
  public let text: String
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    role: String,
    text: String,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.role = role
    self.text = text
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for a confirmed `system`/`hook_started` or `hook_response` event.
/// Only ever reflects hooks from the `settingSources` explicitly loaded
/// (default: the operating user's own trusted `~/.claude/settings.json`
/// only) — see `ClaudeConfiguration.settingSources`.
public struct ClaudeHookEvent: EventPayload {
  public static let eventType = "claude.hook"

  public let runID: UUID
  public let hookName: String
  public let hookEvent: String
  public let outcome: String?
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    hookName: String,
    hookEvent: String,
    outcome: String? = nil,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.hookName = hookName
    self.hookEvent = hookEvent
    self.outcome = outcome
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for a confirmed top-level `rate_limit_event`.
public struct ClaudeRateLimitEvent: EventPayload {
  public static let eventType = "claude.rateLimit"

  public let runID: UUID
  public let status: String
  public let rateLimitType: String
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    status: String,
    rateLimitType: String,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.status = status
    self.rateLimitType = rateLimitType
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for a tool-use/tool-result content block. The authorized smoke
/// test used `--tools ""` (no tools available), so these shapes were never
/// observed; carried opaquely rather than with fabricated structured fields
/// — see ADR-012.
public struct ClaudeToolEvent: EventPayload {
  public static let eventType = "claude.tool"

  public let runID: UUID
  public let rawContentType: String
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    rawContentType: String,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.rawContentType = rawContentType
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for the confirmed final `result` event.
public struct ClaudeTurnCompletedEvent: EventPayload {
  public static let eventType = "claude.turn.completed"

  public enum Outcome: String, Codable, Sendable, Equatable {
    case succeeded
    case failed
  }

  public let runID: UUID
  public let outcome: Outcome
  public let resultText: String
  public let totalCostUSD: Double
  public let numTurns: Int
  public let durationMs: Int
  public let stopReason: String?
  public let permissionDenialCount: Int
  public let completedAt: Date

  public init(
    runID: UUID,
    outcome: Outcome,
    resultText: String,
    totalCostUSD: Double,
    numTurns: Int,
    durationMs: Int,
    stopReason: String? = nil,
    permissionDenialCount: Int = 0,
    completedAt: Date = Date()
  ) {
    self.runID = runID
    self.outcome = outcome
    self.resultText = resultText
    self.totalCostUSD = totalCostUSD
    self.numTurns = numTurns
    self.durationMs = durationMs
    self.stopReason = stopReason
    self.permissionDenialCount = permissionDenialCount
    self.completedAt = completedAt
  }
}

/// Emitted whenever a Claude Code run fails for any reason.
public struct ClaudeErrorEvent: EventPayload {
  public static let eventType = "claude.error"

  public enum Category: String, Codable, Sendable, Equatable {
    case cliLaunchFailed
    case decodeFailed
    case budgetExceeded
    case policyDenied
    case timedOut
    case cancelled
    case processExitedNonZero
    case apiError
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
public struct ClaudeBudgetExceededEvent: EventPayload {
  public static let eventType = "claude.budget.exceeded"

  public enum Kind: String, Codable, Sendable, Equatable {
    case time
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
