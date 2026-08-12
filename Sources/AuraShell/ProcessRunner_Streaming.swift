import AuraCore
import Foundation

private struct StreamingLaunchContext: @unchecked Sendable {
  let process: Process
  let stdoutPipe: Pipe
  let stderrPipe: Pipe
  let stdoutAccumulator: LineAccumulator
  let stderrAccumulator: LineAccumulator
  let redactor: OutputRedactor
  let start: Date
  let deadline: Date
}

private struct StreamingProcessResources {
  let stdoutPipe: Pipe
  let stderrPipe: Pipe
  let inputPipe: Pipe?
}

private struct StreamingOutputContext: @unchecked Sendable {
  let accumulator: LineAccumulator
  let redactor: OutputRedactor
  let executionID: UUID
  let continuation: AsyncThrowingStream<ProcessStreamEvent, Error>.Continuation
}

extension ProcessRunner {
  public func runStreaming(
    _ command: Command,
    executionID: UUID
  ) async -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    let redactor = OutputRedactor(patterns: configuration.redactionPatterns)
    do {
      try command.validate(configuration: configuration)
    } catch {
      return throwingStream(error)
    }
    guard
      let context = await launchStreamingProcess(
        command, executionID: executionID, redactor: redactor)
    else {
      return throwingStream(AuraError.shellError("streaming process launch failed"))
    }
    activeProcesses[executionID] = context.process
    return makeStreamingStream(context, command: command, executionID: executionID)
  }

  private func throwingStream(
    _ error: Error
  ) -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    AsyncThrowingStream { continuation in
      continuation.finish(throwing: error)
    }
  }

  private func launchStreamingProcess(
    _ command: Command,
    executionID: UUID,
    redactor: OutputRedactor
  ) async -> StreamingLaunchContext? {
    let process = Process()
    let resources = configureStreamingProcess(process, command: command)
    await announceStreamingStart(command: command, executionID: executionID)
    do {
      try process.run()
    } catch {
      await emitCompletion(
        ProcessCompletionInput(
          executionID: executionID, redactor: redactor, start: Date(), outcome: .failed,
          exitCode: nil, stdoutBytes: 0, stderrBytes: 0))
      return nil
    }
    writeStreamingInput(resources.inputPipe, text: command.standardInputText)
    let start = Date()
    let stdoutAccumulator = LineAccumulator(
      maxBytes: configuration.maxOutputBytes, maxLines: configuration.maxOutputLines)
    let stderrAccumulator = LineAccumulator(
      maxBytes: configuration.maxOutputBytes, maxLines: configuration.maxOutputLines)
    return StreamingLaunchContext(
      process: process, stdoutPipe: resources.stdoutPipe, stderrPipe: resources.stderrPipe,
      stdoutAccumulator: stdoutAccumulator, stderrAccumulator: stderrAccumulator,
      redactor: redactor, start: start,
      deadline: start.addingTimeInterval(command.timeoutSeconds))
  }

  private func configureStreamingProcess(
    _ process: Process, command: Command
  ) -> StreamingProcessResources {
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
    let inputPipe: Pipe?
    if command.standardInputText != nil {
      let pipe = Pipe()
      process.standardInput = pipe
      inputPipe = pipe
    } else {
      inputPipe = nil
    }
    return StreamingProcessResources(
      stdoutPipe: stdoutPipe, stderrPipe: stderrPipe, inputPipe: inputPipe)
  }

  private func announceStreamingStart(command: Command, executionID: UUID) async {
    await AuraEventBus.shared.emit(
      EventEnvelope(
        correlationID: executionID, causationID: executionID, actor: .automation,
        sensitivity: .internalLevel,
        payload: CommandStartedEvent(
          executionID: executionID, executable: command.executable,
          argumentCount: command.effectiveArguments.count)))
  }

  private func writeStreamingInput(_ inputPipe: Pipe?, text: String?) {
    guard let inputPipe, let text else { return }
    if let data = text.data(using: .utf8) {
      inputPipe.fileHandleForWriting.write(data)
    }
    inputPipe.fileHandleForWriting.closeFile()
  }

  private func makeStreamingStream(
    _ context: StreamingLaunchContext,
    command: Command,
    executionID: UUID
  ) -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    AsyncThrowingStream { continuation in
      let outputContext = StreamingOutputContext(
        accumulator: context.stdoutAccumulator, redactor: context.redactor,
        executionID: executionID, continuation: continuation)
      installOutputHandler(
        context.stdoutPipe, stream: .stdout, context: outputContext)
      let errorContext = StreamingOutputContext(
        accumulator: context.stderrAccumulator, redactor: context.redactor,
        executionID: executionID, continuation: continuation)
      installOutputHandler(
        context.stderrPipe, stream: .stderr, context: errorContext)
      let watchTask = Task {
        let watchOutcome = await self.watchStreamingProcess(
          executionID: executionID, process: context.process, deadline: context.deadline,
          stdoutAccumulator: context.stdoutAccumulator,
          stderrAccumulator: context.stderrAccumulator)
        await self.finishStreamingProcess(
          StreamingFinalizationContext(
            command: command, executionID: executionID, process: context.process,
            stdoutPipe: context.stdoutPipe, stderrPipe: context.stderrPipe,
            stdoutAccumulator: context.stdoutAccumulator,
            stderrAccumulator: context.stderrAccumulator,
            continuation: continuation, redactor: context.redactor, start: context.start,
            watchOutcome: watchOutcome))
      }
      continuation.onTermination = { @Sendable _ in
        watchTask.cancel()
        Task { await self.cancel(executionID: executionID) }
      }
    }
  }

  private func installOutputHandler(
    _ pipe: Pipe,
    stream: ProcessOutputStream,
    context: StreamingOutputContext
  ) {
    pipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else {
        handle.readabilityHandler = nil
        Task { await context.accumulator.markEOF() }
        return
      }
      let text = String(data: data, encoding: .utf8) ?? ""
      Task {
        for (line, sequence) in await context.accumulator.append(text) {
          context.continuation.yield(
            .line(
              ProcessOutputLine(
                executionID: context.executionID, stream: stream,
                text: context.redactor.redact(line),
                sequence: sequence)))
        }
      }
    }
  }
  private func finishStreamingProcess(
    _ context: StreamingFinalizationContext
  ) async {
    // Process exit does not guarantee that already-read chunks were parsed.
    for _ in 0..<100 {
      let stdoutEOF = await context.stdoutAccumulator.reachedEOF
      let stderrEOF = await context.stderrAccumulator.reachedEOF
      if stdoutEOF && stderrEOF { break }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }

    context.stdoutPipe.fileHandleForReading.readabilityHandler = nil
    context.stderrPipe.fileHandleForReading.readabilityHandler = nil
    await yieldRemainders(context)

    let exitCode = Int(context.process.terminationStatus)
    let outcome = completionOutcome(context)
    await emitCompletion(
      ProcessCompletionInput(
        executionID: context.executionID,
        redactor: context.redactor,
        start: context.start,
        outcome: outcome,
        exitCode: exitCode,
        stdoutBytes: 0,
        stderrBytes: 0))

    if context.watchOutcome.wasCancelled {
      context.continuation.finish(throwing: AuraError.shellError("cancelled"))
      return
    }
    if context.watchOutcome.wasTimedOut {
      context.continuation.finish(
        throwing: AuraError.shellError(
          "timed out after \(context.command.timeoutSeconds) seconds"))
      return
    }

    let duration = Date().timeIntervalSince(context.start)
    context.continuation.yield(
      .completed(
        ProcessResult(
          executionID: context.executionID,
          exitCode: exitCode,
          stdout: "",
          stderr: "",
          durationSeconds: duration,
          wasCancelled: false,
          wasTimedOut: false,
          stdoutTruncated: await context.stdoutAccumulator.boundExceeded,
          stderrTruncated: await context.stderrAccumulator.boundExceeded
        )))
    context.continuation.finish()
  }

  private func yieldRemainders(_ context: StreamingFinalizationContext) async {
    if let remainder = await context.stdoutAccumulator.flushRemainder() {
      context.continuation.yield(
        .line(
          ProcessOutputLine(
            executionID: context.executionID,
            stream: .stdout,
            text: context.redactor.redact(remainder.line),
            sequence: remainder.sequence)))
    }
    if let remainder = await context.stderrAccumulator.flushRemainder() {
      context.continuation.yield(
        .line(
          ProcessOutputLine(
            executionID: context.executionID,
            stream: .stderr,
            text: context.redactor.redact(remainder.line),
            sequence: remainder.sequence)))
    }
  }

  private func completionOutcome(
    _ context: StreamingFinalizationContext
  ) -> CommandCompletedEvent.Outcome {
    if context.watchOutcome.wasCancelled { return .cancelled }
    if context.watchOutcome.wasTimedOut { return .timedOut }
    if context.watchOutcome.wasBoundExceeded { return .failed }
    let exitCode = Int(context.process.terminationStatus)
    return context.command.expectedExitCodes.contains(exitCode) ? .succeeded : .failed
  }

  /// Poll loop shared by `runStreaming`, mirroring `run()`'s deadline and
  /// cancellation semantics, plus early termination on output-bound overrun
  /// (necessary because a streaming run may otherwise never exit on its own).
}

private struct StreamingFinalizationContext: @unchecked Sendable {
  let command: Command
  let executionID: UUID
  let process: Process
  let stdoutPipe: Pipe
  let stderrPipe: Pipe
  let stdoutAccumulator: LineAccumulator
  let stderrAccumulator: LineAccumulator
  let continuation: AsyncThrowingStream<ProcessStreamEvent, Error>.Continuation
  let redactor: OutputRedactor
  let start: Date
  let watchOutcome: ProcessWatchOutcome
}
