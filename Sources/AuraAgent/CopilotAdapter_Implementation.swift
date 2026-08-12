import AuraCore
import AuraPolicy
import AuraShell
import Foundation

struct CopilotPerformContext {
  let actor: ActorID
  let sessionID: UUID
  let correlationID: UUID
  let causationID: UUID
  let runID: UUID
  let continuation: AsyncThrowingStream<CopilotNormalizedEvent, Error>.Continuation
}

extension CopilotAdapter {
  // MARK: - Implementation

  func perform(
    request: CopilotRunRequest,
    context: CopilotPerformContext
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

  private func makeCommand(_ request: CopilotRunRequest) throws -> Command {
    let timeout = min(
      request.timeoutSeconds ?? configuration.defaultTimeoutSeconds,
      configuration.maxTimeoutSeconds)
    let arguments = try CopilotArguments.make(request: request, configuration: configuration)
    return Command(
      executable: configuration.executablePath,
      arguments: arguments,
      workingDirectory: request.workingDirectory,
      timeoutSeconds: timeout,
      riskTier: request.toolProfile == .workspaceWrite ? .destructive : .reversible,
      trailingArgument: request.objective)
  }

  private func emitLaunchFailure(_ error: Error, context: CopilotPerformContext) async {
    await emitAudit(
      CopilotErrorEvent(
        runID: context.runID, category: .cliLaunchFailed,
        message: "argument construction failed: \(error)"),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(.copilotError(message: "argument construction failed"))
  }

  private func emitRunStarted(_ request: CopilotRunRequest, context: CopilotPerformContext) async {
    context.continuation.yield(
      .runStarted(
        toolProfile: request.toolProfile.rawValue, workingDirectory: request.workingDirectory,
        model: request.model,
        customInstructionsLoaded: configuration.loadCustomInstructionsByDefault))
    await emitAudit(
      CopilotRunStartedEvent(
        runID: context.runID, toolProfile: request.toolProfile.rawValue, model: request.model,
        workingDirectory: request.workingDirectory,
        customInstructionsLoaded: configuration.loadCustomInstructionsByDefault),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
  }

  private func consume(
    _ stream: AsyncThrowingStream<ProcessStreamEvent, Error>,
    command: Command,
    context: CopilotPerformContext
  ) async throws {
    var sequence = 0
    for try await event in stream {
      switch event {
      case .line(let outputLine):
        sequence += 1
        await handleLine(outputLine, sequence: sequence, context: context)
      case .completed(let result):
        await handleCompletion(result, command: command, context: context)
      }
    }
  }

  private func handleLine(
    _ outputLine: ProcessOutputLine,
    sequence: Int,
    context: CopilotPerformContext
  ) async {
    let normalized = CopilotEventNormalizer.normalize(
      line: outputLine.text, sequence: sequence)
    await emitAuditForNormalizedEvent(
      normalized, runID: context.runID, actor: context.actor,
      correlationID: context.correlationID, causationID: context.causationID)
    context.continuation.yield(normalized)
    guard case .turnCompleted(_, _, _, let filesModifiedCount, _, _) = normalized,
      filesModifiedCount > configuration.maxFileWritesPerRun
    else { return }
    await emitAudit(
      CopilotBudgetExceededEvent(
        runID: context.runID, kind: .fileWrites,
        limit: Double(configuration.maxFileWritesPerRun), observed: Double(filesModifiedCount)),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(
      .budgetExceeded(
        kind: "fileWrites", limit: Double(configuration.maxFileWritesPerRun),
        observed: Double(filesModifiedCount)))
  }

  private func handleCompletion(
    _ result: ProcessResult,
    command: Command,
    context: CopilotPerformContext
  ) async {
    let processFailed =
      result.wasCancelled || result.wasTimedOut
      || !command.expectedExitCodes.contains(result.exitCode)
    guard processFailed else { return }
    let reason =
      result.wasCancelled
      ? "process cancelled"
      : result.wasTimedOut
        ? "process timed out" : "process exited with unexpected code \(result.exitCode)"
    await emitAudit(
      CopilotErrorEvent(
        runID: context.runID,
        category: result.wasCancelled
          ? .cancelled : result.wasTimedOut ? .timedOut : .processExitedNonZero,
        message: reason),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(.turnFailed(message: reason))
  }

  private func authorize(
    request: CopilotRunRequest,
    context: CopilotPerformContext
  ) async -> Bool {
    guard await scanRepositoryInstructions(request: request, context: context) else { return false }
    let policyRequest = CopilotPolicyAdapter.request(
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
        CopilotApprovalRequestedEvent(
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

  private func scanRepositoryInstructions(
    request: CopilotRunRequest,
    context: CopilotPerformContext
  ) async -> Bool {
    guard configuration.scanRepositoryInstructionsForSecrets else { return true }
    let scan = RepositoryInstructionsScanner.scan(repositoryRoot: request.workingDirectory)
    context.continuation.yield(
      .repositoryInstructionsScanned(
        filesScanned: scan.filesScanned, secretsDetected: scan.secretsDetected,
        blockedFiles: scan.blockedFiles))
    await emitAudit(
      CopilotRepositoryInstructionsScanEvent(
        runID: context.runID, filesScanned: scan.filesScanned,
        secretsDetected: scan.secretsDetected, blockedFiles: scan.blockedFiles),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    guard scan.secretsDetected && configuration.loadCustomInstructionsByDefault else { return true }
    let message =
      "repository instructions contain secret-looking content: "
      + "\(scan.blockedFiles.joined(separator: ", "))"
    await emitAudit(
      CopilotErrorEvent(
        runID: context.runID, category: .repositoryInstructionsBlocked, message: message),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(.copilotError(message: message))
    return false
  }

  func denyAndEmit(
    requestID: UUID,
    reason: String,
    context: CopilotPerformContext
  ) async {
    await emitAudit(
      CopilotErrorEvent(runID: context.runID, category: .policyDenied, message: reason),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(
      .approvalDecision(requestID: requestID, allowed: false, reason: reason))
  }

  func emitAuditForNormalizedEvent(
    _ event: CopilotNormalizedEvent,
    runID: UUID,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    switch event {
    case .copilotError(let message):
      await emitAudit(
        CopilotErrorEvent(runID: runID, category: .unknown, message: message),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .sessionError(let errorType, _, let message, let statusCode, _):
      await emitAudit(
        CopilotErrorEvent(
          runID: runID, category: errorType == "quota" ? .quotaExceeded : .unknown,
          message: "\(message)\(statusCode.map { " (status \($0))" } ?? "")"),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .modelCallFailure(let model, let statusCode, let errorMessage, _):
      await emitAudit(
        CopilotErrorEvent(
          runID: runID, category: .unknown,
          message: "\(model): \(errorMessage)\(statusCode.map { " (status \($0))" } ?? "")"),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .turnFailed(let message):
      await emitAudit(
        CopilotErrorEvent(runID: runID, category: .processExitedNonZero, message: message ?? ""),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .turnCompleted(
      _, let sessionDurationMs, let premiumRequests, let filesModifiedCount,
      let linesAdded, let linesRemoved):
      await emitAudit(
        CopilotTurnCompletedEvent(
          runID: runID, outcome: .succeeded, sessionDurationMs: sessionDurationMs,
          premiumRequests: premiumRequests, filesModifiedCount: filesModifiedCount,
          linesAdded: linesAdded, linesRemoved: linesRemoved),
        actor: actor, correlationID: correlationID, causationID: causationID)
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
