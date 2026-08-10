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

  public func preflight(_ request: CodingTaskRequest) async throws(AuraError) -> CodingTaskPreflight
  {
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
