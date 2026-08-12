import AuraCore
import AuraStore
import Foundation

extension AuraTaskEngine {
  // MARK: - Recovery

  /// Loads previously persisted tasks and re-enqueues those that can resume.
  ///
  /// Must be called before `start()` to guarantee crash-recovery semantics.
  public func recoverState() async throws(AuraError) {
    guard !recoveryCompleted else { return }
    let ids = try await storeBackend.indexEntries()
    for id in ids {
      guard let snapshot = try await storeBackend.loadTaskSnapshot(id: id) else {
        // Stale index entry; remove it.
        try await storeBackend.removeTaskSnapshot(id: id)
        continue
      }
      guard let task = AuraTask.from(snapshot: snapshot) else { continue }

      // Terminal states are remembered but not re-queued.
      switch snapshot.state {
      case .pending, .running:
        tasksByID[task.id] = task
        _ = queue.enqueue(task)
      // Running tasks were interrupted; treat as pending for retry.
      case .paused:
        tasksByID[task.id] = task
      case .completed, .failed, .cancelled:
        tasksByID[task.id] = task
      }
    }
    recoveryCompleted = true
  }
}
