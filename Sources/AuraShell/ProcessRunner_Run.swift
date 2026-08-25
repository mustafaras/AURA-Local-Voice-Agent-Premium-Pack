import AuraCore
import Foundation

private struct BufferedProcessWaitResult {
  let wasCancelled: Bool
  let wasTimedOut: Bool
}

private struct BufferedProcessFinalizationContext {
  let process: Process
  let stdoutPipe: Pipe
  let stderrPipe: Pipe
  let command: Command
  let executionID: UUID
  let start: Date
  let redactor: OutputRedactor
  let waitResult: BufferedProcessWaitResult
}

private struct BufferedProcessLaunchContext {
  let process: Process
  let stdoutPipe: Pipe
  let stderrPipe: Pipe
}

extension ProcessRunner {
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

    guard
      let launch = await launchBufferedProcess(
        command, executionID: executionID, redactor: redactor, start: start)
    else {
      return .failure(AuraError.shellError("buffered process launch failed"))
    }
    let process = launch.process

    activeProcesses[executionID] = process
    let waitResult = await waitForProcess(process, executionID: executionID, command: command)
    return await finalizeBufferedProcess(
      BufferedProcessFinalizationContext(
        process: process,
        stdoutPipe: launch.stdoutPipe,
        stderrPipe: launch.stderrPipe,
        command: command,
        executionID: executionID,
        start: start,
        redactor: redactor,
        waitResult: waitResult))
  }

  private func launchBufferedProcess(
    _ command: Command,
    executionID: UUID,
    redactor: OutputRedactor,
    start: Date
  ) async -> BufferedProcessLaunchContext? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command.executable)
    process.arguments = command.effectiveArguments
    if let cwd = command.workingDirectory {
      process.currentDirectoryURL = URL(fileURLWithPath: cwd)
    }
    process.environment = Self.mergeEnvironment(
      commandEnvironment: command.environment, allowedKeys: configuration.allowedEnvironmentKeys)
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    // Always give the child a closed stdin pipe. Without this, the child
    // inherits the parent's stdin (a pipe held open by the test runner or
    // app), so a CLI that waits for stdin EOF (e.g. `claude --help`) never
    // sees EOF and hangs. When `standardInputText` is set, write it first.
    let inputPipe = Pipe()
    process.standardInput = inputPipe
    if let text = command.standardInputText, let data = text.data(using: .utf8) {
      inputPipe.fileHandleForWriting.write(data)
    }
    inputPipe.fileHandleForWriting.closeFile()
    await AuraEventBus.shared.emit(
      EventEnvelope(
        correlationID: executionID, causationID: executionID, actor: .automation,
        sensitivity: .internalLevel,
        payload: CommandStartedEvent(
          executionID: executionID, executable: command.executable,
          argumentCount: command.effectiveArguments.count)))
    do {
      try process.run()
      return BufferedProcessLaunchContext(
        process: process, stdoutPipe: stdoutPipe, stderrPipe: stderrPipe)
    } catch {
      await emitCompletion(
        ProcessCompletionInput(
          executionID: executionID, redactor: redactor, start: start, outcome: .failed,
          exitCode: nil, stdoutBytes: 0, stderrBytes: 0))
      return nil
    }
  }

  private func waitForProcess(
    _ process: Process,
    executionID: UUID,
    command: Command
  ) async -> BufferedProcessWaitResult {
    let deadline = Date().addingTimeInterval(command.timeoutSeconds)
    var wasCancelled = false
    var wasTimedOut = false
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
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
    if cancellationRequested.contains(executionID) {
      wasCancelled = true
    }
    return BufferedProcessWaitResult(wasCancelled: wasCancelled, wasTimedOut: wasTimedOut)
  }

  private func finalizeBufferedProcess(
    _ context: BufferedProcessFinalizationContext
  ) async -> Result<ProcessResult, AuraError> {
    cancellationRequested.remove(context.executionID)
    activeProcesses.removeValue(forKey: context.executionID)
    let duration = Date().timeIntervalSince(context.start)
    let exitCode = Int(context.process.terminationStatus)
    let (stdoutRaw, stdoutTruncated) = collectAndBound(
      pipe: context.stdoutPipe,
      maxBytes: configuration.maxOutputBytes,
      maxLines: configuration.maxOutputLines)
    let (stderrRaw, stderrTruncated) = collectAndBound(
      pipe: context.stderrPipe,
      maxBytes: configuration.maxOutputBytes,
      maxLines: configuration.maxOutputLines)
    let stdout = context.redactor.redact(stdoutRaw)
    let stderr = context.redactor.redact(stderrRaw)
    await emitOutputEvents(
      ProcessOutputEventInput(
        executionID: context.executionID,
        stdout: stdout,
        stderr: stderr,
        stdoutTruncated: stdoutTruncated,
        stderrTruncated: stderrTruncated,
        redactor: context.redactor))
    let outcome: CommandCompletedEvent.Outcome =
      context.waitResult.wasCancelled
      ? .cancelled
      : context.waitResult.wasTimedOut
        ? .timedOut
        : context.command.expectedExitCodes.contains(exitCode) ? .succeeded : .failed
    await emitCompletion(
      ProcessCompletionInput(
        executionID: context.executionID,
        redactor: context.redactor,
        start: context.start,
        outcome: outcome,
        exitCode: exitCode,
        stdoutBytes: stdoutRaw.utf8.count,
        stderrBytes: stderrRaw.utf8.count))
    if context.waitResult.wasCancelled {
      return .failure(AuraError.shellError("cancelled"))
    }
    if context.waitResult.wasTimedOut {
      return .failure(
        AuraError.shellError("timed out after \(context.command.timeoutSeconds) seconds"))
    }
    return .success(
      ProcessResult(
        executionID: context.executionID, exitCode: exitCode, stdout: stdout, stderr: stderr,
        durationSeconds: duration, wasCancelled: false, wasTimedOut: false,
        stdoutTruncated: stdoutTruncated, stderrTruncated: stderrTruncated))
  }

  /// Run a typed command, yielding output lines as they arrive instead of
  /// buffering all output until the process exits.
  ///
  /// Shares `activeProcesses`/`cancellationRequested` bookkeeping with
  /// `run()`, so the existing `cancel(executionID:)` terminates streaming
  /// runs too. If `command.standardInputText` is set, it is written to the
  /// process's stdin and the pipe is then closed for EOF.
}
