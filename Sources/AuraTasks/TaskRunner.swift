import AuraCore
import Foundation

/// Conformers execute the durable work for an individual task.
///
/// The engine owns the lifecycle; the runner reports progress, checkpoints, and
/// terminal outcomes through `TaskExecutionContext`. A runner must respond to
/// cancellation by throwing `CancellationError` from its `run` method or by
/// completing quickly.
public protocol TaskRunner: Sendable {
  /// Prepare a concrete plan from the task request. Called once before execution.
  func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan

  /// Execute the task. Use `context` to report progress and checkpoints.
  func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError)
}

/// A coarse plan produced before running a task.
public struct TaskPlan: Codable, Sendable, Equatable {
  /// Estimated number of steps to completion.
  public let totalSteps: Int

  /// Ordered step descriptions for progress reporting.
  public let stepDescriptions: [String]

  public init(totalSteps: Int, stepDescriptions: [String] = []) {
    self.totalSteps = max(0, totalSteps)
    self.stepDescriptions = stepDescriptions
  }
}

/// Context passed to a runner to report progress and save checkpoints.
public actor TaskExecutionContext {
  public let taskID: UUID
  private let onProgress: @Sendable (TaskProgressUpdate) async -> Void
  private let onCheckpoint: @Sendable (TaskCheckpoint) async throws(AuraError) -> Void

  private var _isCancelled = false
  private var _lastActivityAt = Date()

  public var isCancelled: Bool {
    _isCancelled
  }

  internal init(
    taskID: UUID,
    onProgress: @escaping @Sendable (TaskProgressUpdate) async -> Void,
    onCheckpoint: @escaping @Sendable (TaskCheckpoint) async throws(AuraError) -> Void
  ) {
    self.taskID = taskID
    self.onProgress = onProgress
    self.onCheckpoint = onCheckpoint
    self._lastActivityAt = Date()
  }

  public func reportProgress(
    completedSteps: Int,
    totalSteps: Int,
    currentStepDescription: String
  ) async {
    _lastActivityAt = Date()
    await onProgress(
      TaskProgressUpdate(
        taskID: taskID,
        completedSteps: completedSteps,
        totalSteps: totalSteps,
        currentStepDescription: currentStepDescription
      )
    )
  }

  public func reportCheckpoint(name: String, state: [String: String]) async throws(AuraError) {
    _lastActivityAt = Date()
    try await onCheckpoint(
      TaskCheckpoint(taskID: taskID, name: name, state: state)
    )
  }

  public func markCancelled() {
    _isCancelled = true
  }

  public func touchActivity() {
    _lastActivityAt = Date()
  }

  public func secondsSinceLastActivity(referenceDate: Date = Date()) -> Double {
    referenceDate.timeIntervalSince(_lastActivityAt)
  }

  public func checkCancellation() {
    if Task.isCancelled || _isCancelled {
      markCancelled()
    }
  }
}

/// Internal progress update used between runner and engine.
struct TaskProgressUpdate: Sendable {
  let taskID: UUID
  let completedSteps: Int
  let totalSteps: Int
  let currentStepDescription: String
}
