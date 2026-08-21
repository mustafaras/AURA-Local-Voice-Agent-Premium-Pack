import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import AuraVSCode
import Foundation
import Testing

// SP-013 — CodingTaskCoordinator durable-task lifecycle tests.
//
// Exercises the coordinator's mode routing against a REAL `WorktreeManager`
// on a real scratch `git` repository and a REAL `AuraTaskEngine`/`AuraStore`,
// matching the WorktreeManager/MultiAgentOrchestrator precedent of never
// mocking the safety-relevant isolation/durability boundaries. The backend
// is a fake `TaskRunner` that records which working directory and sandbox
// tier it was handed — so a test proves the coordinator actually routed the
// resolved workspace/worktree into the per-backend context keys, which is the
// SP-013 "workspace routing + worktree isolation" gate.

// MARK: - Fake backend runner that records its context

actor ContextRecordingRunner: TaskRunner {
  private(set) var workingDirectory: String?
  private(set) var sandboxTier: String?
  private let writeToWorktree: Bool

  init(writeToWorktree: Bool = false) {
    self.writeToWorktree = writeToWorktree
  }

  func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan {
    TaskPlan(totalSteps: 1, stepDescriptions: ["run"])
  }

  func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    workingDirectory =
      request.context["codex.workingDirectory"]
      ?? request.context["claude.workingDirectory"]
      ?? request.context["copilot.workingDirectory"]
    sandboxTier =
      request.context["codex.sandbox"]
      ?? request.context["claude.toolProfile"]
      ?? request.context["copilot.toolProfile"]

    if writeToWorktree, let wd = workingDirectory {
      // Modify the tracked file so `git diff` in the worktree is non-empty.
      // (An untracked new file would not appear in `git diff`.)
      let file = wd + "/file.txt"
      var current = ""
      if let existing = try? String(contentsOfFile: file, encoding: .utf8) {
        current = existing
      }
      try? (current + "changed-from-sp013\n").write(
        toFile: file, atomically: true, encoding: .utf8)
    }
    await context.reportProgress(
      completedSteps: 1, totalSteps: 1, currentStepDescription: "ran")
  }

  func recorded() -> (String?, String?) {
    (workingDirectory, sandboxTier)
  }
}

// MARK: - Scratch git repo + policy + store helpers

@discardableResult
private func coordinatorRunGit(_ arguments: [String], cwd: String) throws -> String {
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
      domain: "coordinator-tests", code: Int(process.terminationStatus),
      userInfo: [NSLocalizedDescriptionKey: output])
  }
  return output
}

private func makeCoordinatorScratchRepo() throws -> String {
  let root = NSHomeDirectory() + "/.aura-coordinator-tests/\(UUID().uuidString)"
  try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
  try coordinatorRunGit(["init", "-q"], cwd: root)
  try coordinatorRunGit(["config", "user.email", "test@example.com"], cwd: root)
  try coordinatorRunGit(["config", "user.name", "Test"], cwd: root)
  try "hello\n".write(toFile: root + "/file.txt", atomically: true, encoding: .utf8)
  try coordinatorRunGit(["add", "file.txt"], cwd: root)
  try coordinatorRunGit(["commit", "-q", "-m", "init"], cwd: root)
  return root
}

private func removeCoordinatorScratchRepo(_ root: String) {
  try? FileManager.default.removeItem(atPath: root)
}

private func makeCoordinatorTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeCoordinatorPolicyEngine(eventBus: AuraEventBus) async throws -> PolicyEngine {
  try await PolicyEngine(
    configuration: PolicyConfiguration(
      defaultConfirmationTier: .destructive,
      allowByDefaultTiers: [.observation, .reversible, .mutation],
      denyByDefaultTiers: [.destructive]),
    eventBus: eventBus, store: try await makeCoordinatorTempStore())
}

private func makeCoordinatorBus() -> AuraEventBus {
  AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "coordinator"))
}

// A probe that always reports a ready backend, so write-capable preflight
// passes.
private struct ReadyProbe: AgentBackendHealthProbing {
  func probe(backend: AgentBackendID, workspacePath: String?) async -> AgentBackendHealth {
    AgentBackendHealth(
      backend: backend, state: .ready,
      executablePath: "/bin/sh",
      version: "fixture", interfaceDescription: "fixture",
      authentication: .verified, modelAvailability: "fixture",
      sandboxPolicy: "fixture", cancellation: "fixture",
      networkPolicy: "offline",
      workingDirectoryPolicy: workspacePath ?? "unresolved",
      budgetPolicy: "fixture", detail: "ready fixture")
  }
}

private struct CoordinatorHarness {
  let store: AuraStore
  let taskEngine: AuraTaskEngine
  let healthRegistry: AgentBackendHealthRegistry
  let worktreeManager: WorktreeManager
  let coordinator: CodingTaskCoordinator
  let eventBus: AuraEventBus
  let runner: ContextRecordingRunner
}

private func makeCoordinatorHarness(repoRoot: String) async throws -> CoordinatorHarness {
  let store = try await makeCoordinatorTempStore()
  let eventBus = makeCoordinatorBus()
  let policy = try await makeCoordinatorPolicyEngine(eventBus: eventBus)
  let taskEngine = await AuraTaskEngine(store: store, eventBus: eventBus)
  try await taskEngine.recoverState()
  let registry = AgentBackendHealthRegistry(probe: ReadyProbe())
  let worktreeManager = WorktreeManager(
    configuration: WorktreeConfiguration(), policyEngine: policy, eventBus: eventBus)
  let runner = ContextRecordingRunner()
  let coordinator = CodingTaskCoordinator(
    taskEngine: taskEngine, backendRunner: runner, healthRegistry: registry,
    worktreeManager: worktreeManager)
  return CoordinatorHarness(
    store: store, taskEngine: taskEngine, healthRegistry: registry,
    worktreeManager: worktreeManager, coordinator: coordinator, eventBus: eventBus,
    runner: runner)
}

private func waitForTerminal(_ engine: AuraTaskEngine, id: UUID, timeoutNs: UInt64 = 2_000_000_000)
  async -> TaskState?
{
  let deadline = ContinuousClock().now + .nanoseconds(Int64(timeoutNs))
  while ContinuousClock().now < deadline {
    if let s = await engine.status(id: id) {
      switch s.state {
      case .completed, .failed, .cancelled:
        return s.state
      case .pending, .running, .paused:
        break
      }
    }
    try? await Task.sleep(nanoseconds: 25_000_000)
  }
  return await engine.status(id: id)?.state
}

// MARK: - Tests

@Suite("CodingTaskCoordinator durable lifecycle")
struct CodingTaskCoordinatorTests {

  @Test("read-only mode routes the resolved workspace and read-only sandbox")
  func readOnlyRoutesWorkspaceAndReadOnlyTier() async throws {
    let repo = try makeCoordinatorScratchRepo()
    defer { removeCoordinatorScratchRepo(repo) }
    let harness = try await makeCoordinatorHarness(repoRoot: repo)

    let request = CodingTaskRequest(
      objective: "read-only task", backend: .codex, mode: .readOnly,
      explicitWorkspacePath: repo, repositoryRoot: repo)
    let status = try await harness.coordinator.enqueue(request)
    let finalState = await waitForTerminal(harness.taskEngine, id: status.id)
    #expect(finalState == .completed)
    #expect(await harness.worktreeManager.activeCount() == 0)

    // The resolved workspace (not a worktree) must have been routed into the
    // backend's working-directory context key, with the read-only sandbox.
    let (wd, tier) = await harness.runner.recorded()
    #expect(wd == repo)
    #expect(tier == "readOnly")
  }

  @Test("review-only mode routes read-only and needs no worktree")
  func reviewOnlyNeedsNoWorktree() async throws {
    let root = try makeCoordinatorScratchRepo()
    defer { removeCoordinatorScratchRepo(root) }
    let harness = try await makeCoordinatorHarness(repoRoot: root)

    let request = CodingTaskRequest(
      objective: "review task", backend: .claude, mode: .reviewOnly,
      explicitWorkspacePath: root, repositoryRoot: root)
    let status = try await harness.coordinator.enqueue(request)
    let finalState = await waitForTerminal(harness.taskEngine, id: status.id)
    #expect(finalState == .completed)
    #expect(await harness.worktreeManager.activeCount() == 0)

    // Claude routing uses `claude.toolProfile`; review reads at read-only tier.
    let (wd, tier) = await harness.runner.recorded()
    #expect(wd == root)
    #expect(tier == "readOnly")
  }

  @Test("write-capable mode requires a worktree manager")
  func writeCapableRequiresWorktreeManager() async throws {
    let repo = try makeCoordinatorScratchRepo()
    defer { removeCoordinatorScratchRepo(repo) }
    let store = try await makeCoordinatorTempStore()
    let bus = makeCoordinatorBus()
    let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
    try await taskEngine.recoverState()
    let registry = AgentBackendHealthRegistry(probe: ReadyProbe())
    // Coordinator constructed with worktreeManager = nil.
    let coordinator = CodingTaskCoordinator(
      taskEngine: taskEngine, backendRunner: ContextRecordingRunner(),
      healthRegistry: registry, worktreeManager: nil)

    let request = CodingTaskRequest(
      objective: "write", backend: .codex, mode: .writeCapable,
      explicitWorkspacePath: repo, repositoryRoot: repo)
    await #expect(throws: AuraError.self) {
      try await coordinator.enqueue(request)
    }
  }

  @Test("write-capable mode prepares an isolated worktree and routes it to the backend")
  func writeCapablePreparesWorktreeAndRoutesIt() async throws {
    let repo = try makeCoordinatorScratchRepo()
    defer { removeCoordinatorScratchRepo(repo) }
    let harness = try await makeCoordinatorHarness(repoRoot: repo)

    let request = CodingTaskRequest(
      objective: "write task", backend: .codex, mode: .writeCapable,
      explicitWorkspacePath: repo, repositoryRoot: repo)
    let status = try await harness.coordinator.enqueue(request)
    let finalState = await waitForTerminal(harness.taskEngine, id: status.id)
    #expect(finalState == .completed)
    // A write-capable task should have prepared a worktree.
    #expect(await harness.worktreeManager.activeCount() == 1)
    let handle = await harness.worktreeManager.handle(for: status.id)
    #expect(handle != nil)

    // The isolated worktree path and the workspace-write sandbox tier must
    // have been routed into the backend's context keys, not the default.
    let (wd, tier) = await harness.runner.recorded()
    #expect(wd == handle?.path)
    #expect(tier == "workspaceWrite")
  }

  @Test("a write-capable task that completes with no diff is a false success")
  func falseBackendSuccessFailsClosed() async throws {
    let repo = try makeCoordinatorScratchRepo()
    defer { removeCoordinatorScratchRepo(repo) }
    let harness = try await makeCoordinatorHarness(repoRoot: repo)

    let request = CodingTaskRequest(
      objective: "no-op write", backend: .codex, mode: .writeCapable,
      explicitWorkspacePath: repo, repositoryRoot: repo)
    let status = try await harness.coordinator.enqueue(request)
    _ = await waitForTerminal(harness.taskEngine, id: status.id)

    // The fake runner wrote nothing, so the worktree diff is empty.
    let verification = await harness.coordinator.verifyCompletion(
      taskID: status.id, mode: .writeCapable)
    #expect(verification.verified == false)
    #expect(verification.detail.contains("no diff"))
  }

  @Test("a write-capable task that produced a diff verifies")
  func writeCapableWithDiffVerifies() async throws {
    let repo = try makeCoordinatorScratchRepo()
    defer { removeCoordinatorScratchRepo(repo) }
    let store = try await makeCoordinatorTempStore()
    let bus = makeCoordinatorBus()
    let policy = try await makeCoordinatorPolicyEngine(eventBus: bus)
    let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
    try await taskEngine.recoverState()
    let registry = AgentBackendHealthRegistry(probe: ReadyProbe())
    let worktreeManager = WorktreeManager(
      configuration: WorktreeConfiguration(), policyEngine: policy, eventBus: bus)
    let runner = ContextRecordingRunner(writeToWorktree: true)
    let coordinator = CodingTaskCoordinator(
      taskEngine: taskEngine, backendRunner: runner, healthRegistry: registry,
      worktreeManager: worktreeManager)

    let request = CodingTaskRequest(
      objective: "write with diff", backend: .codex, mode: .writeCapable,
      explicitWorkspacePath: repo, repositoryRoot: repo)
    let status = try await coordinator.enqueue(request)
    _ = await waitForTerminal(taskEngine, id: status.id)

    let verification = await coordinator.verifyCompletion(taskID: status.id, mode: .writeCapable)
    #expect(verification.verified == true)
    #expect(verification.detail.contains("non-empty diff"))
  }

  @Test("read-only and review-only modes have no diff postcondition")
  func readOnlyAndReviewOnlyHaveNoDiffPostcondition() async throws {
    let repo = try makeCoordinatorScratchRepo()
    defer { removeCoordinatorScratchRepo(repo) }
    let harness = try await makeCoordinatorHarness(repoRoot: repo)

    let ro = await harness.coordinator.verifyCompletion(
      taskID: UUID(), mode: .readOnly)
    #expect(ro.verified == true)
    #expect(ro.detail.contains("no mutable-diff postcondition"))

    let review = await harness.coordinator.verifyCompletion(
      taskID: UUID(), mode: .reviewOnly)
    #expect(review.verified == true)
    #expect(review.detail.contains("no mutable-diff postcondition"))
  }
}
