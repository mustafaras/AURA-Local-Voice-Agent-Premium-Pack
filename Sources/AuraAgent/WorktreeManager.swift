import AuraCore
import AuraPolicy
import AuraShell
import Foundation

/// Creates and removes isolated `git worktree`s for multi-agent orchestration
/// tasks.
///
/// Each mutable task gets exactly one worktree, matching the master prompt's
/// concurrency rule ("Allow one mutable task per worktree"). Creation and
/// removal are policy-gated the same way `CodexAdapter`/`ClaudeAdapter`/
/// `CopilotAdapter` gate their own CLI runs: this actor calls
/// `PolicyEngine.evaluate` itself before ever touching `git`, since
/// `AuraShell.execute`'s own doc comment documents that it "constructs but
/// does not enforce" a policy decision.
///
/// `git` is spawned through a dedicated `AuraShell` scoped to only the
/// configured `git` binary, mirroring `CodexConfiguration
/// .derivedShellConfiguration()`.
public actor WorktreeManager {
  private let configuration: WorktreeConfiguration
  private let policyEngine: PolicyEngine
  private let shell: AuraShell
  private let eventBus: AuraEventBus

  private var activeWorktrees: [UUID: WorktreeHandle] = [:]
  private var reservedPaths: Set<String> = []

  public init(
    configuration: WorktreeConfiguration,
    policyEngine: PolicyEngine,
    eventBus: AuraEventBus = .shared
  ) {
    self.configuration = configuration
    self.policyEngine = policyEngine
    self.eventBus = eventBus
    self.shell = AuraShell(configuration: configuration.derivedShellConfiguration())
  }

  /// Create an isolated worktree for `taskID`, branched from `baseRef` inside
  /// `repositoryRoot`. Throws if a worktree already exists for this task ID,
  /// if policy denies the creation, or if `git worktree add` fails.
  @discardableResult
  public func prepareWorktree(
    taskID: UUID,
    repositoryRoot: String,
    baseRef: String = "HEAD",
    actor: ActorID,
    sessionID: UUID
  ) async throws(AuraError) -> WorktreeHandle {
    guard activeWorktrees[taskID] == nil else {
      throw AuraError.taskInvalidState("worktree already prepared for task \(taskID)")
    }

    let branch = "\(configuration.branchPrefix)\(taskID.uuidString.lowercased())"
    let path = (configuration.worktreeRoot(for: repositoryRoot) as NSString)
      .appendingPathComponent(taskID.uuidString.lowercased())

    guard !reservedPaths.contains(path) else {
      throw AuraError.taskInvalidState("worktree path already reserved: \(path)")
    }

    let policyRequest = PolicyEvaluationRequest(
      capability: .agentWorktreeCreate,
      actor: actor,
      target: PolicyTarget(directoryPath: path),
      sessionID: sessionID,
      correlationID: taskID,
      causationID: taskID
    )
    let decision = await policyEngine.evaluate(policyRequest)
    guard case .allow = decision else {
      let reason = denialReason(for: decision)
      await emit(
        WorktreeCreationFailedEvent(taskID: taskID, reason: reason), actor: actor,
        correlationID: taskID, causationID: taskID)
      throw AuraError.orchestrationError("worktree creation denied: \(reason)")
    }

    reservedPaths.insert(path)

    let command = Command(
      executable: configuration.gitExecutablePath,
      arguments: ["worktree", "add", "-b", branch, path, baseRef],
      workingDirectory: repositoryRoot,
      timeoutSeconds: configuration.defaultTimeoutSeconds,
      riskTier: .mutation
    )

    let result = await shell.execute(
      command: command, actor: actor, sessionID: sessionID, correlationID: taskID,
      causationID: taskID)

    switch result {
    case .success(let processResult) where processResult.exitCode == 0:
      let handle = WorktreeHandle(
        taskID: taskID, repositoryRoot: repositoryRoot, path: path, branch: branch,
        baseRef: baseRef)
      activeWorktrees[taskID] = handle
      await emit(
        WorktreeCreatedEvent(taskID: taskID, path: path, branch: branch, baseRef: baseRef),
        actor: actor, correlationID: taskID, causationID: taskID)
      return handle

    case .success(let processResult):
      reservedPaths.remove(path)
      let reason = "git worktree add exited \(processResult.exitCode): \(processResult.stderr)"
      await emit(
        WorktreeCreationFailedEvent(taskID: taskID, reason: reason), actor: actor,
        correlationID: taskID, causationID: taskID)
      throw AuraError.orchestrationError(reason)

    case .failure(let error):
      reservedPaths.remove(path)
      await emit(
        WorktreeCreationFailedEvent(taskID: taskID, reason: error.localizedDescription),
        actor: actor, correlationID: taskID, causationID: taskID)
      throw error
    }
  }

  /// Remove a previously prepared worktree. `force: true` discards
  /// uncommitted changes (required by `git worktree remove` whenever the
  /// worktree is dirty); `force: false` fails loudly instead of silently
  /// discarding work.
  public func removeWorktree(
    taskID: UUID,
    actor: ActorID,
    sessionID: UUID,
    force: Bool = false
  ) async throws(AuraError) {
    guard let handle = activeWorktrees[taskID] else {
      throw AuraError.taskNotFound(taskID)
    }

    let policyRequest = PolicyEvaluationRequest(
      capability: .agentWorktreeRemove,
      actor: actor,
      target: PolicyTarget(directoryPath: handle.path),
      sessionID: sessionID,
      correlationID: taskID,
      causationID: taskID
    )
    let decision = await policyEngine.evaluate(policyRequest)
    guard case .allow = decision else {
      throw AuraError.orchestrationError(
        "worktree removal denied: \(denialReason(for: decision))")
    }

    var arguments = ["worktree", "remove", handle.path]
    if force {
      arguments.append("--force")
    }
    let command = Command(
      executable: configuration.gitExecutablePath,
      arguments: arguments,
      workingDirectory: handle.repositoryRoot,
      timeoutSeconds: configuration.defaultTimeoutSeconds,
      riskTier: .mutation
    )

    let result = await shell.execute(
      command: command, actor: actor, sessionID: sessionID, correlationID: taskID,
      causationID: taskID)

    switch result {
    case .success(let processResult) where processResult.exitCode == 0:
      activeWorktrees.removeValue(forKey: taskID)
      reservedPaths.remove(handle.path)
      await emit(
        WorktreeRemovedEvent(taskID: taskID, path: handle.path, forced: force), actor: actor,
        correlationID: taskID, causationID: taskID)

    case .success(let processResult):
      throw AuraError.orchestrationError(
        "git worktree remove exited \(processResult.exitCode): \(processResult.stderr)")

    case .failure(let error):
      throw error
    }
  }

  /// Read the diff between a worktree's current state and its base ref.
  /// Read-only evidence capture, analogous to `FilesystemEvidence` snapshots
  /// elsewhere in the codebase — not policy-gated, since it mutates nothing.
  public func diff(taskID: UUID, actor: ActorID, sessionID: UUID) async throws(AuraError) -> String
  {
    guard let handle = activeWorktrees[taskID] else {
      throw AuraError.taskNotFound(taskID)
    }
    let command = Command(
      executable: configuration.gitExecutablePath,
      arguments: ["diff", handle.baseRef],
      workingDirectory: handle.path,
      timeoutSeconds: configuration.defaultTimeoutSeconds,
      riskTier: .observation
    )
    let result = await shell.execute(
      command: command, actor: actor, sessionID: sessionID, correlationID: taskID,
      causationID: taskID)
    switch result {
    case .success(let processResult):
      return processResult.stdout
    case .failure(let error):
      throw error
    }
  }

  /// The active handle for a task, if a worktree has been prepared for it.
  public func handle(for taskID: UUID) -> WorktreeHandle? {
    activeWorktrees[taskID]
  }

  /// Number of currently active (not-yet-removed) worktrees.
  public func activeCount() -> Int {
    activeWorktrees.count
  }

  private func denialReason(for decision: PolicyDecision) -> String {
    switch decision {
    case .deny(let reason, _):
      return reason
    case .confirm:
      return "confirmation required but not supported for worktree lifecycle actions"
    case .allow:
      return "unreachable"
    }
  }

  private func emit<Payload: EventPayload>(
    _ payload: Payload,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}
