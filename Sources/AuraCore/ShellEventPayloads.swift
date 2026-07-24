import Foundation

// MARK: - Shell command lifecycle event payloads

/// Emitted when a typed shell command starts execution.
public struct CommandStartedEvent: EventPayload {
  public static let eventType = "shell.command.started"

  /// Correlation ID of the command execution.
  public let executionID: UUID

  /// Executable path that was invoked.
  public let executable: String

  /// Count of arguments; arguments themselves are omitted from the event.
  public let argumentCount: Int

  /// Monotonic timestamp of the start.
  public let startedAt: TimeInterval

  public init(
    executionID: UUID,
    executable: String,
    argumentCount: Int,
    startedAt: TimeInterval = Date().timeIntervalSince1970
  ) {
    self.executionID = executionID
    self.executable = executable
    self.argumentCount = argumentCount
    self.startedAt = startedAt
  }
}

/// Emitted when a typed shell command finishes.
public struct CommandCompletedEvent: EventPayload {
  public static let eventType = "shell.command.completed"

  public enum Outcome: String, Codable, Sendable, Equatable {
    case succeeded
    case failed
    case timedOut
    case cancelled
  }

  public let executionID: UUID
  public let outcome: Outcome
  public let exitCode: Int?
  public let durationSeconds: Double
  public let stdoutByteCount: Int
  public let stderrByteCount: Int
  public let redacted: Bool

  public init(
    executionID: UUID,
    outcome: Outcome,
    exitCode: Int? = nil,
    durationSeconds: Double,
    stdoutByteCount: Int,
    stderrByteCount: Int,
    redacted: Bool
  ) {
    self.executionID = executionID
    self.outcome = outcome
    self.exitCode = exitCode
    self.durationSeconds = durationSeconds
    self.stdoutByteCount = stdoutByteCount
    self.stderrByteCount = stderrByteCount
    self.redacted = redacted
  }
}

/// Emitted for a chunk of command output. Secrets must be redacted before emission.
public struct CommandOutputEvent: EventPayload {
  public static let eventType = "shell.command.output"

  public enum Stream: String, Codable, Sendable, Equatable {
    case stdout
    case stderr
  }

  public let executionID: UUID
  public let stream: Stream
  public let text: String
  public let isComplete: Bool
  public let truncated: Bool

  public init(
    executionID: UUID,
    stream: Stream,
    text: String,
    isComplete: Bool,
    truncated: Bool
  ) {
    self.executionID = executionID
    self.stream = stream
    self.text = text
    self.isComplete = isComplete
    self.truncated = truncated
  }
}

/// Emitted when a command is explicitly cancelled by the caller.
public struct CommandCancelledEvent: EventPayload {
  public static let eventType = "shell.command.cancelled"

  public let executionID: UUID
  public let cancelledAt: TimeInterval

  public init(
    executionID: UUID,
    cancelledAt: TimeInterval = Date().timeIntervalSince1970
  ) {
    self.executionID = executionID
    self.cancelledAt = cancelledAt
  }
}
