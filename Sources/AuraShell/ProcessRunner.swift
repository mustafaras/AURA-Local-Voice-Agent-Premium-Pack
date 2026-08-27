import AuraCore
import Foundation

/// Typed result of a process invocation.
public struct ProcessResult: Sendable, Equatable, Codable {
  public let executionID: UUID
  public let exitCode: Int
  public let stdout: String
  public let stderr: String
  public let durationSeconds: Double
  public let wasCancelled: Bool
  public let wasTimedOut: Bool
  public let stdoutTruncated: Bool
  public let stderrTruncated: Bool

  public init(
    executionID: UUID,
    exitCode: Int,
    stdout: String,
    stderr: String,
    durationSeconds: Double,
    wasCancelled: Bool,
    wasTimedOut: Bool,
    stdoutTruncated: Bool,
    stderrTruncated: Bool
  ) {
    self.executionID = executionID
    self.exitCode = exitCode
    self.stdout = stdout
    self.stderr = stderr
    self.durationSeconds = durationSeconds
    self.wasCancelled = wasCancelled
    self.wasTimedOut = wasTimedOut
    self.stdoutTruncated = stdoutTruncated
    self.stderrTruncated = stderrTruncated
  }
}

/// Process execution error details emitted as ledger context.
public struct ProcessFailure: Sendable, Equatable {
  public enum Reason: String, Sendable, Equatable {
    case launchFailed
    case timedOut
    case cancelled
    case unexpectedExitCode
    case encodingFailure
    case outputBoundsExceeded
  }

  public let reason: Reason
  public let underlyingErrorDescription: String

  public init(reason: Reason, underlyingErrorDescription: String) {
    self.reason = reason
    self.underlyingErrorDescription = underlyingErrorDescription
  }
}

/// Which standard stream a `ProcessOutputLine` was read from.
public enum ProcessOutputStream: String, Sendable, Equatable {
  case stdout
  case stderr
}

/// A single line of output observed while a process is running.
public struct ProcessOutputLine: Sendable, Equatable {
  public let executionID: UUID
  public let stream: ProcessOutputStream
  public let text: String
  public let sequence: Int
  public let timestamp: Date

  public init(
    executionID: UUID,
    stream: ProcessOutputStream,
    text: String,
    sequence: Int,
    timestamp: Date = Date()
  ) {
    self.executionID = executionID
    self.stream = stream
    self.text = text
    self.sequence = sequence
    self.timestamp = timestamp
  }
}

/// An element of a streaming process execution.
public enum ProcessStreamEvent: Sendable {
  /// A single, redacted, newline-delimited line of stdout or stderr.
  case line(ProcessOutputLine)
  /// The terminal result. `stdout`/`stderr` are empty — streaming callers
  /// already received every line via `.line`; buffering the full output a
  /// second time would defeat the purpose of streaming.
  case completed(ProcessResult)
}

/// Accumulates raw bytes into complete, newline-terminated lines while
/// enforcing an output bound.
///
/// A separate actor (not `ProcessRunner` itself) because `readabilityHandler`
/// closures run on arbitrary GCD threads, not on `ProcessRunner`'s executor.
actor LineAccumulator {
  var pending = ""
  var sequence = 0
  var totalBytes = 0
  let maxBytes: Int
  let maxLines: Int
  private(set) var boundExceeded = false

  /// Set once the readability handler observes EOF (empty `availableData`).
  /// Callers must wait for this before reading final state — `Process`'s
  /// `isRunning` becoming `false` does not by itself guarantee every prior
  /// `append(_:)` call spawned from the handler has finished executing.
  private(set) var reachedEOF = false

  init(maxBytes: Int, maxLines: Int) {
    self.maxBytes = maxBytes
    self.maxLines = maxLines
  }

  func markEOF() {
    reachedEOF = true
  }

  /// Append a chunk of raw text, returning any newly completed lines.
  /// Stops accumulating once the configured output bound is exceeded.
  func append(_ text: String) -> [(line: String, sequence: Int)] {
    guard !boundExceeded else { return [] }
    totalBytes += text.utf8.count
    pending += text
    var completed: [(line: String, sequence: Int)] = []
    while let range = pending.range(of: "\n") {
      let line = String(pending[pending.startIndex..<range.lowerBound])
      pending.removeSubrange(pending.startIndex..<range.upperBound)
      sequence += 1
      completed.append((line, sequence))
      if sequence >= maxLines || totalBytes > maxBytes {
        boundExceeded = true
        pending = ""
        break
      }
    }
    return completed
  }

  /// Flush a trailing, non-newline-terminated partial line (e.g. at EOF).
  func flushRemainder() -> (line: String, sequence: Int)? {
    guard !boundExceeded, !pending.isEmpty else { return nil }
    defer { pending = "" }
    sequence += 1
    return (pending, sequence)
  }
}

/// Executes typed `Command` values with policy, timeout, cancellation,
/// output bounds, and redaction.
public actor ProcessRunner {
  let configuration: ShellConfiguration
  var activeProcesses: [UUID: Process] = [:]
  var cancellationRequested: Set<UUID> = []

  public init(configuration: ShellConfiguration) {
    self.configuration = configuration
  }

}
