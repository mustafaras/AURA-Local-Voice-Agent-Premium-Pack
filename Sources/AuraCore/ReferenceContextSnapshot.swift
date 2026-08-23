import Foundation

/// Typed, dependency-neutral live state supplied by the composition root to
/// the intent/context path. `AuraContext` consumes this data but never reaches
/// into tasks, automation, VS Code, or agent backends itself.
public struct ReferenceContextSnapshot: Sendable, Equatable {
  public let activeWorkspace: ActiveWorkspaceSnapshot?
  public let durableTasks: [TaskStatus]

  public init(
    activeWorkspace: ActiveWorkspaceSnapshot? = nil,
    durableTasks: [TaskStatus] = []
  ) {
    self.activeWorkspace = activeWorkspace
    self.durableTasks = durableTasks
  }

  public static let empty = ReferenceContextSnapshot()
}
