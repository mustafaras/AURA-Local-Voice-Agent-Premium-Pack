import Foundation

/// Configuration for the durable task engine.
public struct TaskConfiguration: Codable, Sendable, Equatable {
  /// Default maximum number of bounded retries for a recoverable task step.
  public var defaultMaxRetries: Int

  /// Seconds of inactivity before a running task is automatically paused.
  public var defaultInactivityTimeoutSeconds: Double

  /// Days to retain checkpoints before they become eligible for eviction.
  public var checkpointRetentionDays: Int

  /// Maximum number of tasks allowed to run concurrently.
  public var maxConcurrentTasks: Int

  /// Maximum number of pending tasks in the queue.
  public var queueCapacity: Int

  public init(
    defaultMaxRetries: Int = 3,
    defaultInactivityTimeoutSeconds: Double = 300.0,
    checkpointRetentionDays: Int = 30,
    maxConcurrentTasks: Int = 3,
    queueCapacity: Int = 100
  ) {
    self.defaultMaxRetries = defaultMaxRetries
    self.defaultInactivityTimeoutSeconds = defaultInactivityTimeoutSeconds
    self.checkpointRetentionDays = checkpointRetentionDays
    self.maxConcurrentTasks = maxConcurrentTasks
    self.queueCapacity = queueCapacity
  }

  public func validate() throws(AuraError) {
    guard defaultMaxRetries >= 0 else {
      throw AuraError.invalidConfiguration("task defaultMaxRetries must be non-negative")
    }
    guard defaultInactivityTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("task defaultInactivityTimeoutSeconds must be positive")
    }
    guard checkpointRetentionDays > 0 else {
      throw AuraError.invalidConfiguration("task checkpointRetentionDays must be positive")
    }
    guard maxConcurrentTasks > 0 else {
      throw AuraError.invalidConfiguration("task maxConcurrentTasks must be positive")
    }
    guard queueCapacity > 0 else {
      throw AuraError.invalidConfiguration("task queueCapacity must be positive")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    defaultMaxRetries = try container.decodeIfPresent(Int.self, forKey: .defaultMaxRetries) ?? 3
    defaultInactivityTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultInactivityTimeoutSeconds) ?? 300.0
    checkpointRetentionDays =
      try container.decodeIfPresent(Int.self, forKey: .checkpointRetentionDays) ?? 30
    maxConcurrentTasks =
      try container.decodeIfPresent(Int.self, forKey: .maxConcurrentTasks) ?? 3
    queueCapacity = try container.decodeIfPresent(Int.self, forKey: .queueCapacity) ?? 100
  }
}
