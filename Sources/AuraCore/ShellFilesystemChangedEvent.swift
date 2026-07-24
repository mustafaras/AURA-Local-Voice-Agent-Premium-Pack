import Foundation

/// Emitted when filesystem evidence paths change as the result of a shell command.
public struct ShellFilesystemChangedEvent: EventPayload {
  public static let eventType = "shell.filesystem.changed"

  public let executionID: UUID
  public let path: String
  public let diffDigest: String
  public let added: [String]
  public let removed: [String]
  public let modified: [String]

  public init(
    executionID: UUID,
    path: String,
    diffDigest: String,
    added: [String] = [],
    removed: [String] = [],
    modified: [String] = []
  ) {
    self.executionID = executionID
    self.path = path
    self.diffDigest = diffDigest
    self.added = added
    self.removed = removed
    self.modified = modified
  }
}
