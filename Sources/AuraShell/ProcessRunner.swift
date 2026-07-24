import AuraCore
import Foundation

/// Typed result of a process invocation.
public struct ProcessResult: Sendable, Equatable {
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

/// Executes typed `Command` values with policy, timeout, cancellation,
/// output bounds, and redaction.
public actor ProcessRunner {
  private let configuration: ShellConfiguration
  private var activeProcesses: [UUID: Process] = [:]
  private var cancellationRequested: Set<UUID> = []

  public init(configuration: ShellConfiguration) {
    self.configuration = configuration
  }

  /// Run a typed command and return a typed result.
  ///
  /// - Parameters:
  ///   - command: the typed command to execute.
  ///   - executionID: explicit correlation/execution identifier. Callers such
  ///     as `AuraShell` should pass their own correlation ID so that external
  ///     cancellation can target the in-flight run.
  public func run(
    _ command: Command,
    executionID: UUID
  ) async -> Result<ProcessResult, AuraError> {
    let start = Date()
    let redactor = OutputRedactor(patterns: configuration.redactionPatterns)

    do {
      try command.validate(configuration: configuration)
    } catch {
      return .failure(error)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: command.executable)
    process.arguments = command.arguments
    if let cwd = command.workingDirectory {
      process.currentDirectoryURL = URL(fileURLWithPath: cwd)
    }
    process.environment = Self.mergeEnvironment(
      commandEnvironment: command.environment,
      allowedKeys: configuration.allowedEnvironmentKeys
    )

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let startedEnvelope = EventEnvelope<CommandStartedEvent>(
      correlationID: executionID,
      causationID: executionID,
      actor: .automation,
      sensitivity: .internalLevel,
      payload: CommandStartedEvent(
        executionID: executionID,
        executable: command.executable,
        argumentCount: command.arguments.count
      )
    )
    await AuraEventBus.shared.emit(startedEnvelope)

    do {
      try process.run()
    } catch {
      let failure = ProcessFailure(
        reason: .launchFailed,
        underlyingErrorDescription: error.localizedDescription
      )
      await emitCompletion(
        executionID: executionID,
        command: command,
        redactor: redactor,
        start: start,
        outcome: .failed,
        exitCode: nil,
        stdoutBytes: 0,
        stderrBytes: 0
      )
      return .failure(AuraError.shellError("launch failed: \(failure.underlyingErrorDescription)"))
    }

    let deadline = Date().addingTimeInterval(command.timeoutSeconds)
    var wasCancelled = false
    var wasTimedOut = false

    activeProcesses[executionID] = process

    while process.isRunning {
      if Task.isCancelled || cancellationRequested.contains(executionID) {
        wasCancelled = true
        process.terminate()
        process.waitUntilExit()
        break
      }
      if Date() >= deadline {
        wasTimedOut = true
        process.terminate()
        process.waitUntilExit()
        break
      }
      try? await Task.sleep(nanoseconds: 20_000_000)  // 20 ms
    }

    // If the process exited because of an external cancel() call that raced
    // past the loop check, mark the run as cancelled now that it is complete.
    if cancellationRequested.contains(executionID) {
      wasCancelled = true
    }

    cancellationRequested.remove(executionID)
    activeProcesses.removeValue(forKey: executionID)

    let duration = Date().timeIntervalSince(start)
    let exitCode = Int(process.terminationStatus)

    let (stdoutRaw, stdoutTruncated) = collectAndBound(
      pipe: stdoutPipe,
      maxBytes: configuration.maxOutputBytes,
      maxLines: configuration.maxOutputLines
    )
    let (stderrRaw, stderrTruncated) = collectAndBound(
      pipe: stderrPipe,
      maxBytes: configuration.maxOutputBytes,
      maxLines: configuration.maxOutputLines
    )

    let stdout = redactor.redact(stdoutRaw)
    let stderr = redactor.redact(stderrRaw)

    await emitOutputEvents(
      executionID: executionID,
      stdout: stdout,
      stderr: stderr,
      stdoutTruncated: stdoutTruncated,
      stderrTruncated: stderrTruncated,
      redactor: redactor
    )

    let outcome: CommandCompletedEvent.Outcome
    if wasCancelled {
      outcome = .cancelled
    } else if wasTimedOut {
      outcome = .timedOut
    } else if command.expectedExitCodes.contains(exitCode) {
      outcome = .succeeded
    } else {
      outcome = .failed
    }

    await emitCompletion(
      executionID: executionID,
      command: command,
      redactor: redactor,
      start: start,
      outcome: outcome,
      exitCode: exitCode,
      stdoutBytes: stdoutRaw.utf8.count,
      stderrBytes: stderrRaw.utf8.count
    )

    if wasCancelled {
      return .failure(AuraError.shellError("cancelled"))
    }
    if wasTimedOut {
      return .failure(AuraError.shellError("timed out after \(command.timeoutSeconds) seconds"))
    }

    let result = ProcessResult(
      executionID: executionID,
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      durationSeconds: duration,
      wasCancelled: false,
      wasTimedOut: false,
      stdoutTruncated: stdoutTruncated,
      stderrTruncated: stderrTruncated
    )
    return .success(result)
  }

  /// Cancel an in-flight command by execution ID.
  public func cancel(executionID: UUID) async {
    cancellationRequested.insert(executionID)
    activeProcesses[executionID]?.terminate()
    // Yield so the termination signal has a chance to land before the
    // caller checks the result synchronously.
    try? await Task.sleep(nanoseconds: 10_000_000)
  }

  // MARK: - Helpers

  private static func mergeEnvironment(
    commandEnvironment: [String: String],
    allowedKeys: Set<String>
  ) -> [String: String]? {
    var merged = ProcessInfo.processInfo.environment
    for (key, value) in commandEnvironment where allowedKeys.contains(key) {
      merged[key] = value
    }
    return merged
  }

  private func collectAndBound(
    pipe: Pipe,
    maxBytes: Int,
    maxLines: Int
  ) -> (text: String, truncated: Bool) {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    var text = String(data: data, encoding: .utf8) ?? ""
    var truncated = false

    let lines = text.components(separatedBy: "\n")
    if lines.count > maxLines {
      text = lines.prefix(maxLines).joined(separator: "\n") + "\n"
      truncated = true
    }
    if text.utf8.count > maxBytes {
      let maxIndex =
        text.index(text.startIndex, offsetBy: maxBytes, limitedBy: text.endIndex)
        ?? text.endIndex
      text = String(text[..<maxIndex])
      truncated = true
    }
    return (text, truncated)
  }

  private func emitOutputEvents(
    executionID: UUID,
    stdout: String,
    stderr: String,
    stdoutTruncated: Bool,
    stderrTruncated: Bool,
    redactor: OutputRedactor
  ) async {
    let redactedStdout = redactor.redact(stdout)
    let redactedStderr = redactor.redact(stderr)

    let stdoutPayload = CommandOutputEvent(
      executionID: executionID,
      stream: .stdout,
      text: redactedStdout,
      isComplete: true,
      truncated: stdoutTruncated
    )
    let stderrPayload = CommandOutputEvent(
      executionID: executionID,
      stream: .stderr,
      text: redactedStderr,
      isComplete: true,
      truncated: stderrTruncated
    )
    let stdoutEnvelope = EventEnvelope<CommandOutputEvent>(
      correlationID: executionID,
      causationID: executionID,
      actor: .automation,
      sensitivity: .internalLevel,
      payload: stdoutPayload
    )
    let stderrEnvelope = EventEnvelope<CommandOutputEvent>(
      correlationID: executionID,
      causationID: executionID,
      actor: .automation,
      sensitivity: .internalLevel,
      payload: stderrPayload
    )
    await AuraEventBus.shared.emit(stdoutEnvelope)
    await AuraEventBus.shared.emit(stderrEnvelope)
  }

  private func emitCompletion(
    executionID: UUID,
    command: Command,
    redactor: OutputRedactor,
    start: Date,
    outcome: CommandCompletedEvent.Outcome,
    exitCode: Int?,
    stdoutBytes: Int,
    stderrBytes: Int
  ) async {
    let payload = CommandCompletedEvent(
      executionID: executionID,
      outcome: outcome,
      exitCode: exitCode,
      durationSeconds: Date().timeIntervalSince(start),
      stdoutByteCount: stdoutBytes,
      stderrByteCount: stderrBytes,
      redacted: !redactor.rules.isEmpty
    )
    let envelope = EventEnvelope<CommandCompletedEvent>(
      correlationID: executionID,
      causationID: executionID,
      actor: .automation,
      sensitivity: .internalLevel,
      payload: payload
    )
    await AuraEventBus.shared.emit(envelope)
  }
}
