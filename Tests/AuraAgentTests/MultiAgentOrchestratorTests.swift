import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import Foundation
import Testing

/// Exercises `MultiAgentOrchestrator`'s control flow — bounded review
/// iterations, evidence-based adjudication, conflict recording, escalation,
/// the agent-invocation budget guard, and the specialist swarm pattern —
/// against fake `OrchestratedAgentRunning` role agents (no real CLI
/// spawned), but a REAL `WorktreeManager` operating on a real scratch `git`
/// repository, matching this codebase's precedent of never mocking the
/// safety-relevant boundary (worktree isolation) while faking the
/// model-facing boundary (agent responses).

// MARK: - Fake role agent

private actor FakeOrchestratedAgent: OrchestratedAgentRunning {
  nonisolated let backendName: String
  private var scripts: [[OrchestrationAgentEvent]]
  private var callIndex = 0
  private(set) var invocationCount = 0
  private(set) var receivedObjectives: [String] = []
  private(set) var receivedWorkingDirectories: [String] = []

  init(backendName: String = "fake", scripts: [[OrchestrationAgentEvent]]) {
    self.backendName = backendName
    self.scripts = scripts
  }

  func run(
    objective: String, workingDirectory: String, writable: Bool, actor: ActorID,
    sessionID: UUID, correlationID: UUID, causationID: UUID
  ) async -> AsyncThrowingStream<OrchestrationAgentEvent, Error> {
    invocationCount += 1
    receivedObjectives.append(objective)
    receivedWorkingDirectories.append(workingDirectory)
    let index = min(callIndex, max(scripts.count - 1, 0))
    callIndex += 1
    let events = scripts.isEmpty ? [] : scripts[index]
    return AsyncThrowingStream { continuation in
      for event in events {
        continuation.yield(event)
      }
      continuation.finish()
    }
  }

  func cancel(correlationID: UUID) async {}
}

// MARK: - Scratch git repo helpers

@discardableResult
private func runGit(_ arguments: [String], cwd: String) throws -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
  process.arguments = arguments
  process.currentDirectoryURL = URL(fileURLWithPath: cwd)
  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = pipe
  try process.run()
  process.waitUntilExit()
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: data, encoding: .utf8) ?? ""
  guard process.terminationStatus == 0 else {
    throw NSError(
      domain: "orchestrator-tests", code: Int(process.terminationStatus),
      userInfo: [NSLocalizedDescriptionKey: output])
  }
  return output
}

private func makeScratchGitRepo() throws -> String {
  let root = NSHomeDirectory() + "/.aura-orchestrator-tests/\(UUID().uuidString)"
  try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
  try runGit(["init", "-q"], cwd: root)
  try runGit(["config", "user.email", "test@example.com"], cwd: root)
  try runGit(["config", "user.name", "Test"], cwd: root)
  try "hello\n".write(toFile: root + "/file.txt", atomically: true, encoding: .utf8)
  try runGit(["add", "file.txt"], cwd: root)
  try runGit(["commit", "-q", "-m", "init"], cwd: root)
  return root
}

private func removeScratchRepo(_ root: String) {
  try? FileManager.default.removeItem(atPath: root)
}

// MARK: - Policy / store helpers

private func makeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeAllowingPolicyEngine(eventBus: AuraEventBus) async throws -> PolicyEngine {
  try await PolicyEngine(
    configuration: PolicyConfiguration(
      defaultConfirmationTier: .destructive,
      allowByDefaultTiers: [.observation, .reversible, .mutation],
      denyByDefaultTiers: [.destructive]
    ),
    eventBus: eventBus, store: try await makeTempStore())
}

private func makeValidationShell() -> AuraShell {
  AuraShell(
    configuration: ShellConfiguration(allowedWorkingDirectories: ["$HOME/*", "$TMPDIR/*"]))
}

// MARK: - Event capture

private actor Capture {
  var payloads: [any EventPayload] = []

  func append(_ payload: any EventPayload) {
    payloads.append(payload)
  }

  func all<E: EventPayload>(_ type: E.Type) -> [E] {
    payloads.compactMap { $0 as? E }
  }
}

// MARK: - Happy path: approved on first iteration

@Test
func orchestratorApprovesOnFirstReviewIteration() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchApprove"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let worktreeManager = WorktreeManager(
    configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
  let orchestrator = MultiAgentOrchestrator(
    worktreeManager: worktreeManager, policyEngine: policyEngine, eventBus: bus)

  let planner = FakeOrchestratedAgent(scripts: [[.text(role: "planner", content: "do X"), .turnCompleted]])
  let implementer = FakeOrchestratedAgent(
    scripts: [[.text(role: "assistant", content: "implemented"), .turnCompleted]])
  let reviewer = FakeOrchestratedAgent(
    scripts: [[.text(role: "assistant", content: "VERDICT: APPROVE"), .turnCompleted]])

  let outcome = await orchestrator.runPlannerImplementerReviewer(
    objective: "add a feature", repositoryRoot: repoRoot, planner: planner, implementer: implementer,
    reviewer: reviewer)

  guard case .approved(let path, _, let iterations) = outcome else {
    Issue.record("expected approved, got \(outcome)")
    return
  }
  #expect(iterations == 1)
  #expect(FileManager.default.fileExists(atPath: path))
  #expect(await planner.invocationCount == 1)
  #expect(await implementer.invocationCount == 1)
  #expect(await reviewer.invocationCount == 1)
}

// MARK: - Correction loop: reviewer requests changes once, then approves

@Test
func orchestratorCorrectsOnceThenApproves() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchCorrect"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let capture = Capture()
  await bus.subscribe(OrchestrationConflictRecordedEvent.self) {
    (envelope: EventEnvelope<OrchestrationConflictRecordedEvent>) async in
    await capture.append(envelope.payload)
  }
  let worktreeManager = WorktreeManager(
    configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
  let orchestrator = MultiAgentOrchestrator(
    worktreeManager: worktreeManager, policyEngine: policyEngine,
    configuration: .init(maxReviewIterations: 3), eventBus: bus)

  let planner = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  let implementer = FakeOrchestratedAgent(
    scripts: [
      [.text(role: "assistant", content: "first pass"), .turnCompleted],
      [.text(role: "assistant", content: "addressed feedback"), .turnCompleted],
    ])
  let reviewer = FakeOrchestratedAgent(
    scripts: [
      [.text(role: "assistant", content: "VERDICT: REQUEST_CHANGES: missing tests"), .turnCompleted],
      [.text(role: "assistant", content: "VERDICT: APPROVE"), .turnCompleted],
    ])

  let outcome = await orchestrator.runPlannerImplementerReviewer(
    objective: "add a feature", repositoryRoot: repoRoot, planner: planner, implementer: implementer,
    reviewer: reviewer)

  guard case .approved(_, _, let iterations) = outcome else {
    Issue.record("expected approved, got \(outcome)")
    return
  }
  #expect(iterations == 2)
  #expect(await implementer.invocationCount == 2)
  #expect(await reviewer.invocationCount == 2)
  let conflicts = await capture.all(OrchestrationConflictRecordedEvent.self)
  #expect(conflicts.count == 1)
  #expect(conflicts.first?.reviewerReason == "missing tests")
}

// MARK: - Escalation after bounded iterations

@Test
func orchestratorEscalatesAfterBoundedIterationsExhausted() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchEscalate"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let capture = Capture()
  await bus.subscribe(OrchestrationEscalatedEvent.self) {
    (envelope: EventEnvelope<OrchestrationEscalatedEvent>) async in
    await capture.append(envelope.payload)
  }
  let worktreeManager = WorktreeManager(
    configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
  let orchestrator = MultiAgentOrchestrator(
    worktreeManager: worktreeManager, policyEngine: policyEngine,
    configuration: .init(maxReviewIterations: 2), eventBus: bus)

  let planner = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  let implementer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  let reviewer = FakeOrchestratedAgent(
    scripts: [[.text(role: "assistant", content: "VERDICT: REQUEST_CHANGES: still broken"), .turnCompleted]])

  let outcome = await orchestrator.runPlannerImplementerReviewer(
    objective: "add a feature", repositoryRoot: repoRoot, planner: planner, implementer: implementer,
    reviewer: reviewer)

  guard case .escalated(_, _, let iterations, let conflicts) = outcome else {
    Issue.record("expected escalated, got \(outcome)")
    return
  }
  #expect(iterations == 2)
  #expect(conflicts.count == 2)
  let escalations = await capture.all(OrchestrationEscalatedEvent.self)
  #expect(escalations.count == 1)
  #expect(escalations.first?.iterations == 2)
}

// MARK: - Evidence-based adjudication overrides a bare model approval

@Test
func orchestratorValidationFailureOverridesReviewerApproval() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchEvidence"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let worktreeManager = WorktreeManager(
    configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
  let orchestrator = MultiAgentOrchestrator(
    worktreeManager: worktreeManager, policyEngine: policyEngine,
    configuration: .init(maxReviewIterations: 1), validationShell: makeValidationShell(), eventBus: bus)

  let planner = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  let implementer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  // The reviewer says APPROVE, but the real validation command below always
  // fails — evidence must win over the model's own self-report.
  let reviewer = FakeOrchestratedAgent(
    scripts: [[.text(role: "assistant", content: "VERDICT: APPROVE"), .turnCompleted]])

  let outcome = await orchestrator.runPlannerImplementerReviewer(
    objective: "add a feature", repositoryRoot: repoRoot, planner: planner, implementer: implementer,
    reviewer: reviewer, validationCommand: Command(executable: "/usr/bin/false"))

  guard case .escalated = outcome else {
    Issue.record("expected escalated despite reviewer approval, got \(outcome)")
    return
  }
}

// MARK: - Agent-invocation budget prevents any spawn

@Test
func orchestratorZeroInvocationBudgetPreventsAnyAgentSpawn() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchBudget"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let capture = Capture()
  await bus.subscribe(OrchestrationBudgetExceededEvent.self) {
    (envelope: EventEnvelope<OrchestrationBudgetExceededEvent>) async in
    await capture.append(envelope.payload)
  }
  let worktreeManager = WorktreeManager(
    configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
  let orchestrator = MultiAgentOrchestrator(
    worktreeManager: worktreeManager, policyEngine: policyEngine,
    configuration: .init(maxTotalAgentInvocations: 0), eventBus: bus)

  let planner = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  let implementer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  let reviewer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])

  let outcome = await orchestrator.runPlannerImplementerReviewer(
    objective: "add a feature", repositoryRoot: repoRoot, planner: planner, implementer: implementer,
    reviewer: reviewer)

  guard case .budgetExceeded = outcome else {
    Issue.record("expected budgetExceeded, got \(outcome)")
    return
  }
  #expect(await planner.invocationCount == 0)
  #expect(await implementer.invocationCount == 0)
  #expect(await reviewer.invocationCount == 0)
  #expect(await worktreeManager.activeCount() == 0)
  #expect(await capture.all(OrchestrationBudgetExceededEvent.self).count == 1)
}

// MARK: - Planner failure never creates a worktree

@Test
func orchestratorPlannerFailureNeverCreatesWorktree() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchPlannerFail"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let worktreeManager = WorktreeManager(
    configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
  let orchestrator = MultiAgentOrchestrator(
    worktreeManager: worktreeManager, policyEngine: policyEngine, eventBus: bus)

  let planner = FakeOrchestratedAgent(scripts: [[.turnFailed(message: "planner crashed")]])
  let implementer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  let reviewer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])

  let outcome = await orchestrator.runPlannerImplementerReviewer(
    objective: "add a feature", repositoryRoot: repoRoot, planner: planner, implementer: implementer,
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

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchImplFail"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let worktreeManager = WorktreeManager(
    configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: bus)
  let orchestrator = MultiAgentOrchestrator(
    worktreeManager: worktreeManager, policyEngine: policyEngine, eventBus: bus)

  let planner = FakeOrchestratedAgent(scripts: [[.turnCompleted]])
  let implementer = FakeOrchestratedAgent(scripts: [[.turnFailed(message: "disk full")]])
  let reviewer = FakeOrchestratedAgent(scripts: [[.turnCompleted]])

  let outcome = await orchestrator.runPlannerImplementerReviewer(
    objective: "add a feature", repositoryRoot: repoRoot, planner: planner, implementer: implementer,
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

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchSwarmFail"))
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

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchSwarmOversize"))
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
