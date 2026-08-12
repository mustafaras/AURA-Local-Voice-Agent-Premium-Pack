import AuraCore
import AuraStore
import Foundation

extension AuraTaskEngine {
  // MARK: - Queue pumping

  func pumpQueue(runner: TaskRunner) {
    // Avoid creating too many concurrent tasks; this is a simple FIFO-with-priority pump.
    // Each call pulls one task and runs it; when it finishes, it pumps again.
    Task {
      await pumpQueueAsync(runner: runner)
    }
  }

  func pumpQueueAsync(runner: TaskRunner) async {
    guard !shutdown else { return }
    guard activeRunners.count < configuration.maxConcurrentTasks else { return }

    guard let task = queue.dequeue() else { return }
    let taskID = task.id
    activeRunners[taskID] = Task {
      await self.run(task: task, runner: runner)
      // Ensure the task record is removed before the next pump so the
      // engine never over-counts active slots.
      self.activeRunners.removeValue(forKey: taskID)
      self.pumpQueue(runner: runner)
    }
  }
}
