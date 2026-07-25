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
private actor LineAccumulator {
  private var pending = ""
  private var sequence = 0
  private var totalBytes = 0
  private let maxBytes: Int
  private let maxLines: Int
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
    process.arguments = command.effectiveArguments
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
        argumentCount: command.effectiveArguments.count
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

  /// Run a typed command, yielding output lines as they arrive instead of
  /// buffering all output until the process exits.
  ///
  /// Shares `activeProcesses`/`cancellationRequested` bookkeeping with
  /// `run()`, so the existing `cancel(executionID:)` terminates streaming
  /// runs too. If `command.standardInputText` is set, it is written to the
  /// process's stdin and the pipe is then closed for EOF.
  public func runStreaming(
    _ command: Command,
    executionID: UUID
  ) async -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    let redactor = OutputRedactor(patterns: configuration.redactionPatterns)

    do {
      try command.validate(configuration: configuration)
    } catch {
      return AsyncThrowingStream { continuation in
        continuation.finish(throwing: error)
      }
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: command.executable)
    process.arguments = command.effectiveArguments
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

    var stdinPipe: Pipe?
    if command.standardInputText != nil {
      let pipe = Pipe()
      process.standardInput = pipe
      stdinPipe = pipe
    }

    let startedEnvelope = EventEnvelope<CommandStartedEvent>(
      correlationID: executionID,
      causationID: executionID,
      actor: .automation,
      sensitivity: .internalLevel,
      payload: CommandStartedEvent(
        executionID: executionID,
        executable: command.executable,
        argumentCount: command.effectiveArguments.count
      )
    )
    await AuraEventBus.shared.emit(startedEnvelope)

    do {
      try process.run()
    } catch {
      await emitCompletion(
        executionID: executionID,
        command: command,
        redactor: redactor,
        start: Date(),
        outcome: .failed,
        exitCode: nil,
        stdoutBytes: 0,
        stderrBytes: 0
      )
      let launchError = AuraError.shellError("launch failed: \(error.localizedDescription)")
      return AsyncThrowingStream { continuation in
        continuation.finish(throwing: launchError)
      }
    }

    if let stdinPipe, let text = command.standardInputText {
      if let data = text.data(using: .utf8) {
        stdinPipe.fileHandleForWriting.write(data)
      }
      stdinPipe.fileHandleForWriting.closeFile()
    }

    activeProcesses[executionID] = process
    let start = Date()
    let deadline = start.addingTimeInterval(command.timeoutSeconds)
    let stdoutAccumulator = LineAccumulator(
      maxBytes: configuration.maxOutputBytes, maxLines: configuration.maxOutputLines)
    let stderrAccumulator = LineAccumulator(
      maxBytes: configuration.maxOutputBytes, maxLines: configuration.maxOutputLines)

    return AsyncThrowingStream { continuation in
      stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else {
          handle.readabilityHandler = nil
          Task { await stdoutAccumulator.markEOF() }
          return
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        Task {
          for (line, sequence) in await stdoutAccumulator.append(text) {
            continuation.yield(
              .line(
                ProcessOutputLine(
                  executionID: executionID,
                  stream: .stdout,
                  text: redactor.redact(line),
                  sequence: sequence
                )))
          }
        }
      }
      stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else {
          handle.readabilityHandler = nil
          Task { await stderrAccumulator.markEOF() }
          return
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        Task {
          for (line, sequence) in await stderrAccumulator.append(text) {
            continuation.yield(
              .line(
                ProcessOutputLine(
                  executionID: executionID,
                  stream: .stderr,
                  text: redactor.redact(line),
                  sequence: sequence
                )))
          }
        }
      }

      let watchTask = Task {
        let (wasCancelled, wasTimedOut, wasBoundExceeded) = await self.watchStreamingProcess(
          executionID: executionID,
          process: process,
          deadline: deadline,
          stdoutAccumulator: stdoutAccumulator,
          stderrAccumulator: stderrAccumulator
        )

        // The process exiting does not by itself guarantee every chunk the
        // readability handler already read has finished being parsed into
        // lines (that parsing happens in independently scheduled Tasks).
        // Wait for both streams to reach EOF before reading final state,
        // bounded so a pipe that never signals EOF cannot hang this method.
        for _ in 0..<100 {
          let stdoutEOF = await stdoutAccumulator.reachedEOF
          let stderrEOF = await stderrAccumulator.reachedEOF
          if stdoutEOF && stderrEOF {
            break
          }
          try? await Task.sleep(nanoseconds: 5_000_000)  // 5 ms
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if let remainder = await stdoutAccumulator.flushRemainder() {
          continuation.yield(
            .line(
              ProcessOutputLine(
                executionID: executionID,
                stream: .stdout,
                text: redactor.redact(remainder.line),
                sequence: remainder.sequence
              )))
        }
        if let remainder = await stderrAccumulator.flushRemainder() {
          continuation.yield(
            .line(
              ProcessOutputLine(
                executionID: executionID,
                stream: .stderr,
                text: redactor.redact(remainder.line),
                sequence: remainder.sequence
              )))
        }

        let duration = Date().timeIntervalSince(start)
        let exitCode = Int(process.terminationStatus)
        let stdoutTruncated = await stdoutAccumulator.boundExceeded
        let stderrTruncated = await stderrAccumulator.boundExceeded

        let outcome: CommandCompletedEvent.Outcome
        if wasCancelled {
          outcome = .cancelled
        } else if wasTimedOut {
          outcome = .timedOut
        } else if wasBoundExceeded {
          outcome = .failed
        } else if command.expectedExitCodes.contains(exitCode) {
          outcome = .succeeded
        } else {
          outcome = .failed
        }

        await self.emitCompletion(
          executionID: executionID,
          command: command,
          redactor: redactor,
          start: start,
          outcome: outcome,
          exitCode: exitCode,
          stdoutBytes: 0,
          stderrBytes: 0
        )

        if wasCancelled {
          continuation.finish(throwing: AuraError.shellError("cancelled"))
          return
        }
        if wasTimedOut {
          continuation.finish(
            throwing: AuraError.shellError("timed out after \(command.timeoutSeconds) seconds"))
          return
        }

        continuation.yield(
          .completed(
            ProcessResult(
              executionID: executionID,
              exitCode: exitCode,
              stdout: "",
              stderr: "",
              durationSeconds: duration,
              wasCancelled: false,
              wasTimedOut: false,
              stdoutTruncated: stdoutTruncated,
              stderrTruncated: stderrTruncated
            )))
        continuation.finish()
      }

      continuation.onTermination = { @Sendable _ in
        watchTask.cancel()
        Task { await self.cancel(executionID: executionID) }
      }
    }
  }

  /// Poll loop shared by `runStreaming`, mirroring `run()`'s deadline and
  /// cancellation semantics, plus early termination on output-bound overrun
  /// (necessary because a streaming run may otherwise never exit on its own).
  private func watchStreamingProcess(
    executionID: UUID,
    process: Process,
    deadline: Date,
    stdoutAccumulator: LineAccumulator,
    stderrAccumulator: LineAccumulator
  ) async -> (wasCancelled: Bool, wasTimedOut: Bool, wasBoundExceeded: Bool) {
    var wasCancelled = false
    var wasTimedOut = false
    var wasBoundExceeded = false

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
      let stdoutBoundExceeded = await stdoutAccumulator.boundExceeded
      let stderrBoundExceeded = await stderrAccumulator.boundExceeded
      if stdoutBoundExceeded || stderrBoundExceeded {
        wasBoundExceeded = true
        process.terminate()
        process.waitUntilExit()
        break
      }
      try? await Task.sleep(nanoseconds: 20_000_000)  // 20 ms
    }

    if cancellationRequested.contains(executionID) {
      wasCancelled = true
    }
    cancellationRequested.remove(executionID)
    activeProcesses.removeValue(forKey: executionID)

    return (wasCancelled, wasTimedOut, wasBoundExceeded)
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
