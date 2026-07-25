import AuraCore
import Foundation

/// Persistent checkpoint value for a durable task.
///
/// Checkpoints are opaque to AuraTasks; the concrete runner encodes and decodes
/// the `state` dictionary. AuraTasks only guarantees atomic storage and retrieval.
public struct TaskCheckpoint: Codable, Sendable, Equatable {
  /// Task identifier this checkpoint belongs to.
  public let taskID: UUID

  /// Human-readable checkpoint name (e.g. step label).
  public let name: String

  /// Runner-specific serialized state.
  public let state: [String: String]

  /// Monotonic clock at the time the checkpoint was captured.
  public let capturedAt: TimeInterval

  public init(
    taskID: UUID,
    name: String,
    state: [String: String],
    capturedAt: TimeInterval = Date().timeIntervalSince1970
  ) {
    self.taskID = taskID
    self.name = name
    self.state = state
    self.capturedAt = capturedAt
  }
}
