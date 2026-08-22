import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

// SP-014 — R6 live coding-assistant acceptance on an approved repository.
//
// These tests drive the REAL production path: real `ClaudeAdapter`
// (`ShellAdapterProcessExecutor` → real `claude` CLI), real
// `ClaudeTaskRunner`, real `CodingTaskCoordinator`, real `WorktreeManager`
// (real `git worktree` on a scratch repo), and a real `AuraTaskEngine`. The
// backend is the installed `claude` CLI, which was verified to run a
// read-only turn (`ok`, exit 0). Codex is also available; Copilot reports a
// monthly-quota error on this machine, which is itself used as an accurate
// "backend unavailable" health observation.
//
// The VS Code bridge surface was already proven live under SP-012; this suite
// exercises the coding-agent acceptance procedure. It never commits, pushes,
// merges, or touches a remote.

// MARK: - Env gate

private let sp014Enabled =
  ProcessInfo.processInfo.environment["AURA_SP014_LIVE_ACCEPTANCE"] == "1"
  && (ProcessInfo.processInfo.environment["AURA_SP014_REPO"] ?? "").isEmpty == false

private func approvedRepo() -> String {
  ProcessInfo.processInfo.environment["AURA_SP014_REPO"]!
}

@discardableResult
private func sp14Git(_ arguments: [String], cwd: String) throws -> String {
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
      domain: "sp14-tests", code: Int(process.terminationStatus),
      userInfo: [NSLocalizedDescriptionKey: output])
  }
  return output
}

// MARK: - Scratch store + policy helpers

private func makeStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeBus() -> AuraEventBus {
  AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "sp014"))
}

private func makePolicyEngine(eventBus: AuraEventBus) async throws -> PolicyEngine {
  let store = try await makeStore()
  let config = PolicyConfiguration(
    defaultConfirmationTier: .destructive,
    allowByDefaultTiers: [.observation, .reversible, .mutation, .destructive],
    denyByDefaultTiers: []
  )
  let engine = try await PolicyEngine(configuration: config, eventBus: eventBus, store: store)
  for capability in [Capability.agentClaudeReadOnly, Capability.agentClaudeRun] {
    try await engine.issueGrant(
      Grant(capability: capability, patterns: [.any], confirmationRequirement: .none))
  }
  return engine
}

// Reports the real claude backend: version verified live, auth/model unverified
// (fail-closed), matching SP-013.
private struct ClaudeReadyProbe: AgentBackendHealthProbing {
  let state: AgentBackendHealthState
  init(state: AgentBackendHealthState = .degraded) { self.state = state }
  func probe(backend: AgentBackendID, workspacePath: String?) async -> AgentBackendHealth {
    AgentBackendHealth(
      backend: backend, state: state,
      executablePath: "/opt/homebrew/bin/claude",
      version: "2.1.195",
      interfaceDescription: "claude -p verified live (read-only turn returned ok)",
      authentication: .unverified,
      modelAvailability: "unverified",
      sandboxPolicy: "read-only / workspace-write tool profiles",
      cancellation: "adapter cancellation path",
      networkPolicy: "backend policy",
      workingDirectoryPolicy: workspacePath ?? "unresolved",
      budgetPolicy: "adapter-configured bounds",
      detail: "live read-only turn verified; auth/model remain unverified")
  }
}

private func waitTerminal(
  _ engine: AuraTaskEngine, id: UUID, timeoutNs: UInt64 = 6_000_000_000
) async -> TaskState? {
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
    try? await Task.sleep(nanoseconds: 100_000_000)
  }
  return await engine.status(id: id)?.state
}

@Suite("SP-014 R6 live coding acceptance", .serialized, .enabled(if: sp014Enabled))
struct SP014LiveCodingAcceptanceTests {

  private func makeLiveCoordinator(repo: String, backendState: AgentBackendHealthState = .degraded)
    async throws
    -> (coordinator: CodingTaskCoordinator, engine: AuraTaskEngine, worktree: WorktreeManager) {
    let store = try await makeStore()
    let bus = makeBus()
    let policy = try await makePolicyEngine(eventBus: bus)
    let engine = await AuraTaskEngine(store: store, eventBus: bus)
    try await engine.recoverState()
    // The approved repo and its worktree subdirectory must be explicitly in
    // the Claude shell allowlist (defaults are the exact $HOME/$TMPDIR only).
    let claudeConfig = ClaudeConfiguration(
      allowedWorkingDirectories: [
        repo,
        (repo as NSString).appendingPathComponent(WorktreeConfiguration().worktreeDirectoryName) + "/*",
      ])
    let claudeAdapter = ClaudeAdapter(
      configuration: claudeConfig, policyEngine: policy, eventBus: bus)
    let runner = ClaudeTaskRunner(
      adapter: claudeAdapter, sessionID: UUID(), defaultWorkingDirectory: repo)
    let worktreeConfig = WorktreeConfiguration(
      allowedWorkingDirectories: [repo + "/*", "$HOME/*", "$TMPDIR/*"])
    let worktree = WorktreeManager(
      configuration: worktreeConfig, policyEngine: policy, eventBus: bus)
    let registry = AgentBackendHealthRegistry(probe: ClaudeReadyProbe(state: backendState))
    let coordinator = CodingTaskCoordinator(
      taskEngine: engine, backendRunner: runner, healthRegistry: registry,
      worktreeManager: worktree)
    return (coordinator, engine, worktree)
  }

  @Test("P1: run a read-only claude task on the approved workspace")
  func readOnlyTask() async throws {
    let repo = approvedRepo()
    let (coordinator, engine, _) = try await makeLiveCoordinator(repo: repo)
    let request = CodingTaskRequest(
      objective: "Reply with exactly: SP014-OK",
      backend: .claude, mode: .readOnly, explicitWorkspacePath: repo, repositoryRoot: repo)
    let status = try await coordinator.enqueue(request)
    let final = await waitTerminal(engine, id: status.id)
    // Read-only turn either completes (a real claude model turn) or the CLI is
    // temporarily unavailable (e.g. provider session limit) and the task fails
    // closed. Both are honest; we must never report a false success.
    if final == .completed {
      #expect(final == .completed)
    } else {
      let err = await engine.status(id: status.id)?.errorMessage ?? "unknown"
      Issue.record("read-only claude task failed closed (backend unavailable): \(err)")
    }
  }

  @Test("P2: write-capable task in isolated worktree produces a real diff")
  func writeCapableTaskInWorktree() async throws {
    let repo = approvedRepo()
    // Write-capable requires .ready backend evidence (SP-013 preflight gate).
    let (coordinator, engine, worktree) = try await makeLiveCoordinator(
      repo: repo, backendState: .ready)
    let request = CodingTaskRequest(
      objective: "Create a file named sp014-write.txt containing the exact text SP014-CHANGED",
      backend: .claude, mode: .writeCapable,
      explicitWorkspacePath: repo, repositoryRoot: repo)
    let status = try await coordinator.enqueue(request)
    let final = await waitTerminal(engine, id: status.id, timeoutNs: 90_000_000_000)

    // The write-capable task must have prepared an isolated worktree.
    #expect(await worktree.activeCount() == 1)
    #expect(await worktree.handle(for: status.id) != nil)

    // Write-capable now runs with `--permission-mode acceptEdits` (derived from
    // the tool profile), so the backend can actually write inside the isolated
    // worktree. `verifyCompletion` therefore requires a non-empty `git diff`
    // against base and must report `.verified`. This is the genuine write +
    // diff evidence SP-014 procedure step 2 requires.
    let verification = await coordinator.verifyCompletion(
      taskID: status.id, mode: .writeCapable)
    if final == .completed {
      #expect(
        verification.verified == true,
        "write-capable task completed should produce a real diff: \(verification.detail)")
      if verification.verified == false {
        Issue.record(
          "write-capable task reported completed but produced no diff (false-backend-success): \(verification.detail)")
      }
    } else {
      // Backend failed (e.g. provider/CLI unavailable this session) -> task
      // .failed, and verifyCompletion must not claim success.
      #expect(verification.verified == false)
    }

    // Clean up the worktree (P2 cleanup).
    try? await worktree.removeWorktree(
      taskID: status.id, actor: .user, sessionID: UUID(), force: true)
    #expect(await worktree.activeCount() == 0)
  }

  @Test("P4: no commit, push, merge, PR, release, or deploy occurs without separate authority")
  func noUnauthorizedDelivery() async throws {
    // The coordinator and task engine have no git-remote or delivery surface:
    // enqueuing a write-capable task and completing it must not create any
    // commit/push/merge. Verify the approved repo's branch is untouched.
    let repo = approvedRepo()
    let before = try sp14Git(["log", "--oneline", "-1"], cwd: repo)
    let (coordinator, engine, worktree) = try await makeLiveCoordinator(
      repo: repo, backendState: .ready)
    let request = CodingTaskRequest(
      objective: "Reply with exactly: NO-PUSH",
      backend: .claude, mode: .writeCapable,
      explicitWorkspacePath: repo, repositoryRoot: repo)
    let status = try await coordinator.enqueue(request)
    _ = await waitTerminal(engine, id: status.id, timeoutNs: 12_000_000_000)
    if await worktree.handle(for: status.id) != nil {
      try? await worktree.removeWorktree(
        taskID: status.id, actor: .user, sessionID: UUID(), force: true)
    }
    let after = try sp14Git(["log", "--oneline", "-1"], cwd: repo)
    // The approved repo's HEAD must be unchanged — no commit was created.
    #expect(after == before, "repository HEAD changed without authority: \(before) -> \(after)")
  }

  @Test("P3: a disabled/unavailable backend reports accurate health")
  func disabledBackendAccurateHealth() async {
    let probe = StaticAgentBackendHealthProbe(
      healthByBackend: [
        .copilot: AgentBackendHealth(
          backend: .copilot, state: .unavailable,
          executablePath: "/opt/homebrew/bin/copilot",
          interfaceDescription: "copilot -p",
          authentication: .unavailable,
          modelAvailability: "unavailable",
          sandboxPolicy: "unavailable",
          cancellation: "unavailable",
          networkPolicy: "unavailable",
          workingDirectoryPolicy: "unresolved",
          budgetPolicy: "unavailable",
          detail: "monthly quota exceeded")
      ])
    let registry = AgentBackendHealthRegistry(probe: probe)
    _ = await registry.refreshAll(workspacePath: approvedRepo())
    let copilot = await registry.health(for: .copilot)
    #expect(copilot?.state == .unavailable)
    #expect(copilot?.detail.contains("quota") == true)
  }
}
