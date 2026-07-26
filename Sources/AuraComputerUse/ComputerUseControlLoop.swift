import AuraCore
import AuraPolicy
import AuraScreen
import Foundation

/// Drives one bounded Observe → Plan → Policy → Act → Verify computer-use
/// session against a single approved window/application, per
/// `docs/subsystems/10_COMPUTER_USE.md`.
///
/// Every iteration: capture the approved window (`ScreenContextEngine`,
/// already policy-gated and redacted per Phase 17), check for an identity
/// change or unexpected modal, check for no-progress, ask the injected
/// `ComputerUsePlanning` conformer for a bounded plan, re-check policy for
/// each step immediately before executing it, execute through
/// `UIActionExecuting`, and record whether progress was observed. The loop
/// never sees or evaluates anything but typed `ComputerUsePlan`/
/// `ComputerUseActionStep` values — the planner boundary is what makes "no
/// raw model output becomes an executable action" true by construction.
public actor ComputerUseControlLoop {
  private let screenEngine: ScreenContextEngine
  private let policyEngine: PolicyEngine
  private let actionExecutor: any UIActionExecuting
  private let modalDetector: any ModalDialogDetecting
  private let secureFieldDetector: any SecureFieldDetecting
  private let emergencyStop: EmergencyStopController
  private let eventBus: AuraEventBus
  private let configuration: ComputerUseConfiguration

  public init(
    screenEngine: ScreenContextEngine,
    policyEngine: PolicyEngine,
    actionExecutor: any UIActionExecuting,
    modalDetector: any ModalDialogDetecting,
    secureFieldDetector: any SecureFieldDetecting,
    emergencyStop: EmergencyStopController,
    eventBus: AuraEventBus = .shared,
    configuration: ComputerUseConfiguration = ComputerUseConfiguration()
  ) {
    self.screenEngine = screenEngine
    self.policyEngine = policyEngine
    self.actionExecutor = actionExecutor
    self.modalDetector = modalDetector
    self.secureFieldDetector = secureFieldDetector
    self.emergencyStop = emergencyStop
    self.eventBus = eventBus
    self.configuration = configuration
  }

  /// Run one bounded control loop session against `target`. Always returns —
  /// never blocks indefinitely — because every branch either executes a
  /// bounded plan and loops, or returns a terminal `ComputerUseLoopOutcome`.
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
        runID: runID, windowID: target.windowID, appBundleIdentifier: target.appBundleIdentifier,
        objective: objective),
      correlationID: runID, actor: actor)

    var iteration = 0
    var previousContentHash: String?
    var consecutiveNoProgress = 0
    var previousSteps: [ComputerUseActionStep] = []

    while iteration < configuration.maxIterations {
      iteration += 1
      let correlationID = UUID()

      if Task.isCancelled {
        let outcome = ComputerUseLoopOutcome.failed(
          reason: "computer-use control loop cancelled", iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      if await emergencyStop.isActive {
        let outcome = ComputerUseLoopOutcome.emergencyStopped(iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      // MARK: Observe

      let captureOutcome: ScreenCaptureOutcome
      do {
        captureOutcome = try await screenEngine.captureWindow(
          windowID: target.windowID, actor: actor, sessionID: sessionID,
          correlationID: correlationID)
      } catch {
        let outcome = ComputerUseLoopOutcome.failed(
          reason: "observation failed: \(error.localizedDescription)", iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      guard case .captured(let observation) = captureOutcome else {
        var reason = "capture failed"
        if case .blocked(let blockReason) = captureOutcome {
          reason = "capture blocked: \(blockReason.rawValue)"
        }
        let outcome = ComputerUseLoopOutcome.failed(reason: reason, iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      await emit(
        ComputerUseObservationEvent(
          runID: runID, iteration: iteration, observationID: observation.id,
          contentHash: observation.contentHash),
        correlationID: correlationID, actor: actor)

      guard observation.appBundleIdentifier == target.appBundleIdentifier else {
        await emit(
          ComputerUseIdentityChangedEvent(
            runID: runID, iteration: iteration, expectedBundleIdentifier: target.appBundleIdentifier,
            observedBundleIdentifier: observation.appBundleIdentifier),
          correlationID: correlationID, actor: actor)
        let outcome = ComputerUseLoopOutcome.identityChanged(iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      if let modalBundleID = await modalDetector.detectUnexpectedModal(
        expectedBundleIdentifier: target.appBundleIdentifier)
      {
        await emit(
          ComputerUseModalDialogDetectedEvent(
            runID: runID, iteration: iteration, dialogBundleIdentifier: modalBundleID),
          correlationID: correlationID, actor: actor)
        let outcome = ComputerUseLoopOutcome.unexpectedModalDialog(iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      // MARK: Verify (progress since the previous iteration's observation)

      let progressed = previousContentHash.map { $0 != observation.contentHash } ?? true
      consecutiveNoProgress = progressed ? 0 : consecutiveNoProgress + 1
      previousContentHash = observation.contentHash
      await emit(
        ComputerUseVerifyEvent(
          runID: runID, iteration: iteration, progressed: progressed,
          consecutiveNoProgressCount: consecutiveNoProgress),
        correlationID: correlationID, actor: actor)

      guard consecutiveNoProgress < configuration.noProgressIterationThreshold else {
        let outcome = ComputerUseLoopOutcome.noProgress(iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      // MARK: Plan

      let plan = await planner.propose(
        observation: observation, objective: objective, previousSteps: previousSteps)

      if plan.isEmpty {
        let outcome = ComputerUseLoopOutcome.completed(iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      guard plan.steps.count <= configuration.maxStepsPerPlan else {
        let reason =
          "plan step count \(plan.steps.count) exceeds configured maximum \(configuration.maxStepsPerPlan)"
        await emit(
          ComputerUseInvalidPlanEvent(runID: runID, iteration: iteration, reason: reason),
          correlationID: correlationID, actor: actor)
        let outcome = ComputerUseLoopOutcome.invalidPlan(reason: reason, iterations: iteration)
        await complete(runID: runID, outcome: outcome, actor: actor)
        return outcome
      }

      await emit(
        ComputerUsePlanGeneratedEvent(
          runID: runID, iteration: iteration, stepCount: plan.steps.count,
          intents: plan.steps.map(\.semanticIntent)),
        correlationID: correlationID, actor: actor)

      // MARK: Policy + Act, one step at a time

      var lastActionAt: Date?

      stepLoop: for step in plan.steps {
        if Task.isCancelled {
          let outcome = ComputerUseLoopOutcome.failed(
            reason: "computer-use control loop cancelled", iterations: iteration)
          await complete(runID: runID, outcome: outcome, actor: actor)
          return outcome
        }

        if await emergencyStop.isActive {
          let outcome = ComputerUseLoopOutcome.emergencyStopped(iterations: iteration)
          await complete(runID: runID, outcome: outcome, actor: actor)
          return outcome
        }

        guard step.targetAppBundleIdentifier == target.appBundleIdentifier else {
          await emitStepBlocked(
            runID: runID, iteration: iteration, step: step, reason: .identityMismatch,
            correlationID: correlationID, actor: actor)
          let outcome = ComputerUseLoopOutcome.identityChanged(iterations: iteration)
          await complete(runID: runID, outcome: outcome, actor: actor)
          return outcome
        }

        guard step.anchor.isValid else {
          await emitStepBlocked(
            runID: runID, iteration: iteration, step: step, reason: .invalidAnchor,
            correlationID: correlationID, actor: actor)
          let outcome = ComputerUseLoopOutcome.invalidPlan(
            reason: "step \(step.id) has an invalid anchor", iterations: iteration)
          await complete(runID: runID, outcome: outcome, actor: actor)
          return outcome
        }

        // Never interact with password fields — an absolute rule, not a
        // per-grant confirmation. Aborts the remaining steps of this plan
        // but not the whole run; the field may not be focused next
        // iteration.
        let secureFieldFocused = await secureFieldDetector.isSecureFieldFocused(
          applicationBundleIdentifier: target.appBundleIdentifier)
        if secureFieldFocused {
          await emitStepBlocked(
            runID: runID, iteration: iteration, step: step, reason: .secureFieldFocused,
            correlationID: correlationID, actor: actor)
          break stepLoop
        }

        // Rate limiting: skip just this one step, keep processing the rest
        // of the plan — a throttle, not a safety violation.
        if let lastActionAt,
          Date().timeIntervalSince(lastActionAt) < configuration.minActionIntervalSeconds
        {
          await emitStepBlocked(
            runID: runID, iteration: iteration, step: step, reason: .rateLimited,
            correlationID: correlationID, actor: actor)
          continue stepLoop
        }

        let capability = Capability.forComputerUse(intent: step.semanticIntent)
        let policyRequest = PolicyEvaluationRequest(
          capability: capability,
          actor: actor,
          target: PolicyTarget(appID: step.targetAppBundleIdentifier),
          sessionID: sessionID,
          correlationID: correlationID,
          causationID: correlationID
        )
        let decision = await policyEngine.evaluate(policyRequest)

        switch decision {
        case .deny:
          await emitStepBlocked(
            runID: runID, iteration: iteration, step: step, reason: .policyDenied,
            correlationID: correlationID, actor: actor)
          break stepLoop

        case .confirm(let challenge, _):
          await emitStepBlocked(
            runID: runID, iteration: iteration, step: step,
            reason: .mandatoryConfirmationRequired, correlationID: correlationID, actor: actor)
          let outcome = ComputerUseLoopOutcome.confirmationRequired(
            challenge: challenge, iterations: iteration)
          await complete(runID: runID, outcome: outcome, actor: actor)
          return outcome

        case .allow:
          // Hard, non-bypassable guard: a step whose semantic intent is one
          // of the named destructive categories must never execute on a
          // bare `.allow` — even one reached via an overly permissive grant
          // configured with `.none` confirmation. See
          // `ComputerUseSemanticIntent.mandatoryConfirmationIntents`.
          if step.semanticIntent.requiresMandatoryConfirmation {
            await emit(
              ComputerUseMandatoryConfirmationBlockedEvent(
                runID: runID, iteration: iteration, stepID: step.id,
                semanticIntent: step.semanticIntent),
              correlationID: correlationID, actor: actor)
            await emitStepBlocked(
              runID: runID, iteration: iteration, step: step,
              reason: .mandatoryConfirmationRequired, correlationID: correlationID, actor: actor)
            let outcome = ComputerUseLoopOutcome.mandatoryConfirmationBlocked(
              intent: step.semanticIntent, iterations: iteration)
            await complete(runID: runID, outcome: outcome, actor: actor)
            return outcome
          }

          do {
            let result = try await actionExecutor.execute(
              step.kind, anchor: step.anchor,
              applicationBundleIdentifier: step.targetAppBundleIdentifier,
              windowFrameX: observation.frameX, windowFrameY: observation.frameY,
              windowFrameWidth: observation.frameWidth, windowFrameHeight: observation.frameHeight)
            lastActionAt = Date()
            previousSteps.append(step)
            await emit(
              ComputerUseStepEvent(
                runID: runID, iteration: iteration, stepID: step.id,
                semanticIntent: step.semanticIntent,
                usedAccessibilityAnchor: result.usedAccessibilityAnchor, executed: true,
                blockReason: nil),
              correlationID: correlationID, actor: actor)
          } catch {
            await emitStepBlocked(
              runID: runID, iteration: iteration, step: step, reason: .executionFailed,
              correlationID: correlationID, actor: actor)
            break stepLoop
          }
        }
      }
    }

    let outcome = ComputerUseLoopOutcome.iterationBudgetExhausted(iterations: iteration)
    await complete(runID: runID, outcome: outcome, actor: actor)
    return outcome
  }

  // MARK: - Event helpers

  private func emitStepBlocked(
    runID: UUID,
    iteration: Int,
    step: ComputerUseActionStep,
    reason: ComputerUseStepBlockReason,
    correlationID: UUID,
    actor: ActorID
  ) async {
    await emit(
      ComputerUseStepEvent(
        runID: runID, iteration: iteration, stepID: step.id, semanticIntent: step.semanticIntent,
        usedAccessibilityAnchor: false, executed: false, blockReason: reason),
      correlationID: correlationID, actor: actor)
  }

  private func complete(runID: UUID, outcome: ComputerUseLoopOutcome, actor: ActorID) async {
    await emit(
      ComputerUseLoopCompletedEvent(
        runID: runID, outcomeDescription: Self.describe(outcome),
        iterations: Self.iterations(of: outcome)),
      correlationID: runID, actor: actor)
  }

  private func emit<Payload: EventPayload>(_ payload: Payload, correlationID: UUID, actor: ActorID)
    async
  {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: correlationID, actor: actor,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }

  private static func describe(_ outcome: ComputerUseLoopOutcome) -> String {
    switch outcome {
    case .completed: return "completed"
    case .noProgress: return "noProgress"
    case .iterationBudgetExhausted: return "iterationBudgetExhausted"
    case .emergencyStopped: return "emergencyStopped"
    case .unexpectedModalDialog: return "unexpectedModalDialog"
    case .identityChanged: return "identityChanged"
    case .confirmationRequired: return "confirmationRequired"
    case .mandatoryConfirmationBlocked(let intent, _):
      return "mandatoryConfirmationBlocked(\(intent.rawValue))"
    case .invalidPlan(let reason, _): return "invalidPlan(\(reason))"
    case .failed(let reason, _): return "failed(\(reason))"
    }
  }

  private static func iterations(of outcome: ComputerUseLoopOutcome) -> Int {
    switch outcome {
    case .completed(let iterations): return iterations
    case .noProgress(let iterations): return iterations
    case .iterationBudgetExhausted(let iterations): return iterations
    case .emergencyStopped(let iterations): return iterations
    case .unexpectedModalDialog(let iterations): return iterations
    case .identityChanged(let iterations): return iterations
    case .confirmationRequired(_, let iterations): return iterations
    case .mandatoryConfirmationBlocked(_, let iterations): return iterations
    case .invalidPlan(_, let iterations): return iterations
    case .failed(_, let iterations): return iterations
    }
  }
}
