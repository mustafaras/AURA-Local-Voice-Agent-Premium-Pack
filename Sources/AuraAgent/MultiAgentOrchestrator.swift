import AuraCore
import AuraPolicy
import AuraShell
import Foundation

/// Drives bounded multi-agent collaboration patterns over isolated `git
/// worktree`s, per the Multi-Agent Collaboration Protocol specification
/// (`docs/subsystems/16_MULTI_AGENT_PROTOCOL.md`).
///
/// Implements two of the four named patterns:
/// - **Planner → Implementer → Reviewer**, with a bounded review/correct
///   loop and evidence-based adjudication (reviewer verdict *and*, when
///   supplied, a real validation command — never the reviewer's verdict
///   alone, and never the implementer's own summary).
/// - **Specialist swarm**, running separable tasks concurrently, each in its
///   own worktree.
///
/// "Parallel proposals → adjudicator" and "Implementer → independent
/// reviewer → corrector" are named follow-ups, not implemented here — see
/// ADR-015. This orchestrator only ever spawns `OrchestratedAgentRunning`
/// role agents, never another orchestrator, so recursive orchestrator
/// spawning is unreachable by construction; the configured total
/// agent-invocation budget additionally bounds how many role agents any
/// single run may spawn.
public actor MultiAgentOrchestrator {
  public struct Configuration: Sendable, Equatable {
    /// Maximum number of review iterations (reviewer + corrector pass) before
    /// escalating instead of approving.
    public var maxReviewIterations: Int
    /// Hard ceiling on the total number of role-agent invocations a single
    /// run may make, across planner/implementer/reviewer/corrector passes —
    /// the recursive-spawn-prevention guard.
    public var maxTotalAgentInvocations: Int
    /// Hard ceiling on the number of tasks a single specialist-swarm call may
    /// run, independent of `maxTotalAgentInvocations`.
    public var maxSpecialistTasks: Int

    public init(
      maxReviewIterations: Int = 3,
      maxTotalAgentInvocations: Int = 20,
      maxSpecialistTasks: Int = 8
    ) {
      self.maxReviewIterations = maxReviewIterations
      self.maxTotalAgentInvocations = maxTotalAgentInvocations
      self.maxSpecialistTasks = maxSpecialistTasks
    }

  }

  let worktreeManager: WorktreeManager
  let policyEngine: PolicyEngine
  let configuration: Configuration
  let validationShell: AuraShell?
  let eventBus: AuraEventBus

  public init(
    worktreeManager: WorktreeManager,
    policyEngine: PolicyEngine,
    configuration: Configuration = Configuration(),
    validationShell: AuraShell? = nil,
    eventBus: AuraEventBus = .shared
  ) {
    self.worktreeManager = worktreeManager
    self.policyEngine = policyEngine
    self.configuration = configuration
    self.validationShell = validationShell
    self.eventBus = eventBus
  }
}
