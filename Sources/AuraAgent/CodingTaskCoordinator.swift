import AuraCore
import AuraTasks
import AuraVSCode
import Foundation

public enum CodingTaskMode: String, Codable, Sendable, Equatable {
  case readOnly
  case writeCapable
  case reviewOnly

  var requiresWorktree: Bool {
    self == .writeCapable
  }
}

/// User/bridge input for a durable coding task. Workspace state is supplied by
/// the caller after the authenticated VS Code observation route; it is not
/// guessed from the process current directory.
public struct CodingTaskRequest: Codable, Sendable, Equatable {
  public let objective: String
  public let backend: AgentBackendID
  public let mode: CodingTaskMode
  public let explicitWorkspacePath: String?
  public let activeWorkspace: VSCodeWorkspaceInfo
  public let activeDurableTaskPath: String?
  public let projectCandidates: [String]
  public let repositoryRoot: String?
  public let baseRef: String
  public let deadline: Date?
  public let inactivityTimeoutSeconds: Double?
  public let maxRetries: Int?
  public let context: [String: String]

  public init(
    objective: String,
    backend: AgentBackendID,
    mode: CodingTaskMode,
    explicitWorkspacePath: String? = nil,
    activeWorkspace: VSCodeWorkspaceInfo = VSCodeWorkspaceInfo(),
    activeDurableTaskPath: String? = nil,
    projectCandidates: [String] = [],
    repositoryRoot: String? = nil,
    baseRef: String = "HEAD",
    deadline: Date? = nil,
    inactivityTimeoutSeconds: Double? = nil,
    maxRetries: Int? = nil,
    context: [String: String] = [:]
  ) {
    self.objective = objective
    self.backend = backend
    self.mode = mode
    self.explicitWorkspacePath = explicitWorkspacePath
    self.activeWorkspace = activeWorkspace
    self.activeDurableTaskPath = activeDurableTaskPath
    self.projectCandidates = projectCandidates
    self.repositoryRoot = repositoryRoot
    self.baseRef = baseRef
    self.deadline = deadline
    self.inactivityTimeoutSeconds = inactivityTimeoutSeconds
    self.maxRetries = maxRetries
    self.context = context
  }
}

public struct CodingTaskPreflight: Codable, Sendable, Equatable {
  public let backend: AgentBackendID
  public let mode: CodingTaskMode
  public let workspace: VSCodeWorkspaceResolution
  public let backendHealth: AgentBackendHealth
  public let detail: String

  public init(
    backend: AgentBackendID,
    mode: CodingTaskMode,
    workspace: VSCodeWorkspaceResolution,
    backendHealth: AgentBackendHealth,
    detail: String
  ) {
    self.backend = backend
    self.mode = mode
    self.workspace = workspace
    self.backendHealth = backendHealth
    self.detail = detail
  }
}

/// Coordinates the R6 durable coding flow: resolve workspace, verify backend
/// readiness, isolate mutable work, then enqueue a typed durable task.
public actor CodingTaskCoordinator {
  private let taskEngine: AuraTaskEngine
  private let backendRunner: any TaskRunner
  private let worktreeManager: WorktreeManager?
  private let healthRegistry: AgentBackendHealthRegistry
  private let workspaceResolver: VSCodeWorkspaceResolver

  public init(
    taskEngine: AuraTaskEngine,
    backendRunner: any TaskRunner,
    healthRegistry: AgentBackendHealthRegistry,
    worktreeManager: WorktreeManager? = nil,
    workspaceResolver: VSCodeWorkspaceResolver = VSCodeWorkspaceResolver()
  ) {
    self.taskEngine = taskEngine
    self.backendRunner = backendRunner
    self.healthRegistry = healthRegistry
    self.worktreeManager = worktreeManager
    self.workspaceResolver = workspaceResolver
  }

  public func preflight(
    _ request: CodingTaskRequest
  ) async throws(AuraError) -> CodingTaskPreflight {
    let objective = request.objective.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !objective.isEmpty else {
      throw .taskError("coding task objective must not be empty")
    }
    let workspace = workspaceResolver.resolve(
      explicitTarget: request.explicitWorkspacePath,
      activeWorkspace: request.activeWorkspace,
      activeDurableTaskPath: request.activeDurableTaskPath,
      projectCandidates: request.projectCandidates)
    guard workspace.isResolved else {
      throw .taskError(workspace.detail)
    }
    let health = await healthRegistry.refresh(
      backend: request.backend,
      workspacePath: workspace.path)
    switch health.state {
    case .unavailable, .unauthorized, .versionMismatch:
      throw .taskError(
        "backend " + request.backend.rawValue + " unavailable: " + health.detail)
    case .degraded where request.mode == .writeCapable:
      throw .taskError(
        "write-capable coding requires ready backend evidence: " + health.detail)
    case .ready, .degraded:
      break
    }
    return CodingTaskPreflight(
      backend: request.backend,
      mode: request.mode,
      workspace: workspace,
      backendHealth: health,
      detail: "workspace, backend readiness, mode, and policy route are explicit")
  }

  @discardableResult
  public func enqueue(
    _ request: CodingTaskRequest,
    actor: ActorID = .user,
    sessionID: UUID = UUID()
  ) async throws(AuraError) -> TaskStatus {
    let preflight = try await preflight(request)
    let taskID = UUID()
    var context = request.context
    context["agent.backend"] = request.backend.rawValue
    context["coding.mode"] = request.mode.rawValue
    context["coding.workspace"] = preflight.workspace.path ?? ""
    context["coding.backendHealth"] = preflight.backendHealth.state.rawValue

    var preparedWorktree: WorktreeHandle?
    if request.mode.requiresWorktree {
      guard let worktreeManager else {
        throw .taskError("write-capable coding requires an isolated worktree manager")
      }
      guard let repositoryRoot = request.repositoryRoot else {
        throw .taskError("write-capable coding requires an explicit repository root")
      }
      let handle = try await worktreeManager.prepareWorktree(
        taskID: taskID,
        repositoryRoot: repositoryRoot,
        baseRef: request.baseRef,
        actor: actor,
        sessionID: sessionID)
      preparedWorktree = handle
      context["coding.worktree"] = handle.path
    }

    // Route the resolved workspace and the mode's sandbox tier into the
    // per-backend context keys the task runners actually read. Before this,
    // the coordinator resolved a workspace and prepared an isolated worktree
    // but never set `codex.workingDirectory` / `claude.workingDirectory` /
    // `copilot.workingDirectory` (nor the sandbox/profile keys), so a
    // write-capable task ran in the backend's *default* working directory
    // with its *default read-only* sandbox — the worktree was disconnected
    // from execution. This is the R6 "route workspace and isolation" gate.
    let workingDirectory = preparedWorktree?.path ?? preflight.workspace.path
    switch request.backend {
    case .codex:
      context[CodexTaskRunner.workingDirectoryContextKey] = workingDirectory
      context[CodexTaskRunner.sandboxContextKey] = request.mode.sandboxTier
    case .claude:
      context[ClaudeTaskRunner.workingDirectoryContextKey] = workingDirectory
      context[ClaudeTaskRunner.toolProfileContextKey] = request.mode.sandboxTier
    case .copilot:
      context[CopilotTaskRunner.workingDirectoryContextKey] = workingDirectory
      context[CopilotTaskRunner.toolProfileContextKey] = request.mode.sandboxTier
    }

    let taskRequest = TaskRequest(
      objective: request.objective,
      deadline: request.deadline,
      inactivityTimeoutSeconds: request.inactivityTimeoutSeconds,
      maxRetries: request.maxRetries,
      context: context)
    do {
      return try await taskEngine.enqueue(
        request: taskRequest,
        runner: backendRunner,
        taskID: taskID)
    } catch {
      if preparedWorktree != nil, let worktreeManager {
        try? await worktreeManager.removeWorktree(
          taskID: taskID,
          actor: actor,
          sessionID: sessionID,
          force: false)
      }
      throw error
    }
  }
}

/// Maps a `CodingTaskMode` to the per-backend sandbox/tool tier it must run
/// under. Write-capable mode uses the isolated worktree and the
/// workspace-write tier; read-only and review-only both run against the
/// resolved workspace under the read-only tier (review reads, never writes).
private extension CodingTaskMode {
  var sandboxTier: String {
    switch self {
    case .readOnly, .reviewOnly:
      return "readOnly"
    case .writeCapable:
      return "workspaceWrite"
    }
  }
}

/// Verdict on whether a completed coding task satisfies its evidence
/// postcondition. A write-capable task is only a success if its isolated
/// worktree actually changed from the base ref; a backend that reports
/// "completed" but produced no diff is a false-backend-success and must fail
/// closed.
public struct CodingTaskVerification: Sendable, Equatable {
  public let taskID: UUID
  public let verified: Bool
  public let detail: String

  public init(taskID: UUID, verified: Bool, detail: String) {
    self.taskID = taskID
    self.verified = verified
    self.detail = detail
  }
}

extension CodingTaskCoordinator {
  /// Verify a write-capable task's evidence postcondition: the isolated
  /// worktree must have a non-empty diff against its base ref. A write-capable
  /// task that finished "completed" with no diff is a false backend success
  /// and fails closed. Read-only and review-only tasks have no diff evidence
  /// requirement (they are not expected to mutate the workspace), so this
  /// returns verified unless a worktree was unexpectedly prepared.
  public func verifyCompletion(
    taskID: UUID,
    mode: CodingTaskMode,
    actor: ActorID = .user,
    sessionID: UUID = UUID()
  ) async -> CodingTaskVerification {
    guard mode == .writeCapable else {
      return CodingTaskVerification(
        taskID: taskID, verified: true,
        detail: "\(mode.rawValue) mode has no mutable-diff postcondition")
    }
    guard let worktreeManager else {
      return CodingTaskVerification(
        taskID: taskID, verified: false,
        detail: "write-capable task cannot be verified without a worktree manager")
    }
    guard await worktreeManager.handle(for: taskID) != nil else {
      return CodingTaskVerification(
        taskID: taskID, verified: false,
        detail: "write-capable task \(taskID) has no prepared worktree to verify")
    }
    do {
      let diff = try await worktreeManager.diff(
        taskID: taskID, actor: actor, sessionID: sessionID)
      let trimmed = diff.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        return CodingTaskVerification(
          taskID: taskID, verified: false,
          detail: "write-capable task \(taskID) reported completed but produced no diff (false-backend-success)")
      }
      return CodingTaskVerification(
        taskID: taskID, verified: true,
        detail: "write-capable task \(taskID) produced a non-empty diff against base")
    } catch {
      return CodingTaskVerification(
        taskID: taskID, verified: false,
        detail: "write-capable task \(taskID) diff verification failed: \(error.localizedDescription)")
    }
  }
}
