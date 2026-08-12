import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import Foundation
import Testing

extension MultiAgentOrchestratorTests {
  @Test
  func orchestratorPlannerFailureNeverCreatesWorktree() async throws {
    let repoRoot = try makeScratchGitRepo()
    defer { removeScratchRepo(repoRoot) }

    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchPlannerFail"))
    let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
    let worktreeManager = WorktreeManager(
      configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
    let orchestrator = MultiAgentOrchestrator(
      worktreeManager: worktreeManager, policyEngine: policyEngine, eventBus: bus)

    let planner = FakeOrchestratedAgent(scripts: [[.turnFailed(message: "planner crashed")]])
    let implementer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
    let reviewer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])

    let outcome = await orchestrator.runPlannerImplementerReviewer(
      objective: "add a feature", repositoryRoot: repoRoot, planner: planner,
      implementer: implementer,
      reviewer: reviewer)

    guard case .failed(let reason) = outcome else {
      Issue.record("expected failed, got \(outcome)")
      return
    }
    #expect(reason.contains("planner crashed"))
    #expect(await implementer.invocationCount == 0)
    #expect(await worktreeManager.activeCount() == 0)
  }

  // MARK: - Post-worktree failure still surfaces the worktree for inspection

  @Test
  func orchestratorImplementerFailureEmbedsWorktreePathInReason() async throws {
    let repoRoot = try makeScratchGitRepo()
    defer { removeScratchRepo(repoRoot) }

    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchImplFail"))
    let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
    let worktreeManager = WorktreeManager(
      configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
    let orchestrator = MultiAgentOrchestrator(
      worktreeManager: worktreeManager, policyEngine: policyEngine, eventBus: bus)

    let planner = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
    let implementer = FakeOrchestratedAgent(scripts: [[.turnFailed(message: "disk full")]])
    let reviewer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])

    let outcome = await orchestrator.runPlannerImplementerReviewer(
      objective: "add a feature", repositoryRoot: repoRoot, planner: planner,
      implementer: implementer,
      reviewer: reviewer)

    guard case .failed(let reason) = outcome else {
      Issue.record("expected failed, got \(outcome)")
      return
    }
    #expect(reason.contains("disk full"))
    #expect(reason.contains(".aura-worktrees"))
    // The orphaned worktree is left in place for inspection, not silently
    // deleted.
    #expect(await worktreeManager.activeCount() == 1)
  }

  // MARK: - Specialist swarm

  @Test
  func orchestratorSpecialistSwarmRunsIsolatedTasksConcurrently() async throws {
    let repoRoot = try makeScratchGitRepo()
    defer { removeScratchRepo(repoRoot) }

    let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchSwarm"))
    let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
    let worktreeManager = WorktreeManager(
      configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
    let orchestrator = MultiAgentOrchestrator(
      worktreeManager: worktreeManager, policyEngine: policyEngine, eventBus: bus)

    let tasks = (0..<3).map { SpecialistTask(objective: "task \($0)") }

    let results = await orchestrator.runSpecialistSwarm(
      tasks: tasks, repositoryRoot: repoRoot,
      agentForTask: { _ in FakeOrchestratedAgent(scripts: [[.turnCompleted]]) })

    #expect(results.count == 3)
    let paths = Set(
      results.compactMap { result -> String? in
        guard case .approved(let path, _, _) = result.outcome else { return nil }
        return path
      })
    #expect(paths.count == 3)
    #expect(await worktreeManager.activeCount() == 3)
  }

  @Test
  func orchestratorSpecialistSwarmIsolatesOneTaskFailureFromOthers() async throws {
    let repoRoot = try makeScratchGitRepo()
    defer { removeScratchRepo(repoRoot) }

    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchSwarmFail"))
    let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
    let worktreeManager = WorktreeManager(
      configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
    let orchestrator = MultiAgentOrchestrator(
      worktreeManager: worktreeManager, policyEngine: policyEngine, eventBus: bus)

    let failingTask = SpecialistTask(objective: "the failing one")
    let tasks = [failingTask, SpecialistTask(objective: "ok 1"), SpecialistTask(objective: "ok 2")]

    let results = await orchestrator.runSpecialistSwarm(
      tasks: tasks, repositoryRoot: repoRoot,
      agentForTask: { task in
        task.taskID == failingTask.taskID
          ? FakeOrchestratedAgent(scripts: [[.turnFailed(message: "boom")]])
          : FakeOrchestratedAgent(scripts: [[.turnCompleted]])
      })

    let failedCount = results.filter {
      if case .failed = $0.outcome { return true } else { return false }
    }.count
    let approvedCount = results.filter {
      if case .approved = $0.outcome { return true } else { return false }
    }.count
    #expect(failedCount == 1)
    #expect(approvedCount == 2)
  }

  @Test
  func orchestratorSpecialistSwarmRejectsOversizedRequest() async throws {
    let repoRoot = try makeScratchGitRepo()
    defer { removeScratchRepo(repoRoot) }

    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchSwarmOversize"))
    let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
    let worktreeManager = WorktreeManager(
      configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
    let orchestrator = MultiAgentOrchestrator(
      worktreeManager: worktreeManager, policyEngine: policyEngine,
      configuration: .init(maxSpecialistTasks: 2), eventBus: bus)

    let tasks = (0..<3).map { SpecialistTask(objective: "task \($0)") }

    let results = await orchestrator.runSpecialistSwarm(
      tasks: tasks, repositoryRoot: repoRoot,
      agentForTask: { _ in FakeOrchestratedAgent(scripts: [[.turnCompleted]]) })

    #expect(results.count == 3)
    #expect(
      results.allSatisfy {
        if case .budgetExceeded = $0.outcome { return true } else { return false }
      })
    #expect(await worktreeManager.activeCount() == 0)
  }

}
