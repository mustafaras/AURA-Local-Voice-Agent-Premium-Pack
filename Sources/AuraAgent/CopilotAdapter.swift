import AuraCore
import AuraPolicy
import AuraShell
import Foundation

/// Coordinates a single Copilot CLI run: repository-instructions secret
/// scan, policy gate, upfront approval, process execution, JSONL
/// normalization, budget observation, and cancellation.
///
/// `copilot -p` (non-interactive mode) requires tool approval to be granted
/// before spawning — verified via `copilot help permissions`: unlisted tools
/// either block on a confirmation prompt with no TTY to answer it, or
/// (`--allow-all-tools`) run without per-call confirmation. Authorization
/// happens once, upfront, through `PolicyEngine.evaluate`; the resulting
/// tool profile is exactly the profile that was evaluated. This adapter
/// drives only the local `copilot` CLI — GitHub's separate cloud-hosted
/// coding agent is out of scope; see ADR-013.
public actor CopilotAdapter {
  private let configuration: CopilotConfiguration
  private let policyEngine: PolicyEngine
  private let approvalPresenter: any CopilotApprovalPresenting
  private let processExecutor: any AdapterProcessExecuting
  private let eventBus: AuraEventBus

  public init(
    configuration: CopilotConfiguration,
    policyEngine: PolicyEngine,
    approvalPresenter: any CopilotApprovalPresenting = CopilotAlwaysDenyApprovalPresenter(),
    processExecutor: (any AdapterProcessExecuting)? = nil,
    eventBus: AuraEventBus = .shared
  ) {
    self.configuration = configuration
    self.policyEngine = policyEngine
    self.approvalPresenter = approvalPresenter
    self.eventBus = eventBus
    self.processExecutor =
      processExecutor
      ?? ShellAdapterProcessExecutor(
        shell: AuraShell(configuration: configuration.derivedShellConfiguration()))
  }

  /// Run a single Copilot turn. The returned stream yields every normalized
  /// event — including the repository-instructions scan and the upfront
  /// approval cycle — in the order it occurs, and finishes when the run
  /// completes, is blocked, is denied, or fails.
  public func run(
    request: CopilotRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> AsyncThrowingStream<CopilotNormalizedEvent, Error> {
    let runID = correlationID

    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          try await self.perform(
            request: request, actor: actor, sessionID: sessionID, correlationID: correlationID,
            causationID: causationID, runID: runID, continuation: continuation)
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      // Only propagate cancellation to the underlying process when the
      // *consumer* stops iterating early (`.cancelled`). On `.finished`
      // (success or a thrown error), `perform(...)` already ran to
      // completion and the process has already exited on its own.
      continuation.onTermination = { @Sendable termination in
        guard case .cancelled = termination else { return }
        task.cancel()
        Task { await self.processExecutor.cancel(executionID: correlationID) }
      }
    }
  }

  /// Cancel an in-flight run by correlation ID.
  public func cancel(correlationID: UUID) async {
    await processExecutor.cancel(executionID: correlationID)
  }

  // MARK: - Implementation

  private func perform(
    request: CopilotRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    runID: UUID,
    continuation: AsyncThrowingStream<CopilotNormalizedEvent, Error>.Continuation
  ) async throws {
    if configuration.scanRepositoryInstructionsForSecrets {
      let scan = RepositoryInstructionsScanner.scan(repositoryRoot: request.workingDirectory)
      continuation.yield(
        .repositoryInstructionsScanned(
          filesScanned: scan.filesScanned, secretsDetected: scan.secretsDetected,
          blockedFiles: scan.blockedFiles))
      await emitAudit(
        CopilotRepositoryInstructionsScanEvent(
          runID: runID, filesScanned: scan.filesScanned, secretsDetected: scan.secretsDetected,
          blockedFiles: scan.blockedFiles),
        actor: actor, correlationID: correlationID, causationID: causationID)

      if scan.secretsDetected && configuration.loadCustomInstructionsByDefault {
        let message =
          "repository instructions contain secret-looking content: \(scan.blockedFiles.joined(separator: ", "))"
        await emitAudit(
          CopilotErrorEvent(
            runID: runID, category: .repositoryInstructionsBlocked, message: message),
          actor: actor, correlationID: correlationID, causationID: causationID)
        continuation.yield(.copilotError(message: message))
        return
      }
    }

    let policyRequest = CopilotPolicyAdapter.request(
      for: request, actor: actor, sessionID: sessionID, correlationID: correlationID,
      causationID: causationID)
    let decision = await policyEngine.evaluate(policyRequest)

    switch decision {
    case .allow:
      break

    case .deny(let reason, _):
      await denyAndEmit(
        requestID: policyRequest.id, reason: reason, runID: runID, actor: actor,
        correlationID: correlationID, causationID: causationID, continuation: continuation)
      return

    case .confirm(let challenge, _):
      continuation.yield(
        .approvalRequested(
          requestID: challenge.requestID, riskTier: challenge.riskTier,
          targetSummary: challenge.targetSummary, expiresAt: challenge.expiresAt))
      await emitAudit(
        CopilotApprovalRequestedEvent(
          requestID: challenge.requestID, sessionID: challenge.sessionID,
          riskTier: challenge.riskTier, targetSummary: challenge.targetSummary,
          expiresAt: challenge.expiresAt),
        actor: actor, correlationID: correlationID, causationID: causationID)

      let response = await approvalPresenter.present(challenge: challenge)
      let resolved = await policyEngine.submitConfirmation(response)
      switch resolved {
      case .allow:
        break
      case .deny(let reason, _):
        await denyAndEmit(
          requestID: challenge.requestID, reason: reason, runID: runID, actor: actor,
          correlationID: correlationID, causationID: causationID, continuation: continuation)
        return
      case .confirm:
        // submitConfirmation never re-issues a challenge; handled defensively.
        await denyAndEmit(
          requestID: challenge.requestID,
          reason: "unexpected re-confirmation after submitConfirmation", runID: runID,
          actor: actor, correlationID: correlationID, causationID: causationID,
          continuation: continuation)
        return
      }
    }

    let command: Command
    do {
      let timeout = min(
        request.timeoutSeconds ?? configuration.defaultTimeoutSeconds,
        configuration.maxTimeoutSeconds)
      let arguments = try CopilotArguments.make(request: request, configuration: configuration)
      command = Command(
        executable: configuration.executablePath,
        arguments: arguments,
        workingDirectory: request.workingDirectory,
        timeoutSeconds: timeout,
        riskTier: request.toolProfile == .workspaceWrite ? .destructive : .reversible,
        trailingArgument: request.objective
      )
    } catch {
      await emitAudit(
        CopilotErrorEvent(
          runID: runID, category: .cliLaunchFailed,
          message: "argument construction failed: \(error)"),
        actor: actor, correlationID: correlationID, causationID: causationID)
      continuation.yield(.copilotError(message: "argument construction failed"))
      return
    }

    continuation.yield(
      .runStarted(
        toolProfile: request.toolProfile.rawValue, workingDirectory: request.workingDirectory,
        model: request.model, customInstructionsLoaded: configuration.loadCustomInstructionsByDefault)
    )
    await emitAudit(
      CopilotRunStartedEvent(
        runID: runID, toolProfile: request.toolProfile.rawValue, model: request.model,
        workingDirectory: request.workingDirectory,
        customInstructionsLoaded: configuration.loadCustomInstructionsByDefault),
      actor: actor, correlationID: correlationID, causationID: causationID)

    let innerStream = await processExecutor.run(
      command: command, actor: actor, sessionID: sessionID, executionID: correlationID)
    let maxFileWrites = configuration.maxFileWritesPerRun
    var sequence = 0

    for try await streamEvent in innerStream {
      switch streamEvent {
      case .line(let outputLine):
        sequence += 1
        let normalized = CopilotEventNormalizer.normalize(
          line: outputLine.text, sequence: sequence)

        await emitAuditForNormalizedEvent(
          normalized, runID: runID, actor: actor, correlationID: correlationID,
          causationID: causationID)
        continuation.yield(normalized)

        // The CLI's own `result.usage.codeChanges.filesModified` is only
        // known once the run finishes, so this is a post-hoc observability
        // check (like the CLI-native `--max-ai-credits` budget), not a live
        // pre-emptive cancel.
        if case .turnCompleted(_, _, _, let filesModifiedCount, _, _) = normalized,
          filesModifiedCount > maxFileWrites
        {
          await emitAudit(
            CopilotBudgetExceededEvent(
              runID: runID, kind: .fileWrites, limit: Double(maxFileWrites),
              observed: Double(filesModifiedCount)),
            actor: actor, correlationID: correlationID, causationID: causationID)
          continuation.yield(
            .budgetExceeded(
              kind: "fileWrites", limit: Double(maxFileWrites),
              observed: Double(filesModifiedCount)))
        }

      case .completed(let result):
        let processFailed =
          result.wasCancelled || result.wasTimedOut
          || !command.expectedExitCodes.contains(result.exitCode)
        if processFailed {
          let reason =
            result.wasCancelled
            ? "process cancelled"
            : result.wasTimedOut
              ? "process timed out" : "process exited with unexpected code \(result.exitCode)"
          await emitAudit(
            CopilotErrorEvent(
              runID: runID,
              category: result.wasCancelled
                ? .cancelled : result.wasTimedOut ? .timedOut : .processExitedNonZero,
              message: reason),
            actor: actor, correlationID: correlationID, causationID: causationID)
          // Copilot's own `result` JSONL line may never arrive if the
          // process was killed before it could write it (cancellation,
          // timeout, crash). Surface process-level failure explicitly so
          // callers never mistake a killed process for a quiet success.
          continuation.yield(.turnFailed(message: reason))
        }
      }
    }
  }

  private func denyAndEmit(
    requestID: UUID,
    reason: String,
    runID: UUID,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID,
    continuation: AsyncThrowingStream<CopilotNormalizedEvent, Error>.Continuation
  ) async {
    await emitAudit(
      CopilotErrorEvent(runID: runID, category: .policyDenied, message: reason),
      actor: actor, correlationID: correlationID, causationID: causationID)
    continuation.yield(.approvalDecision(requestID: requestID, allowed: false, reason: reason))
  }

  private func emitAuditForNormalizedEvent(
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
    case .turnCompleted(_, let sessionDurationMs, let premiumRequests, let filesModifiedCount,
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

  private func emitAudit<Payload: EventPayload>(
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
