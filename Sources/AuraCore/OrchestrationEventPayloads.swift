import Foundation

// MARK: - Worktree lifecycle event payloads

/// Emitted when `WorktreeManager` successfully creates an isolated `git
/// worktree` for a task.
public struct WorktreeCreatedEvent: EventPayload {
  public static let eventType = "worktree.created"

  public let taskID: UUID
  public let path: String
  public let branch: String
  public let baseRef: String
  public let createdAt: Date

  public init(
    taskID: UUID,
    path: String,
    branch: String,
    baseRef: String,
    createdAt: Date = Date()
  ) {
    self.taskID = taskID
    self.path = path
    self.branch = branch
    self.baseRef = baseRef
    self.createdAt = createdAt
  }
}

/// Emitted when worktree creation is denied by policy or fails at the `git`
/// level.
public struct WorktreeCreationFailedEvent: EventPayload {
  public static let eventType = "worktree.creation.failed"

  public let taskID: UUID
  public let reason: String
  public let occurredAt: Date

  public init(taskID: UUID, reason: String, occurredAt: Date = Date()) {
    self.taskID = taskID
    self.reason = reason
    self.occurredAt = occurredAt
  }
}

/// Emitted when a previously created worktree is removed.
public struct WorktreeRemovedEvent: EventPayload {
  public static let eventType = "worktree.removed"

  public let taskID: UUID
  public let path: String
  public let forced: Bool
  public let removedAt: Date

  public init(taskID: UUID, path: String, forced: Bool, removedAt: Date = Date()) {
    self.taskID = taskID
    self.path = path
    self.forced = forced
    self.removedAt = removedAt
  }
}

// MARK: - Orchestration run event payloads

/// Emitted when a `MultiAgentOrchestrator` run starts.
public struct OrchestrationRunStartedEvent: EventPayload {
  public static let eventType = "orchestration.run.started"

  public let runID: UUID
  public let pattern: OrchestrationPattern
  public let objective: String
  public let repositoryRoot: String
  public let startedAt: Date

  public init(
    runID: UUID,
    pattern: OrchestrationPattern,
    objective: String,
    repositoryRoot: String,
    startedAt: Date = Date()
  ) {
    self.runID = runID
    self.pattern = pattern
    self.objective = objective
    self.repositoryRoot = repositoryRoot
    self.startedAt = startedAt
  }
}

/// Emitted every time the orchestrator invokes a role agent (planner,
/// implementer, or reviewer), before the agent runs — the basis for
/// enforcing the total agent-invocation budget and auditing recursive-spawn
/// prevention.
public struct OrchestrationAgentInvokedEvent: EventPayload {
  public static let eventType = "orchestration.agent.invoked"

  public enum Role: String, Codable, Sendable, Equatable {
    case planner
    case implementer
    case reviewer
    case specialist
  }

  public let runID: UUID
  public let role: Role
  public let backendName: String
  public let invocationNumber: Int
  public let invokedAt: Date

  public init(
    runID: UUID,
    role: Role,
    backendName: String,
    invocationNumber: Int,
    invokedAt: Date = Date()
  ) {
    self.runID = runID
    self.role = role
    self.backendName = backendName
    self.invocationNumber = invocationNumber
    self.invokedAt = invokedAt
  }
}

/// Emitted whenever the reviewer's verdict and/or validation evidence
/// disagree with approval for a review iteration — a recorded disagreement,
/// per the Multi-Agent Collaboration Protocol's "agents may disagree; the
/// orchestrator records the disagreement" rule.
public struct OrchestrationConflictRecordedEvent: EventPayload {
  public static let eventType = "orchestration.conflict.recorded"

  public let runID: UUID
  public let iteration: Int
  public let reviewerApproved: Bool
  public let reviewerReason: String?
  public let validationPassed: Bool?
  public let recordedAt: Date

  public init(
    runID: UUID,
    iteration: Int,
    reviewerApproved: Bool,
    reviewerReason: String?,
    validationPassed: Bool?,
    recordedAt: Date = Date()
  ) {
    self.runID = runID
    self.iteration = iteration
    self.reviewerApproved = reviewerApproved
    self.reviewerReason = reviewerReason
    self.validationPassed = validationPassed
    self.recordedAt = recordedAt
  }
}

/// Emitted when bounded review iterations are exhausted without an
/// evidence-backed approval.
public struct OrchestrationEscalatedEvent: EventPayload {
  public static let eventType = "orchestration.escalated"

  public let runID: UUID
  public let iterations: Int
  public let conflictCount: Int
  public let escalatedAt: Date

  public init(
    runID: UUID,
    iterations: Int,
    conflictCount: Int,
    escalatedAt: Date = Date()
  ) {
    self.runID = runID
    self.iterations = iterations
    self.conflictCount = conflictCount
    self.escalatedAt = escalatedAt
  }
}

/// Emitted when the orchestrator aborts before spawning another role agent
/// because the configured total agent-invocation budget was reached.
public struct OrchestrationBudgetExceededEvent: EventPayload {
  public static let eventType = "orchestration.budget.exceeded"

  public let runID: UUID
  public let limit: Int
  public let observed: Int
  public let exceededAt: Date

  public init(runID: UUID, limit: Int, observed: Int, exceededAt: Date = Date()) {
    self.runID = runID
    self.limit = limit
    self.observed = observed
    self.exceededAt = exceededAt
  }
}

/// Emitted once a `MultiAgentOrchestrator` run reaches a terminal outcome.
public struct OrchestrationRunCompletedEvent: EventPayload {
  public static let eventType = "orchestration.run.completed"

  public enum Outcome: String, Codable, Sendable, Equatable {
    case approved
    case escalated
    case failed
    case budgetExceeded
  }

  public let runID: UUID
  public let outcome: Outcome
  public let iterations: Int
  public let summary: String
  public let completedAt: Date

  public init(
    runID: UUID,
    outcome: Outcome,
    iterations: Int,
    summary: String,
    completedAt: Date = Date()
  ) {
    self.runID = runID
    self.outcome = outcome
    self.iterations = iterations
    self.summary = summary
    self.completedAt = completedAt
  }
}
