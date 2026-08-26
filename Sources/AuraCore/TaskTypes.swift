import Foundation

// MARK: - Task priority

/// Execution priority of a durable task.
public enum TaskPriority: Int, Codable, Sendable, Equatable, CaseIterable {
  case background = 0
  case normal = 1
  case high = 2
  case urgent = 3
}

// MARK: - Task state

/// Lifecycle state of a durable task.
public enum TaskState: String, Codable, Sendable, Equatable, CaseIterable {
  /// Waiting in the queue until resources are available.
  case pending
  /// Currently executing.
  case running
  /// Paused because of inactivity, cancellation request, or resource pressure.
  case paused
  /// Cancelled by the user or policy engine; may retain a checkpoint.
  case cancelled
  /// Finished successfully.
  case completed
  /// Finished with a failure or expired deadline.
  case failed
}

// MARK: - Task status snapshot

/// Immutable scope snapshot of a durable task: which coding backend, mode,
/// workspace, and backend-health state the task was launched under.
///
/// This is the OPEN-10 "task scope metadata" projection. Before it existed,
/// the Task Center could only show a `TaskStatus` whose fields were the
/// durable `TaskState` lifecycle fields — the backend/model/workspace/account
/// scope that R9's Task Center requires was encoded only inside the opaque
/// `TaskRequest.context` dictionary (`agent.backend`, `coding.mode`,
/// `coding.workspace`, `coding.backendHealth`), invisible to the UI. The
/// engine now derives this typed snapshot from that context so the Task
/// Center can present it truthfully without leaking every internal key.
public struct TaskScopeInfo: Codable, Sendable, Equatable {
  public let backend: String
  public let mode: String
  public let workspace: String
  public let backendHealth: String

  public init(backend: String, mode: String, workspace: String, backendHealth: String) {
    self.backend = backend
    self.mode = mode
    self.workspace = workspace
    self.backendHealth = backendHealth
  }
}

/// Immutable summary of a task suitable for UI listings and progress reports.
public struct TaskStatus: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let state: TaskState
  public let objective: String
  public let priority: TaskPriority
  public let createdAt: Date
  public let deadline: Date?
  public let updatedAt: Date
  public let completedSteps: Int
  public let totalSteps: Int
  public let currentStepDescription: String
  public let errorMessage: String?
  /// Scope the task was enqueued under (backend/mode/workspace/health), or
  /// `nil` when the task did not carry coding-agent scope context. A plain
  /// task shows no scope, which is itself truthful.
  public let scope: TaskScopeInfo?

  public var percentComplete: Double {
    totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
  }

  public init(
    id: UUID,
    state: TaskState,
    objective: String,
    priority: TaskPriority,
    createdAt: Date,
    deadline: Date? = nil,
    updatedAt: Date,
    completedSteps: Int = 0,
    totalSteps: Int = 0,
    currentStepDescription: String = "",
    errorMessage: String? = nil,
    scope: TaskScopeInfo? = nil
  ) {
    self.id = id
    self.state = state
    self.objective = objective
    self.priority = priority
    self.createdAt = createdAt
    self.deadline = deadline
    self.updatedAt = updatedAt
    self.completedSteps = completedSteps
    self.totalSteps = totalSteps
    self.currentStepDescription = currentStepDescription
    self.errorMessage = errorMessage
    self.scope = scope
  }
}

// MARK: - Task request

/// Request to enqueue a durable task.
public struct TaskRequest: Codable, Sendable, Equatable {
  public let objective: String
  public let priority: TaskPriority
  public let deadline: Date?
  public let inactivityTimeoutSeconds: Double?
  public let maxRetries: Int?
  public let context: [String: String]

  public init(
    objective: String,
    priority: TaskPriority = .normal,
    deadline: Date? = nil,
    inactivityTimeoutSeconds: Double? = nil,
    maxRetries: Int? = nil,
    context: [String: String] = [:]
  ) {
    self.objective = objective
    self.priority = priority
    self.deadline = deadline
    self.inactivityTimeoutSeconds = inactivityTimeoutSeconds
    self.maxRetries = maxRetries
    self.context = context
  }
}
