import AuraCore
import AuraPolicy
import AuraShell
import Foundation

private struct PlannerWorkflowContext {
  let objective: String
  let acceptanceCriteria: [String]
  let repositoryRoot: String
  let baseRef: String
  let planner: any OrchestratedAgentRunning
  let implementer: any OrchestratedAgentRunning
  let reviewer: any OrchestratedAgentRunning
  let validationCommand: Command?
  let actor: ActorID
  let sessionID: UUID
  let runID: UUID
}

private final class PlannerWorkflowState {
  var invocationCount = 0
  var iteration = 0
  var conflicts: [OrchestrationConflict] = []
}

private enum PlannerPhaseResult {
  case value(String)
  case handle(WorktreeHandle)
  case outcome(OrchestrationOutcome)
}

extension MultiAgentOrchestrator {
  // MARK: - Planner → Implementer → Reviewer

  public func runPlannerImplementerReviewer(
    objective: String,
    acceptanceCriteria: [String] = [],
    repositoryRoot: String,
    baseRef: String = "HEAD",
    planner: any OrchestratedAgentRunning,
    implementer: any OrchestratedAgentRunning,
    reviewer: any OrchestratedAgentRunning,
    validationCommand: Command? = nil,
    actor: ActorID = .orchestrator,
    sessionID: UUID = UUID()
  ) async -> OrchestrationOutcome {
    let context = PlannerWorkflowContext(
      objective: objective, acceptanceCriteria: acceptanceCriteria,
      repositoryRoot: repositoryRoot, baseRef: baseRef,
      planner: planner, implementer: implementer, reviewer: reviewer,
      validationCommand: validationCommand, actor: actor, sessionID: sessionID, runID: UUID())
    let state = PlannerWorkflowState()
    await emit(
      OrchestrationRunStartedEvent(
        runID: context.runID, pattern: .plannerImplementerReviewer,
        objective: objective, repositoryRoot: repositoryRoot),
      actor: actor, correlationID: context.runID, causationID: context.runID)

    let plannerResult = await runPlannerPhase(context: context, state: state)
    switch plannerResult {
    case .outcome(let outcome): return await finish(outcome, context: context, state: state)
    case .value(let planText):
      let implementationResult = await runImplementationPhase(
        context: context, state: state, planText: planText)
      switch implementationResult {
      case .outcome(let outcome): return await finish(outcome, context: context, state: state)
      case .handle(let handle):
        let outcome = await runReviewLoop(context: context, state: state, handle: handle)
        return await finish(outcome, context: context, state: state)
      case .value:
        return await finish(
          .failed(reason: "implementation phase returned an invalid value"),
          context: context, state: state)
      }
    case .handle:
      return await finish(
        .failed(reason: "planner phase returned an invalid handle"),
        context: context, state: state)
    }
  }

  private func runPlannerPhase(
    context: PlannerWorkflowContext,
    state: PlannerWorkflowState
  ) async -> PlannerPhaseResult {
    if let outcome = await checkBudget(
      runID: context.runID, invocationCount: state.invocationCount, actor: context.actor)
    {
      return .outcome(outcome)
    }
    state.invocationCount += 1
    await emitInvocation(
      runID: context.runID, role: .planner, backendName: context.planner.backendName,
      invocationNumber: state.invocationCount, actor: context.actor)
    let result = await Self.runToCompletion(
      agent: context.planner,
      request: OrchestratedAgentRunRequest(
        objective: Self.plannerPrompt(
          objective: context.objective, acceptanceCriteria: context.acceptanceCriteria),
        workingDirectory: context.repositoryRoot, writable: false,
        actor: context.actor, sessionID: context.sessionID,
        correlationID: context.runID, causationID: context.runID))
    switch result {
    case .succeeded(let text): return .value(text)
    case .failed(let reason):
      return .outcome(.failed(reason: "planner: \(reason)"))
    }
  }

  private func runImplementationPhase(
    context: PlannerWorkflowContext,
    state: PlannerWorkflowState,
    planText: String
  ) async -> PlannerPhaseResult {
    guard !Task.isCancelled else {
      return .outcome(.failed(reason: "orchestration run cancelled"))
    }
    let handle: WorktreeHandle
    do {
      handle = try await worktreeManager.prepareWorktree(
        taskID: context.runID, repositoryRoot: context.repositoryRoot,
        baseRef: context.baseRef, actor: context.actor, sessionID: context.sessionID)
    } catch {
      return .outcome(
        .failed(
          reason: "worktree preparation failed: \(error.localizedDescription)"))
    }
    if let outcome = await checkBudget(
      runID: context.runID, invocationCount: state.invocationCount, actor: context.actor)
    {
      return .outcome(outcome)
    }
    state.invocationCount += 1
    await emitInvocation(
      runID: context.runID, role: .implementer, backendName: context.implementer.backendName,
      invocationNumber: state.invocationCount, actor: context.actor)
    let result = await Self.runToCompletion(
      agent: context.implementer,
      request: OrchestratedAgentRunRequest(
        objective: Self.implementerPrompt(
          objective: context.objective, plan: planText,
          acceptanceCriteria: context.acceptanceCriteria),
        workingDirectory: handle.path, writable: true,
        actor: context.actor, sessionID: context.sessionID,
        correlationID: context.runID, causationID: context.runID))
    if case .failed(let reason) = result {
      return .outcome(
        .failed(
          reason: Self.failureReason("implementer: \(reason)", handle: handle)))
    }
    return .handle(handle)
  }

  private func runReviewLoop(
    context: PlannerWorkflowContext,
    state: PlannerWorkflowState,
    handle: WorktreeHandle
  ) async -> OrchestrationOutcome {
    while state.iteration < configuration.maxReviewIterations {
      state.iteration += 1
      if Task.isCancelled {
        return .failed(
          reason: Self.failureReason(
            "orchestration run cancelled", handle: handle))
      }
      let iterationResult = await reviewIteration(
        context: context, state: state, handle: handle)
      switch iterationResult {
      case .outcome(let outcome): return outcome
      case .value: continue
      case .handle: return .failed(reason: "invalid review phase result")
      }
    }
    let outcome = OrchestrationOutcome.escalated(
      worktreePath: handle.path, branch: handle.branch,
      iterations: state.iteration, conflicts: state.conflicts)
    await emit(
      OrchestrationEscalatedEvent(
        runID: context.runID, iterations: state.iteration,
        conflictCount: state.conflicts.count),
      actor: context.actor, correlationID: context.runID, causationID: context.runID)
    return outcome
  }

  private func reviewIteration(
    context: PlannerWorkflowContext,
    state: PlannerWorkflowState,
    handle: WorktreeHandle
  ) async -> PlannerPhaseResult {
    let diffText =
      (try? await worktreeManager.diff(
        taskID: context.runID, actor: context.actor, sessionID: context.sessionID))
      ?? "(diff unavailable)"
    let validation = await validationOutcome(context: context, handle: handle)
    guard
      let reviewerResult = await invokeReviewer(
        context: context, state: state, handle: handle,
        diffText: diffText, validation: validation)
    else {
      return .outcome(.budgetExceeded(reason: "agent invocation budget exhausted"))
    }
    switch reviewerResult {
    case .failed(let reason):
      return .outcome(
        .failed(
          reason: Self.failureReason("reviewer: \(reason)", handle: handle)))
    case .succeeded(let reviewText):
      let verdict = ReviewVerdictParser.parse(reviewText)
      let reviewerApproved = if case .approve = verdict { true } else { false }
      let evidenceApproved = reviewerApproved && (validation?.passed ?? true)
      if evidenceApproved {
        return .outcome(
          .approved(
            worktreePath: handle.path, branch: handle.branch, iterations: state.iteration))
      }
      state.conflicts.append(
        OrchestrationConflict(
          iteration: state.iteration, verdict: verdict,
          validationPassed: validation?.passed))
      await emit(
        OrchestrationConflictRecordedEvent(
          runID: context.runID, iteration: state.iteration,
          reviewerApproved: reviewerApproved,
          reviewerReason: Self.reasonText(for: verdict), validationPassed: validation?.passed),
        actor: context.actor, correlationID: context.runID, causationID: context.runID)
      guard state.iteration < configuration.maxReviewIterations else { return .value("") }
      return await runCorrector(
        context: context, state: state, handle: handle,
        verdict: verdict, validation: validation)
    }
  }

  private func validationOutcome(
    context: PlannerWorkflowContext,
    handle: WorktreeHandle
  ) async -> ValidationOutcome? {
    guard let validationCommand = context.validationCommand else { return nil }
    return await runValidation(
      command: validationCommand, workingDirectory: handle.path,
      actor: context.actor, sessionID: context.sessionID, correlationID: context.runID)
  }

  private func invokeReviewer(
    context: PlannerWorkflowContext,
    state: PlannerWorkflowState,
    handle: WorktreeHandle,
    diffText: String,
    validation: ValidationOutcome?
  ) async -> MultiAgentOrchestrator.RoleRunResult? {
    guard
      await checkBudget(
        runID: context.runID, invocationCount: state.invocationCount,
        actor: context.actor) == nil
    else { return nil }
    state.invocationCount += 1
    await emitInvocation(
      runID: context.runID, role: .reviewer, backendName: context.reviewer.backendName,
      invocationNumber: state.invocationCount, actor: context.actor)
    return await Self.runToCompletion(
      agent: context.reviewer,
      request: OrchestratedAgentRunRequest(
        objective: Self.reviewerPrompt(
          objective: context.objective, acceptanceCriteria: context.acceptanceCriteria,
          diff: diffText, validation: validation),
        workingDirectory: handle.path, writable: false,
        actor: context.actor, sessionID: context.sessionID,
        correlationID: context.runID, causationID: context.runID))
  }

  private func runCorrector(
    context: PlannerWorkflowContext,
    state: PlannerWorkflowState,
    handle: WorktreeHandle,
    verdict: ReviewVerdict,
    validation: ValidationOutcome?
  ) async -> PlannerPhaseResult {
    guard
      await checkBudget(
        runID: context.runID, invocationCount: state.invocationCount,
        actor: context.actor) == nil
    else {
      return .outcome(.budgetExceeded(reason: "agent invocation budget exhausted"))
    }
    state.invocationCount += 1
    await emitInvocation(
      runID: context.runID, role: .implementer, backendName: context.implementer.backendName,
      invocationNumber: state.invocationCount, actor: context.actor)
    let result = await Self.runToCompletion(
      agent: context.implementer,
      request: OrchestratedAgentRunRequest(
        objective: Self.correctorPrompt(
          objective: context.objective, feedback: Self.reasonText(for: verdict),
          validation: validation),
        workingDirectory: handle.path, writable: true,
        actor: context.actor, sessionID: context.sessionID,
        correlationID: context.runID, causationID: context.runID))
    if case .failed(let reason) = result {
      return .outcome(
        .failed(
          reason: Self.failureReason("corrector: \(reason)", handle: handle)))
    }
    return .value("")
  }

  private func emitInvocation(
    runID: UUID,
    role: OrchestrationAgentInvokedEvent.Role,
    backendName: String,
    invocationNumber: Int,
    actor: ActorID
  ) async {
    await emit(
      OrchestrationAgentInvokedEvent(
        runID: runID, role: role, backendName: backendName,
        invocationNumber: invocationNumber),
      actor: actor, correlationID: runID, causationID: runID)
  }

  private func finish(
    _ outcome: OrchestrationOutcome,
    context: PlannerWorkflowContext,
    state: PlannerWorkflowState
  ) async -> OrchestrationOutcome {
    await completeRun(
      runID: context.runID, outcome: outcome, iterations: state.iteration,
      actor: context.actor)
    return outcome
  }
}
