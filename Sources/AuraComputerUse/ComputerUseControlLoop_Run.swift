import AuraCore
import AuraPolicy
import AuraScreen
import Foundation

private struct ComputerUseRunContext {
  let target: ComputerUseSessionTarget
  let objective: String
  let planner: any ComputerUsePlanning
  let actor: ActorID
  let sessionID: UUID
  let runID: UUID
  var iteration: Int = 0
}

private struct ComputerUseRunState {
  var iteration: Int = 0
  var previousContentHash: String?
  var consecutiveNoProgress = 0
  var previousSteps: [ComputerUseActionStep] = []
}

private struct ComputerUseIterationResult {
  let state: ComputerUseRunState
  let outcome: ComputerUseLoopOutcome?
}

private enum ComputerUseStepDecision {
  case executed(UIActionExecutionResult)
  case skip
  case stop
  case terminal(ComputerUseLoopOutcome)
}

private enum ComputerUseStepPreflight {
  case proceed
  case skip
  case stop
  case terminal(ComputerUseLoopOutcome)
}

private enum ComputerUseObservationDecision {
  case captured(ScreenObservation)
  case terminal(ComputerUseLoopOutcome)
}

extension ComputerUseControlLoop {
  /// Run one bounded control loop session against `target`.
  public func run(
    target: ComputerUseSessionTarget,
    objective: String,
    planner: any ComputerUsePlanning,
    actor: ActorID = .computerUse,
    sessionID: UUID = UUID()
  ) async -> ComputerUseLoopOutcome {
    let runID = UUID()
    await emit(
      ComputerUseLoopStartedEvent(
        runID: runID, windowID: target.windowID,
        appBundleIdentifier: target.appBundleIdentifier, objective: objective),
      correlationID: runID, actor: actor)
    var context = ComputerUseRunContext(
      target: target, objective: objective, planner: planner,
      actor: actor, sessionID: sessionID, runID: runID)
    var state = ComputerUseRunState()
    while state.iteration < configuration.maxIterations {
      state.iteration += 1
      context.iteration = state.iteration
      let result = await runIteration(context: context, state: state)
      state = result.state
      if let outcome = result.outcome {
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }
    }
    let outcome = ComputerUseLoopOutcome.iterationBudgetExhausted(iterations: state.iteration)
    await complete(runID: runID, outcome: outcome, actor: actor)
    return outcome
  }

  private func runIteration(
    context: ComputerUseRunContext,
    state: ComputerUseRunState
  ) async -> ComputerUseIterationResult {
    if Task.isCancelled {
      return terminal(state, reason: "computer-use control loop cancelled")
    }
    if await emergencyStop.isActive {
      return ComputerUseIterationResult(
        state: state, outcome: .emergencyStopped(iterations: state.iteration))
    }
    let correlationID = UUID()
    let observationDecision = await observe(context: context, correlationID: correlationID)
    let observation: ScreenObservation
    switch observationDecision {
    case .captured(let value): observation = value
    case .terminal(let outcome):
      return ComputerUseIterationResult(state: state, outcome: outcome)
    }
    guard observation.appBundleIdentifier == context.target.appBundleIdentifier else {
      await emit(
        ComputerUseIdentityChangedEvent(
          runID: context.runID, iteration: state.iteration,
          expectedBundleIdentifier: context.target.appBundleIdentifier,
          observedBundleIdentifier: observation.appBundleIdentifier),
        correlationID: correlationID, actor: context.actor)
      return ComputerUseIterationResult(
        state: state, outcome: .identityChanged(iterations: state.iteration))
    }
    var nextState = state
    let progressed = state.previousContentHash.map { $0 != observation.contentHash } ?? true
    nextState.consecutiveNoProgress = progressed ? 0 : state.consecutiveNoProgress + 1
    nextState.previousContentHash = observation.contentHash
    await emit(
      ComputerUseVerifyEvent(
        runID: context.runID, iteration: state.iteration, progressed: progressed,
        consecutiveNoProgressCount: nextState.consecutiveNoProgress),
      correlationID: correlationID, actor: context.actor)
    guard nextState.consecutiveNoProgress < configuration.noProgressIterationThreshold else {
      return ComputerUseIterationResult(
        state: nextState, outcome: .noProgress(iterations: state.iteration))
    }

    return await planAndExecute(
      observation: observation, context: context,
      correlationID: correlationID, state: nextState)
  }

  private func planAndExecute(
    observation: ScreenObservation,
    context: ComputerUseRunContext,
    correlationID: UUID,
    state: ComputerUseRunState
  ) async -> ComputerUseIterationResult {
    let plan = await context.planner.propose(
      observation: observation,
      objective: context.objective,
      previousSteps: state.previousSteps)
    if plan.isEmpty {
      return ComputerUseIterationResult(
        state: state, outcome: .completed(iterations: state.iteration))
    }
    guard plan.steps.count <= configuration.maxStepsPerPlan else {
      let reason =
        "plan step count \(plan.steps.count) exceeds configured maximum "
        + "\(configuration.maxStepsPerPlan)"
      await emit(
        ComputerUseInvalidPlanEvent(
          runID: context.runID, iteration: state.iteration, reason: reason),
        correlationID: correlationID, actor: context.actor)
      return ComputerUseIterationResult(
        state: state, outcome: .invalidPlan(reason: reason, iterations: state.iteration))
    }
    await emit(
      ComputerUsePlanGeneratedEvent(
        runID: context.runID, iteration: state.iteration,
        stepCount: plan.steps.count, intents: plan.steps.map(\.semanticIntent)),
      correlationID: correlationID, actor: context.actor)
    return await executePlan(
      plan: plan, observation: observation, context: context,
      correlationID: correlationID, state: state)
  }

  private func observe(
    context: ComputerUseRunContext,
    correlationID: UUID
  ) async -> ComputerUseObservationDecision {
    let captureOutcome: ScreenCaptureOutcome
    do {
      captureOutcome = try await screenEngine.captureWindow(
        windowID: context.target.windowID,
        actor: context.actor,
        sessionID: context.sessionID,
        correlationID: correlationID)
    } catch {
      return .terminal(
        .failed(
          reason: "observation failed: \(error.localizedDescription)",
          iterations: context.iteration))
    }
    guard case .captured(let observation) = captureOutcome else {
      let reason: String
      if case .blocked(let blockReason) = captureOutcome {
        reason = "capture blocked: \(blockReason.rawValue)"
      } else {
        reason = "capture failed"
      }
      return .terminal(.failed(reason: reason, iterations: context.iteration))
    }
    await emit(
      ComputerUseObservationEvent(
        runID: context.runID, iteration: context.iteration,
        observationID: observation.id, contentHash: observation.contentHash),
      correlationID: correlationID, actor: context.actor)
    if let modalBundleID = await modalDetector.detectUnexpectedModal(
      expectedBundleIdentifier: context.target.appBundleIdentifier)
    {
      await emit(
        ComputerUseModalDialogDetectedEvent(
          runID: context.runID, iteration: context.iteration,
          dialogBundleIdentifier: modalBundleID),
        correlationID: correlationID, actor: context.actor)
      return .terminal(.unexpectedModalDialog(iterations: context.iteration))
    }
    return .captured(observation)
  }

  private func executePlan(
    plan: ComputerUsePlan,
    observation: ScreenObservation,
    context: ComputerUseRunContext,
    correlationID: UUID,
    state: ComputerUseRunState
  ) async -> ComputerUseIterationResult {
    var nextState = state
    var lastActionAt: Date?
    for step in plan.steps {
      let decision = await executeStep(
        step: step,
        observation: observation,
        context: context,
        correlationID: correlationID,
        lastActionAt: lastActionAt)
      switch decision {
      case .executed(let result):
        lastActionAt = Date()
        nextState.previousSteps.append(step)
        await emit(
          ComputerUseStepEvent(
            runID: context.runID, iteration: state.iteration, stepID: step.id,
            semanticIntent: step.semanticIntent,
            usedAccessibilityAnchor: result.usedAccessibilityAnchor,
            executed: true, blockReason: nil),
          correlationID: correlationID, actor: context.actor)
      case .skip: continue
      case .stop: return ComputerUseIterationResult(state: nextState, outcome: nil)
      case .terminal(let outcome):
        return ComputerUseIterationResult(state: nextState, outcome: outcome)
      }
    }
    return ComputerUseIterationResult(state: nextState, outcome: nil)
  }

  private func executeStep(
    step: ComputerUseActionStep,
    observation: ScreenObservation,
    context: ComputerUseRunContext,
    correlationID: UUID,
    lastActionAt: Date?
  ) async -> ComputerUseStepDecision {
    switch await preflight(
      step: step, context: context, correlationID: correlationID, lastActionAt: lastActionAt)
    {
    case .proceed: break
    case .skip: return .skip
    case .stop: return .stop
    case .terminal(let outcome): return .terminal(outcome)
    }
    let capability = Capability.forComputerUse(intent: step.semanticIntent)
    let policyRequest = PolicyEvaluationRequest(
      capability: capability,
      actor: context.actor,
      target: PolicyTarget(appID: step.targetAppBundleIdentifier),
      sessionID: context.sessionID,
      correlationID: correlationID,
      causationID: correlationID)
    let decision = await policyEngine.evaluate(policyRequest)
    switch decision {
    case .deny:
      await emitStepBlocked(
        StepBlockInput(
          runID: context.runID, iteration: contextIteration(context),
          step: step, reason: .policyDenied),
        correlationID: correlationID, actor: context.actor)
      return .stop
    case .confirm(let challenge, _):
      await emitStepBlocked(
        StepBlockInput(
          runID: context.runID, iteration: contextIteration(context),
          step: step, reason: .mandatoryConfirmationRequired),
        correlationID: correlationID, actor: context.actor)
      return .terminal(
        .confirmationRequired(
          challenge: challenge, iterations: contextIteration(context)))
    case .allow:
      if step.semanticIntent.requiresMandatoryConfirmation {
        await emit(
          ComputerUseConfirmationBlockedEvent(
            runID: context.runID, iteration: contextIteration(context),
            stepID: step.id, semanticIntent: step.semanticIntent),
          correlationID: correlationID, actor: context.actor)
        await emitStepBlocked(
          StepBlockInput(
            runID: context.runID, iteration: contextIteration(context),
            step: step, reason: .mandatoryConfirmationRequired),
          correlationID: correlationID, actor: context.actor)
        return .terminal(
          .mandatoryConfirmationBlocked(
            intent: step.semanticIntent, iterations: contextIteration(context)))
      }
      return await performAction(
        step: step, observation: observation, context: context, correlationID: correlationID)
    }
  }

  private func preflight(
    step: ComputerUseActionStep,
    context: ComputerUseRunContext,
    correlationID: UUID,
    lastActionAt: Date?
  ) async -> ComputerUseStepPreflight {
    let iteration = contextIteration(context)
    if Task.isCancelled {
      return .terminal(
        .failed(
          reason: "computer-use control loop cancelled", iterations: iteration))
    }
    if await emergencyStop.isActive { return .terminal(.emergencyStopped(iterations: iteration)) }
    guard step.targetAppBundleIdentifier == context.target.appBundleIdentifier else {
      await emitStepBlocked(
        StepBlockInput(
          runID: context.runID, iteration: iteration, step: step, reason: .identityMismatch),
        correlationID: correlationID, actor: context.actor)
      return .terminal(.identityChanged(iterations: iteration))
    }
    guard step.anchor.isValid else {
      await emitStepBlocked(
        StepBlockInput(
          runID: context.runID, iteration: iteration, step: step, reason: .invalidAnchor),
        correlationID: correlationID, actor: context.actor)
      return .terminal(
        .invalidPlan(
          reason: "step \(step.id) has an invalid anchor", iterations: iteration))
    }
    if await secureFieldDetector.isSecureFieldFocused(
      applicationBundleIdentifier: context.target.appBundleIdentifier)
    {
      await emitStepBlocked(
        StepBlockInput(
          runID: context.runID, iteration: iteration, step: step, reason: .secureFieldFocused),
        correlationID: correlationID, actor: context.actor)
      return .stop
    }
    if let lastActionAt,
      Date().timeIntervalSince(lastActionAt) < configuration.minActionIntervalSeconds
    {
      await emitStepBlocked(
        StepBlockInput(
          runID: context.runID, iteration: iteration, step: step, reason: .rateLimited),
        correlationID: correlationID, actor: context.actor)
      return .skip
    }
    return .proceed
  }

  private func performAction(
    step: ComputerUseActionStep,
    observation: ScreenObservation,
    context: ComputerUseRunContext,
    correlationID: UUID
  ) async -> ComputerUseStepDecision {
    do {
      let result = try await actionExecutor.execute(
        step.kind,
        anchor: step.anchor,
        applicationBundleIdentifier: step.targetAppBundleIdentifier,
        windowFrame: UIWindowFrame(
          originX: observation.frameX, originY: observation.frameY,
          width: observation.frameWidth, height: observation.frameHeight))
      return .executed(result)
    } catch {
      await emitStepBlocked(
        StepBlockInput(
          runID: context.runID, iteration: contextIteration(context),
          step: step, reason: .executionFailed),
        correlationID: correlationID, actor: context.actor)
      return .stop
    }
  }

  private func contextIteration(_ context: ComputerUseRunContext) -> Int {
    context.iteration
  }

  private func terminal(
    _ state: ComputerUseRunState,
    reason: String
  ) -> ComputerUseIterationResult {
    ComputerUseIterationResult(
      state: state,
      outcome: .failed(reason: reason, iterations: state.iteration))
  }
}
