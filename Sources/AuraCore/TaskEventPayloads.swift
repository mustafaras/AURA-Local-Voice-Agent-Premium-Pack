import Foundation

// MARK: - Durable task engine event payloads

/// Emitted when a new durable task is enqueued.
public struct TaskEnqueuedEvent: EventPayload {
  public static let eventType = "task.enqueued"

  public let taskID: UUID
  public let objective: String
  public let priority: TaskPriority
  public let deadline: Date?
  public let enqueuedAt: Date

  public init(
    taskID: UUID,
    objective: String,
    priority: TaskPriority,
    deadline: Date? = nil,
    enqueuedAt: Date = Date()
  ) {
    self.taskID = taskID
    self.objective = objective
    self.priority = priority
    self.deadline = deadline
    self.enqueuedAt = enqueuedAt
  }
}

/// Emitted when a task transitions to a new state.
public struct TaskStateChangedEvent: EventPayload {
  public static let eventType = "task.stateChanged"

  public let taskID: UUID
  public let previousState: TaskState
  public let newState: TaskState
  public let changedAt: Date

  public init(
    taskID: UUID,
    previousState: TaskState,
    newState: TaskState,
    changedAt: Date = Date()
  ) {
    self.taskID = taskID
    self.previousState = previousState
    self.newState = newState
    self.changedAt = changedAt
  }
}

/// Emitted periodically or on meaningful progress updates for a task.
public struct TaskProgressEvent: EventPayload {
  public static let eventType = "task.progress"

  public let taskID: UUID
  public let completedSteps: Int
  public let totalSteps: Int
  public let currentStepDescription: String
  public let percentComplete: Double
  public let updatedAt: Date

  public init(
    taskID: UUID,
    completedSteps: Int,
    totalSteps: Int,
    currentStepDescription: String,
    updatedAt: Date = Date()
  ) {
    self.taskID = taskID
    self.completedSteps = completedSteps
    self.totalSteps = totalSteps
    self.currentStepDescription = currentStepDescription
    self.percentComplete = totalSteps > 0
      ? Double(completedSteps) / Double(totalSteps)
      : 0
    self.updatedAt = updatedAt
  }
}

/// Emitted when a running task is paused because of inactivity or cancellation.
public struct TaskPausedEvent: EventPayload {
  public static let eventType = "task.paused"

  public let taskID: UUID
  public let checkpointKey: String
  public let pausedAt: Date

  public init(
    taskID: UUID,
    checkpointKey: String,
    pausedAt: Date = Date()
  ) {
    self.taskID = taskID
    self.checkpointKey = checkpointKey
    self.pausedAt = pausedAt
  }
}

/// Emitted when a previously paused task resumes execution.
public struct TaskResumedEvent: EventPayload {
  public static let eventType = "task.resumed"

  public let taskID: UUID
  public let resumedAt: Date

  public init(
    taskID: UUID,
    resumedAt: Date = Date()
  ) {
    self.taskID = taskID
    self.resumedAt = resumedAt
  }
}

/// Emitted when a task is explicitly cancelled by the user or policy engine.
public struct TaskCancelledEvent: EventPayload {
  public static let eventType = "task.cancelled"

  public let taskID: UUID
  public let reason: String
  public let cancelledAt: Date

  public init(
    taskID: UUID,
    reason: String,
    cancelledAt: Date = Date()
  ) {
    self.taskID = taskID
    self.reason = reason
    self.cancelledAt = cancelledAt
  }
}

/// Emitted when a task completes, successfully or not.
public struct TaskCompletedEvent: EventPayload {
  public static let eventType = "task.completed"

  public enum Outcome: String, Codable, Sendable, Equatable {
    case succeeded
    case failed
    case cancelled
    case expired
  }

  public let taskID: UUID
  public let outcome: Outcome
  public let summary: String
  public let completedAt: Date

  public init(
    taskID: UUID,
    outcome: Outcome,
    summary: String,
    completedAt: Date = Date()
  ) {
    self.taskID = taskID
    self.outcome = outcome
    self.summary = summary
    self.completedAt = completedAt
  }
}

/// Emitted when a task checkpoint is persisted to storage.
public struct TaskCheckpointEvent: EventPayload {
  public static let eventType = "task.checkpoint"

  public let taskID: UUID
  public let checkpointKey: String
  public let checkpointedAt: Date

  public init(
    taskID: UUID,
    checkpointKey: String,
    checkpointedAt: Date = Date()
  ) {
    self.taskID = taskID
    self.checkpointKey = checkpointKey
    self.checkpointedAt = checkpointedAt
  }
}
