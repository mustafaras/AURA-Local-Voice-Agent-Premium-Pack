import AuraCore
import AuraPolicy
import AuraShell
import Foundation

struct ClaudePerformContext {
  let actor: ActorID
  let sessionID: UUID
  let correlationID: UUID
  let causationID: UUID
  let runID: UUID
  let continuation: AsyncThrowingStream<ClaudeNormalizedEvent, Error>.Continuation
}

extension ClaudeAdapter {
  private func makeCommand(_ request: ClaudeRunRequest) throws -> Command {
    let timeout = min(
      request.timeoutSeconds ?? configuration.defaultTimeoutSeconds,
      configuration.maxTimeoutSeconds)
    let arguments = try ClaudeArguments.make(request: request, configuration: configuration)
    return Command(
      executable: configuration.executablePath,
      arguments: arguments,
      workingDirectory: request.workingDirectory,
      timeoutSeconds: timeout,
      riskTier: request.toolProfile == .workspaceWrite ? .destructive : .reversible,
      standardInputText: request.objective)
  }

  private func emitLaunchFailure(_ error: Error, context: ClaudePerformContext) async {
    await emitAudit(
      ClaudeErrorEvent(
        runID: context.runID, category: .cliLaunchFailed,
        message: "argument construction failed: \(error)"),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(.claudeError(message: "argument construction failed"))
  }

  private func emitRunStarted(_ request: ClaudeRunRequest, context: ClaudePerformContext) async {
    let permissionMode = claudePermissionMode(for: request.toolProfile)
    context.continuation.yield(
      .runStarted(
        permissionMode: permissionMode, workingDirectory: request.workingDirectory,
        ephemeral: configuration.ephemeralByDefault, model: request.model))
    await emitAudit(
      ClaudeRunStartedEvent(
        runID: context.runID, permissionMode: permissionMode, model: request.model,
        workingDirectory: request.workingDirectory, ephemeral: configuration.ephemeralByDefault),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
  }

  private func consume(
    _ stream: AsyncThrowingStream<ProcessStreamEvent, Error>,
    command: Command,
    request: ClaudeRunRequest,
    context: ClaudePerformContext
  ) async throws {
    var sequence = 0
    for try await event in stream {
      switch event {
      case .line(let outputLine):
        await handleLine(outputLine, sequence: &sequence, request: request, context: context)
      case .completed(let result):
        await handleCompletion(result, command: command, context: context)
      }
    }
  }

  private func handleLine(
    _ outputLine: ProcessOutputLine,
    sequence: inout Int,
    request: ClaudeRunRequest,
    context: ClaudePerformContext
  ) async {
    sequence += 1
    let normalized = ClaudeEventNormalizer.normalize(line: outputLine.text, sequence: sequence)
    await emitAuditForNormalizedEvent(
      normalized, runID: context.runID, actor: context.actor,
      correlationID: context.correlationID, causationID: context.causationID)
    context.continuation.yield(normalized)
    guard case .turnCompleted(_, let totalCostUSD, _, _, _, _) = normalized,
      let costBudget = request.maxCostUSD ?? configuration.maxEstimatedCostUSD,
      totalCostUSD > costBudget
    else { return }
    await emitAudit(
      ClaudeBudgetExceededEvent(
        runID: context.runID, kind: .costUSD, limit: costBudget, observed: totalCostUSD),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(
      .budgetExceeded(kind: "costUSD", limit: costBudget, observed: totalCostUSD))
  }

  private func handleCompletion(
    _ result: ProcessResult,
    command: Command,
    context: ClaudePerformContext
  ) async {
    let processFailed =
      result.wasCancelled || result.wasTimedOut
      || !command.expectedExitCodes.contains(result.exitCode)
    guard processFailed else { return }
    let category: ClaudeErrorEvent.Category? =
      result.wasCancelled ? .cancelled : result.wasTimedOut ? .timedOut : nil
    let reason =
      result.wasCancelled
      ? "process cancelled"
      : result.wasTimedOut
        ? "process timed out" : "process exited with unexpected code \(result.exitCode)"
    await emitAudit(
      ClaudeErrorEvent(
        runID: context.runID, category: category ?? .processExitedNonZero, message: reason),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(.turnFailed(message: reason, apiErrorStatus: nil))
  }
}

/// Coordinates a single Claude Code run: policy gate, upfront approval,
/// process execution, JSONL normalization, budget observation, and
/// cancellation.
///
/// `claude -p` (non-interactive mode) runs with a `--permission-mode` derived
/// from the tool profile (`.readOnly` → `dontAsk`, `.workspaceWrite` →
/// `acceptEdits`); both are non-prompting under `-p`. Authorization happens
/// once, upfront, through `PolicyEngine.evaluate` before a process is ever
/// spawned; the resulting tool profile (`--tools`) is exactly the profile
/// that was evaluated, and a `.workspaceWrite` run is additionally confined
/// to an isolated `git` worktree and verified by a diff postcondition (SP-013/
/// SP-014). See ADR-012.
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
            request: request,
            context: ClaudePerformContext(
              actor: actor,
              sessionID: sessionID,
              correlationID: correlationID,
              causationID: causationID,
              runID: runID,
              continuation: continuation
            )
          )
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
    context: ClaudePerformContext
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
    try await consume(innerStream, command: command, request: request, context: context)
  }

  private func authorize(
    request: ClaudeRunRequest,
    context: ClaudePerformContext
  ) async -> Bool {
    let policyRequest = ClaudePolicyAdapter.request(
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
        ClaudeApprovalRequestedEvent(
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

  private func denyAndEmit(
    requestID: UUID,
    reason: String,
    context: ClaudePerformContext
  ) async {
    await emitAudit(
      ClaudeErrorEvent(runID: context.runID, category: .policyDenied, message: reason),
      actor: context.actor,
      correlationID: context.correlationID,
      causationID: context.causationID)
    context.continuation.yield(
      .approvalDecision(requestID: requestID, allowed: false, reason: reason))
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
