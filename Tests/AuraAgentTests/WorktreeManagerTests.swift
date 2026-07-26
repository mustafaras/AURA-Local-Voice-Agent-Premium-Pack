import AuraAgent
import AuraCore
import AuraPolicy
import AuraStore
import Foundation
import Testing

/// Real, authorized `git` invocations against scratch repositories created
/// under `$HOME` (matching `CodexTaskRunnerTests`'s precedent of using
/// `$HOME` rather than `$TMPDIR` to satisfy `WorktreeConfiguration`'s default
/// `allowedWorkingDirectories` unambiguously). Every scratch repository is
/// removed in a `defer` block.

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
      domain: "worktree-manager-tests", code: Int(process.terminationStatus),
      userInfo: [NSLocalizedDescriptionKey: output])
  }
  return output
}

private func makeScratchGitRepo() throws -> String {
  let root =
    NSHomeDirectory() + "/.aura-worktree-tests/\(UUID().uuidString)"
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

// MARK: - Policy engine helpers

private func makeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makePolicyEngine(
  configuration: PolicyConfiguration = PolicyConfiguration(
    defaultConfirmationTier: .destructive,
    allowByDefaultTiers: [.observation, .reversible, .mutation],
    denyByDefaultTiers: [.destructive]
  ),
  eventBus: AuraEventBus
) async throws -> PolicyEngine {
  let store = try await makeTempStore()
  return try await PolicyEngine(configuration: configuration, eventBus: eventBus, store: store)
}

private func makeManager(
  repoRoot: String, eventBus: AuraEventBus, policyEngine: PolicyEngine
) -> WorktreeManager {
  WorktreeManager(configuration: WorktreeConfiguration(), policyEngine: policyEngine, eventBus: eventBus)
}

// MARK: - Creation and isolation

@Test
func worktreeManagerCreatesIsolatedWorktree() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "worktree"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let manager = makeManager(repoRoot: repoRoot, eventBus: bus, policyEngine: policyEngine)
  let taskID = UUID()
  let sessionID = UUID()

  let handle = try await manager.prepareWorktree(
    taskID: taskID, repositoryRoot: repoRoot, actor: .orchestrator, sessionID: sessionID)

  #expect(FileManager.default.fileExists(atPath: handle.path))
  #expect(handle.branch.hasPrefix("aura/orchestration-"))

  // Write inside the worktree and confirm the main repo is untouched — real
  // filesystem isolation, not a mocked assertion.
  let worktreeFile = handle.path + "/file.txt"
  try "changed in worktree\n".appendToFile(atPath: worktreeFile)
  let mainRepoContents = try String(contentsOfFile: repoRoot + "/file.txt", encoding: .utf8)
  #expect(mainRepoContents == "hello\n")

  let worktreeContents = try String(contentsOfFile: worktreeFile, encoding: .utf8)
  #expect(worktreeContents.contains("changed in worktree"))

  #expect(await manager.activeCount() == 1)
  #expect(await manager.handle(for: taskID) != nil)
}

@Test
func worktreeManagerRejectsDuplicateTaskID() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "dup"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let manager = makeManager(repoRoot: repoRoot, eventBus: bus, policyEngine: policyEngine)
  let taskID = UUID()

  _ = try await manager.prepareWorktree(
    taskID: taskID, repositoryRoot: repoRoot, actor: .orchestrator, sessionID: UUID())

  await #expect(throws: AuraError.self) {
    try await manager.prepareWorktree(
      taskID: taskID, repositoryRoot: repoRoot, actor: .orchestrator, sessionID: UUID())
  }
  #expect(await manager.activeCount() == 1)
}

// MARK: - Policy gate

@Test
func worktreeManagerDenyPathNeverTouchesGit() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "deny"))
  let policyEngine = try await makePolicyEngine(
    configuration: PolicyConfiguration(
      defaultConfirmationTier: .destructive,
      allowByDefaultTiers: [.observation, .reversible],
      denyByDefaultTiers: [.mutation, .destructive]
    ),
    eventBus: bus)
  let manager = makeManager(repoRoot: repoRoot, eventBus: bus, policyEngine: policyEngine)
  let taskID = UUID()

  await #expect(throws: AuraError.self) {
    try await manager.prepareWorktree(
      taskID: taskID, repositoryRoot: repoRoot, actor: .orchestrator, sessionID: UUID())
  }
  #expect(await manager.activeCount() == 0)
  #expect(await manager.handle(for: taskID) == nil)

  // No worktree directory should exist on disk since git was never invoked.
  let expectedPath =
    repoRoot + "/.aura-worktrees/" + taskID.uuidString.lowercased()
  #expect(!FileManager.default.fileExists(atPath: expectedPath))
}

// MARK: - Removal

@Test
func worktreeManagerRemovesCleanWorktreeWithoutForce() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "removeClean"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let manager = makeManager(repoRoot: repoRoot, eventBus: bus, policyEngine: policyEngine)
  let taskID = UUID()

  let handle = try await manager.prepareWorktree(
    taskID: taskID, repositoryRoot: repoRoot, actor: .orchestrator, sessionID: UUID())

  try await manager.removeWorktree(taskID: taskID, actor: .orchestrator, sessionID: UUID())

  #expect(!FileManager.default.fileExists(atPath: handle.path))
  #expect(await manager.activeCount() == 0)
}

@Test
func worktreeManagerRemovalRequiresForceWhenDirty() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "removeDirty"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let manager = makeManager(repoRoot: repoRoot, eventBus: bus, policyEngine: policyEngine)
  let taskID = UUID()

  let handle = try await manager.prepareWorktree(
    taskID: taskID, repositoryRoot: repoRoot, actor: .orchestrator, sessionID: UUID())
  try "dirty\n".appendToFile(atPath: handle.path + "/file.txt")

  await #expect(throws: AuraError.self) {
    try await manager.removeWorktree(taskID: taskID, actor: .orchestrator, sessionID: UUID())
  }
  #expect(await manager.activeCount() == 1)

  try await manager.removeWorktree(
    taskID: taskID, actor: .orchestrator, sessionID: UUID(), force: true)
  #expect(!FileManager.default.fileExists(atPath: handle.path))
  #expect(await manager.activeCount() == 0)
}

@Test
func worktreeManagerRemoveUnknownTaskThrowsNotFound() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "removeUnknown"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let manager = makeManager(repoRoot: repoRoot, eventBus: bus, policyEngine: policyEngine)

  await #expect(throws: AuraError.self) {
    try await manager.removeWorktree(taskID: UUID(), actor: .orchestrator, sessionID: UUID())
  }
}

// MARK: - Diff evidence

@Test
func worktreeManagerDiffReflectsWorktreeChanges() async throws {
  let repoRoot = try makeScratchGitRepo()
  defer { removeScratchRepo(repoRoot) }

  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "diff"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let manager = makeManager(repoRoot: repoRoot, eventBus: bus, policyEngine: policyEngine)
  let taskID = UUID()

  let handle = try await manager.prepareWorktree(
    taskID: taskID, repositoryRoot: repoRoot, actor: .orchestrator, sessionID: UUID())
  try "added by implementer\n".appendToFile(atPath: handle.path + "/file.txt")

  let diff = try await manager.diff(taskID: taskID, actor: .orchestrator, sessionID: UUID())
  #expect(diff.contains("added by implementer"))
}

// MARK: - Test helpers

extension String {
  fileprivate func appendToFile(atPath path: String) throws {
    guard let handle = FileHandle(forWritingAtPath: path) else {
      try self.write(toFile: path, atomically: true, encoding: .utf8)
      return
    }
    defer { handle.closeFile() }
    handle.seekToEndOfFile()
    handle.write(Data(self.utf8))
  }
}
