import Foundation

// MARK: - Worktree

/// A prepared, isolated `git worktree` for a single orchestration task.
///
/// One worktree is created per mutable task, matching the master prompt's
/// concurrency rule: "Allow one mutable task per worktree." Read-only roles
/// (e.g. a planner) may operate against `repositoryRoot` directly instead of
/// a worktree.
public struct WorktreeHandle: Sendable, Equatable {
  public let taskID: UUID
  public let repositoryRoot: String
  public let path: String
  public let branch: String
  public let baseRef: String
  public let createdAt: Date

  public init(
    taskID: UUID,
    repositoryRoot: String,
    path: String,
    branch: String,
    baseRef: String,
    createdAt: Date = Date()
  ) {
    self.taskID = taskID
    self.repositoryRoot = repositoryRoot
    self.path = path
    self.branch = branch
    self.baseRef = baseRef
    self.createdAt = createdAt
  }
}

// MARK: - Orchestration pattern

/// A named multi-agent collaboration pattern from the Multi-Agent
/// Collaboration Protocol specification.
///
/// Only the patterns `MultiAgentOrchestrator` actually implements are
/// representable here. "Parallel proposals → adjudicator" and "Implementer →
/// independent reviewer → corrector" are named follow-ups, not silently
/// half-implemented — see ADR-015.
public enum OrchestrationPattern: String, Codable, Sendable, Equatable, CaseIterable {
  case plannerImplementerReviewer
  case specialistSwarm
}

// MARK: - Review verdict

/// The reviewer role's evidence-checked verdict for one review iteration.
///
/// Parsed from the reviewer agent's own accumulated text via a fixed,
/// orchestrator-defined convention (`ReviewVerdictParser`) — never inferred
/// or fabricated from free-form prose.
public enum ReviewVerdict: Sendable, Equatable {
  case approve
  case requestChanges(reason: String)
  /// The reviewer's output did not contain a recognizable verdict marker.
  /// Treated as a disagreement, not a silent approval.
  case unparseable
}

// MARK: - Validation evidence

/// The result of running a caller-supplied validation command (e.g. a build
/// or test invocation) inside a worktree, used for evidence-based
/// adjudication alongside the reviewer's own verdict.
public struct ValidationOutcome: Sendable, Equatable {
  public let passed: Bool
  public let exitCode: Int
  /// Bounded tail of combined stdout/stderr, for inclusion in the reviewer's
  /// evidence bundle and audit events.
  public let outputTail: String

  public init(passed: Bool, exitCode: Int, outputTail: String) {
    self.passed = passed
    self.exitCode = exitCode
    self.outputTail = outputTail
  }
}

// MARK: - Conflict record

/// One recorded disagreement between the reviewer's verdict and/or
/// validation evidence during a bounded review loop.
public struct OrchestrationConflict: Sendable, Equatable {
  public let iteration: Int
  public let verdict: ReviewVerdict
  public let validationPassed: Bool?

  public init(iteration: Int, verdict: ReviewVerdict, validationPassed: Bool?) {
    self.iteration = iteration
    self.verdict = verdict
    self.validationPassed = validationPassed
  }
}

// MARK: - Outcome

/// Terminal result of a `MultiAgentOrchestrator` run.
public enum OrchestrationOutcome: Sendable, Equatable {
  /// The reviewer approved and (when supplied) the validation command
  /// passed. The worktree/branch are left in place for a separate,
  /// explicitly authorized integration step — this outcome does not merge.
  case approved(worktreePath: String, branch: String, iterations: Int)
  /// Bounded review iterations were exhausted without an evidence-backed
  /// approval. The worktree/branch are left in place for inspection.
  case escalated(
    worktreePath: String, branch: String, iterations: Int, conflicts: [OrchestrationConflict])
  /// A role agent failed, was denied by policy, or the run could not proceed
  /// (e.g. worktree preparation failure).
  case failed(reason: String)
  /// Aborted before spawning another role agent because the configured total
  /// agent-invocation budget was reached — prevents uncontrolled recursive
  /// spawning.
  case budgetExceeded(reason: String)
}

// MARK: - Specialist swarm

/// One task in a specialist-swarm run: a separable objective given its own
/// isolated worktree and agent, run concurrently with its siblings.
public struct SpecialistTask: Sendable {
  public let taskID: UUID
  public let objective: String

  public init(taskID: UUID = UUID(), objective: String) {
    self.taskID = taskID
    self.objective = objective
  }
}

/// The result of one `SpecialistTask` within a swarm run.
public struct SpecialistResult: Sendable, Equatable {
  public let taskID: UUID
  public let outcome: OrchestrationOutcome

  public init(taskID: UUID, outcome: OrchestrationOutcome) {
    self.taskID = taskID
    self.outcome = outcome
  }
}
