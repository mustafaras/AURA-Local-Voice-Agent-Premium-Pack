import Foundation

// MARK: - Scope

/// Project/task/session scoping for a memory record, per the "project and
/// task scope" field in the memory record schema.
public struct MemoryScope: Codable, Sendable, Equatable {
  public let projectID: String?
  public let taskID: UUID?
  public let sessionID: UUID?

  public init(projectID: String? = nil, taskID: UUID? = nil, sessionID: UUID? = nil) {
    self.projectID = projectID
    self.taskID = taskID
    self.sessionID = sessionID
  }

  /// No project/task/session scoping — visible regardless of scope filter.
  public static let global = MemoryScope()
}
