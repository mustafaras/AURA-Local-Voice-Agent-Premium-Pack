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
    errorMessage: String? = nil
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
