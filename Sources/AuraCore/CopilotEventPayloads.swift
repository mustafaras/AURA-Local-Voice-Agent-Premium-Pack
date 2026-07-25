import Foundation

// MARK: - GitHub Copilot CLI adapter event payloads
//
// "Approval need" in this normalized model is the upfront, per-run
// `PolicyConfirmationChallenge`/`submitConfirmation` cycle evaluated before a
// process is ever spawned. `copilot -p` requires either `--allow-all-tools`
// or exhaustive per-tool `--allow-tool` grants to run unattended at all
// (verified: `copilot help permissions`); AURA's policy decision picks the
// tool-approval tier before spawning rather than granting tools mid-run.

/// Emitted when a Copilot run is about to be spawned, after policy allows it.
public struct CopilotRunStartedEvent: EventPayload {
  public static let eventType = "copilot.run.started"

  public let runID: UUID
  public let toolProfile: String
  public let model: String?
  public let workingDirectory: String
  public let customInstructionsLoaded: Bool
  public let startedAt: Date

  public init(
    runID: UUID,
    toolProfile: String,
    model: String? = nil,
    workingDirectory: String,
    customInstructionsLoaded: Bool,
    startedAt: Date = Date()
  ) {
    self.runID = runID
    self.toolProfile = toolProfile
    self.model = model
    self.workingDirectory = workingDirectory
    self.customInstructionsLoaded = customInstructionsLoaded
    self.startedAt = startedAt
  }
}

/// Emitted when a run requires explicit user confirmation before it may proceed.
public struct CopilotApprovalRequestedEvent: EventPayload {
  public static let eventType = "copilot.approval.requested"

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
public struct CopilotApprovalDecisionEvent: EventPayload {
  public static let eventType = "copilot.approval.decision"

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

/// Emitted once per run after scanning repository customization files
/// (`.github/copilot-instructions.md`, `.github/instructions/*.instructions.md`,
/// `.github/agents/*.agent.md`, `.github/prompts/*.prompt.md`) for
/// secret-looking content, before the process is spawned.
public struct CopilotRepositoryInstructionsScanEvent: EventPayload {
  public static let eventType = "copilot.repositoryInstructions.scanned"

  public let runID: UUID
  public let filesScanned: [String]
  public let secretsDetected: Bool
  public let blockedFiles: [String]
  public let scannedAt: Date

  public init(
    runID: UUID,
    filesScanned: [String],
    secretsDetected: Bool,
    blockedFiles: [String] = [],
    scannedAt: Date = Date()
  ) {
    self.runID = runID
    self.filesScanned = filesScanned
    self.secretsDetected = secretsDetected
    self.blockedFiles = blockedFiles
    self.scannedAt = scannedAt
  }
}

/// Emitted for confirmed informational `system.*` events
/// (`session.mcp_servers_loaded`, `session.skills_loaded`,
/// `session.tools_updated`) whose payloads are not deeply typed in this
/// phase.
public struct CopilotSessionEvent: EventPayload {
  public static let eventType = "copilot.session"

  public let runID: UUID
  public let rawType: String
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    rawType: String,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.rawType = rawType
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for the confirmed `session.error` event.
public struct CopilotSessionErrorEvent: EventPayload {
  public static let eventType = "copilot.session.error"

  public let runID: UUID
  public let errorType: String
  public let errorCode: String?
  public let message: String
  public let statusCode: Int?
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    errorType: String,
    errorCode: String? = nil,
    message: String,
    statusCode: Int? = nil,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.errorType = errorType
    self.errorCode = errorCode
    self.message = message
    self.statusCode = statusCode
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for the confirmed `user.message` event.
public struct CopilotMessageEvent: EventPayload {
  public static let eventType = "copilot.message"

  public let runID: UUID
  public let role: String
  public let content: String
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    role: String,
    content: String,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.role = role
    self.content = content
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for confirmed `assistant.turn_start`/`turn_end`/`idle` and
/// `model.call_start` events.
public struct CopilotTurnEvent: EventPayload {
  public static let eventType = "copilot.turn"

  public enum Phase: String, Codable, Sendable, Equatable {
    case turnStart
    case turnEnd
    case idle
    case modelCallStart
  }

  public let runID: UUID
  public let phase: Phase
  public let turnID: String?
  public let model: String?
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    phase: Phase,
    turnID: String? = nil,
    model: String? = nil,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.phase = phase
    self.turnID = turnID
    self.model = model
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for the confirmed `model.call_failure` event.
public struct CopilotModelCallFailureEvent: EventPayload {
  public static let eventType = "copilot.model.callFailure"

  public let runID: UUID
  public let model: String
  public let statusCode: Int?
  public let errorMessage: String
  public let sequence: Int
  public let observedAt: Date

  public init(
    runID: UUID,
    model: String,
    statusCode: Int? = nil,
    errorMessage: String,
    sequence: Int,
    observedAt: Date = Date()
  ) {
    self.runID = runID
    self.model = model
    self.statusCode = statusCode
    self.errorMessage = errorMessage
    self.sequence = sequence
    self.observedAt = observedAt
  }
}

/// Emitted for the confirmed final `result` event (`exitCode == 0`).
public struct CopilotTurnCompletedEvent: EventPayload {
  public static let eventType = "copilot.turn.completed"

  public enum Outcome: String, Codable, Sendable, Equatable {
    case succeeded
    case failed
  }

  public let runID: UUID
  public let outcome: Outcome
  public let sessionDurationMs: Int
  public let premiumRequests: Int
  public let filesModifiedCount: Int
  public let linesAdded: Int
  public let linesRemoved: Int
  public let completedAt: Date

  public init(
    runID: UUID,
    outcome: Outcome,
    sessionDurationMs: Int,
    premiumRequests: Int,
    filesModifiedCount: Int,
    linesAdded: Int,
    linesRemoved: Int,
    completedAt: Date = Date()
  ) {
    self.runID = runID
    self.outcome = outcome
    self.sessionDurationMs = sessionDurationMs
    self.premiumRequests = premiumRequests
    self.filesModifiedCount = filesModifiedCount
    self.linesAdded = linesAdded
    self.linesRemoved = linesRemoved
    self.completedAt = completedAt
  }
}

/// Emitted whenever a Copilot run fails for any reason.
public struct CopilotErrorEvent: EventPayload {
  public static let eventType = "copilot.error"

  public enum Category: String, Codable, Sendable, Equatable {
    case cliLaunchFailed
    case decodeFailed
    case budgetExceeded
    case policyDenied
    case timedOut
    case cancelled
    case processExitedNonZero
    case quotaExceeded
    case repositoryInstructionsBlocked
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

/// Emitted when a run is flagged as having exceeded a configured budget.
public struct CopilotBudgetExceededEvent: EventPayload {
  public static let eventType = "copilot.budget.exceeded"

  public enum Kind: String, Codable, Sendable, Equatable {
    case time
    case fileWrites
    case aiCredits
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
