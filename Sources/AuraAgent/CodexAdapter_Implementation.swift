import AuraCore
import AuraPolicy
import AuraShell
import Foundation

struct CodexPerformContext {
  let actor: ActorID
  let sessionID: UUID
  let correlationID: UUID
  let causationID: UUID
  let runID: UUID
  let continuation: AsyncThrowingStream<CodexNormalizedEvent, Error>.Continuation
}

private struct CodexConsumptionState {
  let sequence: Int
  let fileWriteCount: Int
  let budgetExceededTriggered: Bool
}

extension CodexAdapter {
  // MARK: - Implementation

  /// Runs the full policy-gate → approval → spawn → consume flow, yielding
  /// every event through `continuation`. Throws only for genuine stream
  /// failures (process launch/IO errors); denial and policy-driven
  /// termination are represented as yielded events, not thrown errors.
  func perform(
    request: CodexRunRequest,
    context: CodexPerformContext
  ) async throws {
    guard await authorize(request: request, context: context) else { return }

    let command: Command
    do {
      command = try makeCommand(request)
    } catch {
      await emitLaunchFailure(error, context: context)
      return
    }

    await emitRunStarted(request, context: context)

    let innerStream = await processExecutor.run(
      command: command,
      actor: context.actor,
      sessionID: context.sessionID,
      executionID: context.correlationID)
    try await consume(innerStream, command: command, context: context)
  }

  private func makeCommand(_ request: CodexRunRequest) throws -> Command {
    let timeout = min(
      request.timeoutSeconds ?? configuration.defaultTimeoutSeconds,
      configuration.maxTimeoutSeconds)
    let arguments = try CodexArguments.make(request: request, configuration: configuration)
    return Command(
      executable: configuration.executablePath,
      arguments: arguments,
      workingDirectory: request.workingDirectory,
      timeoutSeconds: timeout,
      riskTier: request.sandbox == .workspaceWrite ? .destructive : .reversible,
      standardInputText: request.prompt)
  }

  private func emitLaunchFailure(_ error: Error, context: CodexPerformContext) async {
    await emitAudit(
      CodexErrorEvent(
        runID: context.runID, category: .cliLaunchFailed,
        message: "argument construction failed: \(error)"),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(.codexError(message: "argument construction failed"))
  }

  private func emitRunStarted(_ request: CodexRunRequest, context: CodexPerformContext) async {
    context.continuation.yield(
      .runStarted(
        sandbox: request.sandbox.rawValue, workingDirectory: request.workingDirectory,
        ephemeral: configuration.ephemeralByDefault, model: request.model))
    await emitAudit(
      CodexRunStartedEvent(
        runID: context.runID, sandbox: request.sandbox.rawValue, model: request.model,
        workingDirectory: request.workingDirectory, ephemeral: configuration.ephemeralByDefault),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
  }

  private func consume(
    _ stream: AsyncThrowingStream<ProcessStreamEvent, Error>,
    command: Command,
    context: CodexPerformContext
  ) async throws {
    let start = Date()
    var sequence = 0
    var fileWriteCount = 0
    var budgetExceededTriggered = false
    for try await event in stream {
      switch event {
      case .line(let outputLine):
        let state = await handleLine(
          outputLine,
          sequence: sequence,
          fileWriteCount: fileWriteCount,
          budgetExceededTriggered: budgetExceededTriggered,
          context: context)
        sequence = state.sequence
        fileWriteCount = state.fileWriteCount
        budgetExceededTriggered = state.budgetExceededTriggered
      case .completed(let result):
        await handleCompletion(result, command: command, start: start, context: context)
      }
    }
  }

  private func handleLine(
    _ outputLine: ProcessOutputLine,
    sequence: Int,
    fileWriteCount: Int,
    budgetExceededTriggered: Bool,
    context: CodexPerformContext
  ) async -> CodexConsumptionState {
    let nextSequence = sequence + 1
    let normalized = CodexEventNormalizer.normalize(
      line: outputLine.text, sequence: nextSequence)
    var nextFileWriteCount = fileWriteCount
    var nextBudgetExceeded = budgetExceededTriggered
    if case .unclassifiedItem(rawItemType: "file_change", _, _) = normalized {
      nextFileWriteCount += 1
      if nextFileWriteCount > configuration.maxFileWritesPerRun && !nextBudgetExceeded {
        nextBudgetExceeded = true
        await emitAudit(
          CodexBudgetExceededEvent(
            runID: context.runID, kind: .fileWrites,
            limit: Double(configuration.maxFileWritesPerRun), observed: Double(nextFileWriteCount)),
          actor: context.actor,
          correlationID: context.correlationID,
          causationID: context.causationID)
        context.continuation.yield(
          .budgetExceeded(
            kind: "fileWrites", limit: Double(configuration.maxFileWritesPerRun),
            observed: Double(nextFileWriteCount)))
        await processExecutor.cancel(executionID: context.correlationID)
      }
    }
    await emitAuditForNormalizedEvent(
      normalized, runID: context.runID, actor: context.actor,
      correlationID: context.correlationID, causationID: context.causationID)
    context.continuation.yield(normalized)
    return CodexConsumptionState(
      sequence: nextSequence,
      fileWriteCount: nextFileWriteCount,
      budgetExceededTriggered: nextBudgetExceeded)
  }

  private func handleCompletion(
    _ result: ProcessResult,
    command: Command,
    start: Date,
    context: CodexPerformContext
  ) async {
    let processFailed =
      result.wasCancelled || result.wasTimedOut
      || !command.expectedExitCodes.contains(result.exitCode)
    await emitAudit(
      CodexTurnCompletedEvent(
        runID: context.runID,
        outcome: processFailed ? .failed : .succeeded,
        durationSeconds: Date().timeIntervalSince(start)),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    guard processFailed else { return }
    let reason =
      result.wasCancelled
      ? "process cancelled"
      : result.wasTimedOut
        ? "process timed out" : "process exited with unexpected code \(result.exitCode)"
    context.continuation.yield(.turnFailed(message: reason))
  }

  private func authorize(
    request: CodexRunRequest,
    context: CodexPerformContext
  ) async -> Bool {
    let policyRequest = CodexPolicyAdapter.request(
      for: request,
      actor: context.actor,
      sessionID: context.sessionID,
      correlationID: context.correlationID,
      causationID: context.causationID)
    let decision = await policyEngine.evaluate(policyRequest)
    switch decision {
    case .allow:
      return true
    case .deny(let reason, _):
      await denyAndEmit(requestID: policyRequest.id, reason: reason, context: context)
      return false
    case .confirm(let challenge, _):
      context.continuation.yield(
        .approvalRequested(
          requestID: challenge.requestID, riskTier: challenge.riskTier,
          targetSummary: challenge.targetSummary, expiresAt: challenge.expiresAt))
      await emitAudit(
        CodexApprovalRequestedEvent(
          requestID: challenge.requestID, sessionID: challenge.sessionID,
          riskTier: challenge.riskTier, targetSummary: challenge.targetSummary,
          expiresAt: challenge.expiresAt),
        actor: context.actor,
        correlationID: context.correlationID,
        causationID: context.causationID)
      let response = await approvalPresenter.present(challenge: challenge)
      let resolved = await policyEngine.submitConfirmation(response)
      switch resolved {
      case .allow:
        return true
      case .deny(let reason, _):
        await denyAndEmit(requestID: challenge.requestID, reason: reason, context: context)
        return false
      case .confirm:
        await denyAndEmit(
          requestID: challenge.requestID,
          reason: "unexpected re-confirmation after submitConfirmation",
          context: context)
        return false
      }
    }
  }

  func denyAndEmit(
    requestID: UUID,
    reason: String,
    context: CodexPerformContext
  ) async {
    await emitAudit(
      CodexErrorEvent(runID: context.runID, category: .policyDenied, message: reason),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(
      .approvalDecision(requestID: requestID, allowed: false, reason: reason))
  }

  func emitAuditForNormalizedEvent(
    _ event: CodexNormalizedEvent,
    runID: UUID,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    switch event {
    case .itemError(let message, _):
      await emitAudit(
        CodexErrorEvent(runID: runID, category: .unknown, message: message),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .codexError(let message):
      await emitAudit(
        CodexErrorEvent(runID: runID, category: .unknown, message: message),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .turnFailed(let message):
      await emitAudit(
        CodexErrorEvent(runID: runID, category: .processExitedNonZero, message: message ?? ""),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .unclassifiedItem(let rawItemType, let sequence, _):
      switch rawItemType {
      case "file_change":
        await emitAudit(
          CodexFileChangeEvent(runID: runID, rawItemType: rawItemType ?? "", sequence: sequence),
          actor: actor, correlationID: correlationID, causationID: causationID)
      case "plan_update":
        await emitAudit(
          CodexPlanUpdateEvent(
            runID: runID, rawItemType: rawItemType ?? "", summary: "", sequence: sequence),
          actor: actor, correlationID: correlationID, causationID: causationID)
      default:
        break
      }
    default:
      break
    }
  }

  func emitAudit<Payload: EventPayload>(
    _ payload: Payload,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}
