import Foundation

/// Priority queue of `AuraTask` instances ordered by `TaskPriority` and FIFO within the same priority.
import AuraCore

struct TaskQueue {
  private var storage: [AuraTask] = []
  private let capacity: Int
  private let lock = NSLock()

  init(capacity: Int) {
    self.capacity = capacity
  }

  var count: Int {
    lock.withLock { storage.count }
  }

  var isFull: Bool {
    lock.withLock { storage.count >= capacity }
  }

  /// Inserts a task if capacity allows. Returns true on success.
  @discardableResult
  mutating func enqueue(_ task: AuraTask) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard storage.count < capacity else { return false }
    storage.append(task)
    storage.sort { lhs, rhs in
      if lhs.priority.rawValue != rhs.priority.rawValue {
        return lhs.priority.rawValue > rhs.priority.rawValue
      }
      return lhs.createdAt < rhs.createdAt
    }
    return true
  }

  /// Removes and returns the highest-priority task, if any.
  mutating func dequeue() -> AuraTask? {
    lock.lock()
    defer { lock.unlock() }
    guard !storage.isEmpty else { return nil }
    return storage.removeFirst()
  }

  /// Removes the task with the given ID from the queue. Returns true if it was present.
  @discardableResult
  mutating func remove(id: UUID) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    let before = storage.count
    storage.removeAll { $0.id == id }
    return storage.count < before
  }

  func contains(id: UUID) -> Bool {
    lock.withLock { storage.contains { $0.id == id } }
  }

  func allStatuses() -> [TaskStatus] {
    lock.withLock { storage.map { $0.statusSnapshot() } }
  }
}
