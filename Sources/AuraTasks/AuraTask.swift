import AuraCore
import Foundation

/// Internal aggregate representing a durable task.
///
/// `AuraTask` is not public; callers interact with `TaskStatus` and `TaskRequest`.
final class AuraTask: @unchecked Sendable {
  let id: UUID
  let createdAt: Date
  let priority: TaskPriority
  let objective: String
  let deadline: Date?
  let inactivityTimeoutSeconds: Double
  let maxRetries: Int
  let context: [String: String]

  private var _state: TaskState
  private var _completedSteps: Int
  private var _totalSteps: Int
  private var _currentStepDescription: String
  private var _errorMessage: String?
  private var _updatedAt: Date
  var attemptValue: Int
  private var _latestCheckpointName: String?
  let lock = NSLock()

  var latestCheckpointName: String? {
    get { lock.withLock { _latestCheckpointName } }
    set {
      lock.lock()
      _latestCheckpointName = newValue
      lock.unlock()
    }
  }

  var state: TaskState {
    lock.withLock { _state }
  }

  var completedSteps: Int {
    lock.withLock { _completedSteps }
  }

  var totalSteps: Int {
    lock.withLock { _totalSteps }
  }

  var currentStepDescription: String {
    lock.withLock { _currentStepDescription }
  }

  var errorMessage: String? {
    lock.withLock { _errorMessage }
  }

  var updatedAt: Date {
    lock.withLock { _updatedAt }
  }

  var attempt: Int {
    lock.withLock { attemptValue }
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = Date(),
    priority: TaskPriority,
    objective: String,
    deadline: Date?,
    inactivityTimeoutSeconds: Double,
    maxRetries: Int,
    context: [String: String]
  ) {
    self.id = id
    self.createdAt = createdAt
    self.priority = priority
    self.objective = objective
    self.deadline = deadline
    self.inactivityTimeoutSeconds = inactivityTimeoutSeconds
    self.maxRetries = maxRetries
    self.context = context
    self._state = .pending
    self._completedSteps = 0
    self._totalSteps = 0
    self._currentStepDescription = ""
    self._errorMessage = nil
    self._updatedAt = createdAt
    self.attemptValue = 0
  }

  func transition(to newState: TaskState, error: String? = nil) {
    lock.lock()
    _state = newState
    if let error {
      _errorMessage = error
    }
    _updatedAt = Date()
    lock.unlock()
  }

  func setProgress(completedSteps: Int, totalSteps: Int, currentStepDescription: String) {
    lock.lock()
    _completedSteps = max(0, completedSteps)
    _totalSteps = max(0, totalSteps)
    _currentStepDescription = currentStepDescription
    _updatedAt = Date()
    lock.unlock()
  }

  func incrementAttempt() {
    lock.lock()
    attemptValue += 1
    _updatedAt = Date()
    lock.unlock()
  }

  func statusSnapshot() -> TaskStatus {
    lock.lock()
    defer { lock.unlock() }
    return TaskStatus(
      id: id,
      state: _state,
      objective: objective,
      priority: priority,
      createdAt: createdAt,
      deadline: deadline,
      updatedAt: _updatedAt,
      completedSteps: _completedSteps,
      totalSteps: _totalSteps,
      currentStepDescription: _currentStepDescription,
      errorMessage: _errorMessage
    )
  }

  /// Returns true if the deadline has passed.
  func isExpired(referenceDate: Date = Date()) -> Bool {
    guard let deadline else { return false }
    return referenceDate > deadline
  }
}
