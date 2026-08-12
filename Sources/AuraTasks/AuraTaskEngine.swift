import AuraCore
import AuraStore
import Foundation

/// Coordinates durable, cancellable, resumable background tasks.
///
/// `AuraTaskEngine` owns a priority queue, tracks active runners, persists
/// checkpoints to `AuraStore`, and enforces cancellation, deadlines, and
/// inactivity timeouts.
public actor AuraTaskEngine {
  var queue = TaskQueue(capacity: 0)
  var activeRunners: [UUID: Task<Void, Never>] = [:]
  var tasksByID: [UUID: AuraTask] = [:]
  var shutdown = false
  var recoveryCompleted = false

  let storeBackend: TaskStoreBackend
  let eventBus: AuraEventBus
  let configuration: TaskConfiguration

  /// Creates a new engine.
  /// - Parameters:
  ///   - store: The `AuraStore` used for checkpoints and task snapshots.
  ///   - eventBus: The typed event bus for task lifecycle events.
  ///   - configuration: Task-specific configuration values.
  public init(
    store: AuraStore,
    eventBus: AuraEventBus = .shared,
    configuration: TaskConfiguration? = nil
  ) async {
    let resolved = configuration ?? TaskConfiguration()
    self.storeBackend = await TaskStoreBackend(store: store)
    self.eventBus = eventBus
    self.configuration = resolved
    self.queue = TaskQueue(capacity: resolved.queueCapacity)
  }

}

// MARK: - AuraTask helpers

extension AuraTask {
  static func from(snapshot: TaskSnapshot) -> AuraTask? {
    let task = AuraTask(
      id: snapshot.id,
      createdAt: snapshot.createdAt,
      priority: snapshot.priority,
      objective: snapshot.objective,
      deadline: snapshot.deadline,
      inactivityTimeoutSeconds: snapshot.inactivityTimeoutSeconds,
      maxRetries: snapshot.maxRetries,
      context: snapshot.context
    )
    task.transition(to: snapshot.state, error: snapshot.errorMessage)
    task.setProgress(
      completedSteps: snapshot.completedSteps,
      totalSteps: snapshot.totalSteps,
      currentStepDescription: snapshot.currentStepDescription
    )
    task.setAttempt(snapshot.attempt)
    task.latestCheckpointName = snapshot.latestCheckpointName
    return task
  }

  func snapshot() -> TaskSnapshot {
    TaskSnapshot(
      id: id,
      state: state,
      priority: priority,
      objective: objective,
      deadline: deadline,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      currentStepDescription: currentStepDescription,
      errorMessage: errorMessage,
      inactivityTimeoutSeconds: inactivityTimeoutSeconds,
      maxRetries: maxRetries,
      attempt: attempt,
      context: context,
      latestCheckpointName: latestCheckpointName
    )
  }

  func requestSnapshot() -> TaskRequest {
    TaskRequest(
      objective: objective,
      priority: priority,
      deadline: deadline,
      inactivityTimeoutSeconds: inactivityTimeoutSeconds,
      maxRetries: maxRetries,
      context: context
    )
  }

  func setAttempt(_ value: Int) {
    lock.lock()
    attemptValue = value
    lock.unlock()
  }
}

// MARK: - TaskState helpers

extension TaskState {
  var canCancel: Bool {
    switch self {
    case .pending, .running, .paused:
      return true
    case .completed, .failed, .cancelled:
      return false
    }
  }

  var canPause: Bool {
    switch self {
    case .pending, .running:
      return true
    case .paused, .completed, .failed, .cancelled:
      return false
    }
  }

  var isTerminal: Bool {
    switch self {
    case .completed, .failed, .cancelled:
      return true
    case .pending, .running, .paused:
      return false
    }
  }
}
