import AuraCore
import AuraPolicy
import AuraShell
import Foundation

/// Coordinates a single Codex CLI run: policy gate, upfront approval,
/// process execution, JSONL normalization, budget enforcement, and
/// cancellation.
///
/// `codex exec` has no `-a/--ask-for-approval` flag (verified via
/// `codex exec --help` — that flag exists only on the top-level interactive
/// `codex` command) and is always run without any config-driven mid-run
/// approval prompt. Authorization instead happens once, upfront, through
/// `PolicyEngine.evaluate` before a process is ever spawned; the resulting
/// `-s` sandbox tier is exactly the tier that was evaluated. See ADR-011.
public actor CodexAdapter {
  private let configuration: CodexConfiguration
  private let policyEngine: PolicyEngine
  private let approvalPresenter: any CodexApprovalPresenting
  private let processExecutor: any AdapterProcessExecuting
  private let eventBus: AuraEventBus

  public init(
    configuration: CodexConfiguration,
    policyEngine: PolicyEngine,
    approvalPresenter: any CodexApprovalPresenting = CodexAlwaysDenyApprovalPresenter(),
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

  /// Run a single Codex turn. The returned stream yields every normalized
  /// event — including the upfront approval cycle — in the order it occurs,
  /// and finishes when the run completes, is denied, or fails.
  public func run(
    request: CodexRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> AsyncThrowingStream<CodexNormalizedEvent, Error> {
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
      // completion and the process has already exited on its own —
      // cancelling here too would be redundant on every single run.
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

  /// Runs the full policy-gate → approval → spawn → consume flow, yielding
  /// every event through `continuation`. Throws only for genuine stream
  /// failures (process launch/IO errors); denial and policy-driven
  /// termination are represented as yielded events, not thrown errors.
  private func perform(
    request: CodexRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    runID: UUID,
    continuation: AsyncThrowingStream<CodexNormalizedEvent, Error>.Continuation
  ) async throws {
    let policyRequest = CodexPolicyAdapter.request(
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
        CodexApprovalRequestedEvent(
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
      let arguments = try CodexArguments.make(request: request, configuration: configuration)
      command = Command(
        executable: configuration.executablePath,
        arguments: arguments,
        workingDirectory: request.workingDirectory,
        timeoutSeconds: timeout,
        riskTier: request.sandbox == .workspaceWrite ? .destructive : .reversible,
        standardInputText: request.prompt
      )
    } catch {
      await emitAudit(
        CodexErrorEvent(
          runID: runID, category: .cliLaunchFailed,
          message: "argument construction failed: \(error)"),
        actor: actor, correlationID: correlationID, causationID: causationID)
      continuation.yield(.codexError(message: "argument construction failed"))
      return
    }

    continuation.yield(
      .runStarted(
        sandbox: request.sandbox.rawValue, workingDirectory: request.workingDirectory,
        ephemeral: configuration.ephemeralByDefault, model: request.model))
    await emitAudit(
      CodexRunStartedEvent(
        runID: runID, sandbox: request.sandbox.rawValue, model: request.model,
        workingDirectory: request.workingDirectory, ephemeral: configuration.ephemeralByDefault),
      actor: actor, correlationID: correlationID, causationID: causationID)

    let innerStream = await processExecutor.run(
      command: command, actor: actor, sessionID: sessionID, executionID: correlationID)
    let maxFileWrites = configuration.maxFileWritesPerRun
    let start = Date()
    var sequence = 0
    var fileWriteCount = 0
    var budgetExceededTriggered = false

    for try await streamEvent in innerStream {
      switch streamEvent {
      case .line(let outputLine):
        sequence += 1
        let normalized = CodexEventNormalizer.normalize(line: outputLine.text, sequence: sequence)

        if case .unclassifiedItem(rawItemType: "file_change", _, _) = normalized {
          fileWriteCount += 1
          // `cancel()` doesn't stop the executor from delivering lines it
          // already buffered before the signal lands, so guard against
          // re-triggering on every subsequent file-change line in the meantime.
          if fileWriteCount > maxFileWrites && !budgetExceededTriggered {
            budgetExceededTriggered = true
            await emitAudit(
              CodexBudgetExceededEvent(
                runID: runID, kind: .fileWrites, limit: Double(maxFileWrites),
                observed: Double(fileWriteCount)),
              actor: actor, correlationID: correlationID, causationID: causationID)
            continuation.yield(
              .budgetExceeded(
                kind: "fileWrites", limit: Double(maxFileWrites), observed: Double(fileWriteCount))
            )
            await processExecutor.cancel(executionID: correlationID)
          }
        }

        await emitAuditForNormalizedEvent(
          normalized, runID: runID, actor: actor, correlationID: correlationID,
          causationID: causationID)
        continuation.yield(normalized)

      case .completed(let result):
        let processFailed =
          result.wasCancelled || result.wasTimedOut
          || !command.expectedExitCodes.contains(result.exitCode)
        let outcome: CodexTurnCompletedEvent.Outcome = processFailed ? .failed : .succeeded
        await emitAudit(
          CodexTurnCompletedEvent(
            runID: runID, outcome: outcome, durationSeconds: Date().timeIntervalSince(start)),
          actor: actor, correlationID: correlationID, causationID: causationID)

        // Codex's own `turn.completed`/`turn.failed` JSONL lines may never
        // arrive if the process was killed before it could write them
        // (cancellation, timeout, crash). Surface process-level failure
        // explicitly so callers never mistake a killed process for a quiet
        // success.
        if processFailed {
          let reason =
            result.wasCancelled
            ? "process cancelled"
            : result.wasTimedOut
              ? "process timed out" : "process exited with unexpected code \(result.exitCode)"
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
    continuation: AsyncThrowingStream<CodexNormalizedEvent, Error>.Continuation
  ) async {
    await emitAudit(
      CodexErrorEvent(runID: runID, category: .policyDenied, message: reason),
      actor: actor, correlationID: correlationID, causationID: causationID)
    continuation.yield(.approvalDecision(requestID: requestID, allowed: false, reason: reason))
  }

  private func emitAuditForNormalizedEvent(
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
