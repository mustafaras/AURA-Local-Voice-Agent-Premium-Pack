import AuraCore
import AuraStore
import Foundation

/// Persistence facade used by the task engine.
///
/// All keys are namespaced to avoid colliding with other subsystems that use
/// `AuraStore` key-value storage.
public actor TaskStoreBackend {
  private let store: AuraStore
  private let jsonEncoder: JSONEncoder
  private let jsonDecoder: JSONDecoder

  private static let taskPrefix = "aura:task:"
  private static let checkpointPrefix = "aura:task:checkpoint:"
  private static let indexKey = "aura:task:index"

  public init(store: AuraStore) async {
    self.store = store
    self.jsonEncoder = JSONEncoder()
    self.jsonEncoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder.outputFormatting = .sortedKeys
    self.jsonDecoder = JSONDecoder()
    self.jsonDecoder.dateDecodingStrategy = .iso8601
  }

  private func taskKey(id: UUID) -> String {
    "\(Self.taskPrefix)\(id.uuidString)"
  }

  private func checkpointKey(taskID: UUID, name: String) -> String {
    "\(Self.checkpointPrefix)\(taskID.uuidString):\(name)"
  }

  /// Persist the serialized snapshot of a task.
  public func saveTaskSnapshot(_ snapshot: TaskSnapshot) async throws(AuraError) {
    let data: Data
    do {
      data = try jsonEncoder.encode(snapshot)
    } catch {
      throw AuraError.serializationError(
        "Failed to encode task snapshot: \(error.localizedDescription)")
    }
    let id = snapshot.id
    try await store.setValue(String(data: data, encoding: .utf8) ?? "", forKey: taskKey(id: id))
    try await addToIndex(id: id)
  }

  /// Load the serialized snapshot for a task, if any.
  public func loadTaskSnapshot(id: UUID) async throws(AuraError) -> TaskSnapshot? {
    guard let json = try await store.value(forKey: taskKey(id: id)) else {
      return nil
    }
    guard let data = json.data(using: .utf8) else {
      throw AuraError.serializationError("Task snapshot is not valid UTF-8")
    }
    do {
      return try jsonDecoder.decode(TaskSnapshot.self, from: data)
    } catch {
      throw AuraError.serializationError(
        "Failed to decode task snapshot: \(error.localizedDescription)")
    }
  }

  /// Remove a task snapshot and its index entry.
  public func removeTaskSnapshot(id: UUID) async throws(AuraError) {
    try await store.removeValue(forKey: taskKey(id: id))
    try await removeFromIndex(id: id)
  }

  /// Persist a checkpoint value.
  public func saveCheckpoint(_ checkpoint: TaskCheckpoint) async throws(AuraError) {
    let data: Data
    do {
      data = try jsonEncoder.encode(checkpoint)
    } catch {
      throw AuraError.serializationError(
        "Failed to encode checkpoint: \(error.localizedDescription)")
    }
    let key = checkpointKey(taskID: checkpoint.taskID, name: checkpoint.name)
    try await store.setValue(String(data: data, encoding: .utf8) ?? "", forKey: key)
  }

  /// Load the latest checkpoint for a task, if any.
  public func loadLatestCheckpoint(taskID: UUID) async throws(AuraError) -> TaskCheckpoint? {
    guard let snapshot = try await loadTaskSnapshot(id: taskID),
      let name = snapshot.latestCheckpointName,
      !name.isEmpty
    else {
      return nil
    }
    return try await loadCheckpoint(taskID: taskID, name: name)
  }

  /// Load a named checkpoint for a task.
  public func loadCheckpoint(taskID: UUID, name: String) async throws(AuraError) -> TaskCheckpoint?
  {
    guard let json = try await store.value(forKey: checkpointKey(taskID: taskID, name: name)) else {
      return nil
    }
    guard let data = json.data(using: .utf8) else {
      throw AuraError.serializationError("Checkpoint is not valid UTF-8")
    }
    do {
      return try jsonDecoder.decode(TaskCheckpoint.self, from: data)
    } catch {
      throw AuraError.serializationError(
        "Failed to decode checkpoint: \(error.localizedDescription)")
    }
  }

  /// Read all tracked task IDs from the index.
  public func indexEntries() async throws(AuraError) -> [UUID] {
    guard let json = try await store.value(forKey: Self.indexKey) else {
      return []
    }
    guard let data = json.data(using: .utf8) else {
      throw AuraError.serializationError("Task index is not valid UTF-8")
    }
    do {
      let strings = try jsonDecoder.decode([String].self, from: data)
      return strings.compactMap(UUID.init(uuidString:))
    } catch {
      throw AuraError.serializationError(
        "Failed to decode task index: \(error.localizedDescription)")
    }
  }

  private func addToIndex(id: UUID) async throws(AuraError) {
    var entries = try await indexEntries()
    if !entries.contains(id) {
      entries.append(id)
    }
    try await saveIndex(entries)
  }

  private func removeFromIndex(id: UUID) async throws(AuraError) {
    var entries = try await indexEntries()
    entries.removeAll { $0 == id }
    try await saveIndex(entries)
  }

  private func saveIndex(_ entries: [UUID]) async throws(AuraError) {
    let strings = entries.map { $0.uuidString }
    let data: Data
    do {
      data = try jsonEncoder.encode(strings)
    } catch {
      throw AuraError.serializationError(
        "Failed to encode task index: \(error.localizedDescription)")
    }
    try await store.setValue(String(data: data, encoding: .utf8) ?? "", forKey: Self.indexKey)
  }
}

/// Serializable frozen snapshot of a task used for persistence and recovery.
public struct TaskSnapshot: Codable, Sendable, Equatable {
  public let id: UUID
  public let state: TaskState
  public let priority: TaskPriority
  public let objective: String
  public let deadline: Date?
  public let createdAt: Date
  public let updatedAt: Date
  public let completedSteps: Int
  public let totalSteps: Int
  public let currentStepDescription: String
  public let errorMessage: String?
  public let inactivityTimeoutSeconds: Double
  public let maxRetries: Int
  public let attempt: Int
  public let context: [String: String]
  public let latestCheckpointName: String?

  public init(
    id: UUID,
    state: TaskState,
    priority: TaskPriority,
    objective: String,
    deadline: Date?,
    createdAt: Date,
    updatedAt: Date,
    completedSteps: Int,
    totalSteps: Int,
    currentStepDescription: String,
    errorMessage: String?,
    inactivityTimeoutSeconds: Double,
    maxRetries: Int,
    attempt: Int,
    context: [String: String],
    latestCheckpointName: String? = nil
  ) {
    self.id = id
    self.state = state
    self.priority = priority
    self.objective = objective
    self.deadline = deadline
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.completedSteps = completedSteps
    self.totalSteps = totalSteps
    self.currentStepDescription = currentStepDescription
    self.errorMessage = errorMessage
    self.inactivityTimeoutSeconds = inactivityTimeoutSeconds
    self.maxRetries = maxRetries
    self.attempt = attempt
    self.context = context
    self.latestCheckpointName = latestCheckpointName
  }
}
