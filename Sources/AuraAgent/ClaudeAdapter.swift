import AuraCore
import AuraPolicy
import AuraShell
import Foundation

/// Coordinates a single Claude Code run: policy gate, upfront approval,
/// process execution, JSONL normalization, budget observation, and
/// cancellation.
///
/// `claude -p` (non-interactive mode) always runs with
/// `--permission-mode dontAsk` — verified as the documented "only safe
/// choice" for unattended/CI runs, since a non-interactive run has no TTY to
/// answer any other permission mode's prompts. Authorization instead happens
/// once, upfront, through `PolicyEngine.evaluate` before a process is ever
/// spawned; the resulting tool profile (`--tools`) is exactly the profile
/// that was evaluated. See ADR-012.
public actor ClaudeAdapter {
  private let configuration: ClaudeConfiguration
  private let policyEngine: PolicyEngine
  private let approvalPresenter: any ClaudeApprovalPresenting
  private let processExecutor: any AdapterProcessExecuting
  private let eventBus: AuraEventBus

  public init(
    configuration: ClaudeConfiguration,
    policyEngine: PolicyEngine,
    approvalPresenter: any ClaudeApprovalPresenting = ClaudeAlwaysDenyApprovalPresenter(),
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

  /// Run a single Claude Code turn. The returned stream yields every
  /// normalized event — including the upfront approval cycle — in the order
  /// it occurs, and finishes when the run completes, is denied, or fails.
  public func run(
    request: ClaudeRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> AsyncThrowingStream<ClaudeNormalizedEvent, Error> {
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

  private func perform(
    request: ClaudeRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    runID: UUID,
    continuation: AsyncThrowingStream<ClaudeNormalizedEvent, Error>.Continuation
  ) async throws {
    let policyRequest = ClaudePolicyAdapter.request(
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
        ClaudeApprovalRequestedEvent(
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
      let arguments = try ClaudeArguments.make(request: request, configuration: configuration)
      command = Command(
        executable: configuration.executablePath,
        arguments: arguments,
        workingDirectory: request.workingDirectory,
        timeoutSeconds: timeout,
        riskTier: request.toolProfile == .workspaceWrite ? .destructive : .reversible,
        standardInputText: request.objective
      )
    } catch {
      await emitAudit(
        ClaudeErrorEvent(
          runID: runID, category: .cliLaunchFailed,
          message: "argument construction failed: \(error)"),
        actor: actor, correlationID: correlationID, causationID: causationID)
      continuation.yield(.claudeError(message: "argument construction failed"))
      return
    }

    continuation.yield(
      .runStarted(
        permissionMode: "dontAsk", workingDirectory: request.workingDirectory,
        ephemeral: configuration.ephemeralByDefault, model: request.model))
    await emitAudit(
      ClaudeRunStartedEvent(
        runID: runID, permissionMode: "dontAsk", model: request.model,
        workingDirectory: request.workingDirectory, ephemeral: configuration.ephemeralByDefault),
      actor: actor, correlationID: correlationID, causationID: causationID)

    let innerStream = await processExecutor.run(
      command: command, actor: actor, sessionID: sessionID, executionID: correlationID)
    let costBudget = request.maxCostUSD ?? configuration.maxEstimatedCostUSD
    var sequence = 0

    for try await streamEvent in innerStream {
      switch streamEvent {
      case .line(let outputLine):
        sequence += 1
        let normalized = ClaudeEventNormalizer.normalize(line: outputLine.text, sequence: sequence)

        await emitAuditForNormalizedEvent(
          normalized, runID: runID, actor: actor, correlationID: correlationID,
          causationID: causationID)
        continuation.yield(normalized)

        // `--max-budget-usd` is enforced natively by the CLI; this is a
        // post-hoc observability check comparing the CLI's own reported
        // final cost against the configured budget, not a live pre-emptive
        // cancel (the run has already finished by the time `totalCostUSD`
        // is known).
        if case .turnCompleted(_, let totalCostUSD, _, _, _, _) = normalized,
          let costBudget, totalCostUSD > costBudget
        {
          await emitAudit(
            ClaudeBudgetExceededEvent(
              runID: runID, kind: .costUSD, limit: costBudget, observed: totalCostUSD),
            actor: actor, correlationID: correlationID, causationID: causationID)
          continuation.yield(
            .budgetExceeded(kind: "costUSD", limit: costBudget, observed: totalCostUSD))
        }

      case .completed(let result):
        let processFailed =
          result.wasCancelled || result.wasTimedOut
          || !command.expectedExitCodes.contains(result.exitCode)
        let outcome: ClaudeErrorEvent.Category? =
          result.wasCancelled ? .cancelled : result.wasTimedOut ? .timedOut : nil

        if processFailed {
          let reason =
            result.wasCancelled
            ? "process cancelled"
            : result.wasTimedOut
              ? "process timed out" : "process exited with unexpected code \(result.exitCode)"
          await emitAudit(
            ClaudeErrorEvent(
              runID: runID, category: outcome ?? .processExitedNonZero, message: reason),
            actor: actor, correlationID: correlationID, causationID: causationID)
          // Claude's own `result` JSONL line may never arrive if the
          // process was killed before it could write it (cancellation,
          // timeout, crash). Surface process-level failure explicitly so
          // callers never mistake a killed process for a quiet success.
          continuation.yield(.turnFailed(message: reason, apiErrorStatus: nil))
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
    continuation: AsyncThrowingStream<ClaudeNormalizedEvent, Error>.Continuation
  ) async {
    await emitAudit(
      ClaudeErrorEvent(runID: runID, category: .policyDenied, message: reason),
      actor: actor, correlationID: correlationID, causationID: causationID)
    continuation.yield(.approvalDecision(requestID: requestID, allowed: false, reason: reason))
  }

  private func emitAuditForNormalizedEvent(
    _ event: ClaudeNormalizedEvent,
    runID: UUID,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    switch event {
    case .claudeError(let message):
      await emitAudit(
        ClaudeErrorEvent(runID: runID, category: .unknown, message: message),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .turnFailed(let message, let apiErrorStatus):
      await emitAudit(
        ClaudeErrorEvent(
          runID: runID, category: apiErrorStatus != nil ? .apiError : .processExitedNonZero,
          message: message ?? ""),
        actor: actor, correlationID: correlationID, causationID: causationID)
    case .turnCompleted(
      let resultText, let totalCostUSD, let numTurns, let durationMs, let stopReason, let denials):
      await emitAudit(
        ClaudeTurnCompletedEvent(
          runID: runID, outcome: .succeeded, resultText: resultText, totalCostUSD: totalCostUSD,
          numTurns: numTurns, durationMs: durationMs, stopReason: stopReason,
          permissionDenialCount: denials),
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
