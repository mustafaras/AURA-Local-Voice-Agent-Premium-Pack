import AuraComputerUse
import AuraCore
import AuraPolicy
import AuraScreen
import CoreGraphics
import Foundation
import Testing

private let targetApp = "com.example.app"

private func makeLoop(
  windows: [ScreenWindowDescriptor],
  policyConfiguration: PolicyConfiguration = PolicyConfiguration(),
  executor: ScriptedActionExecutor = ScriptedActionExecutor(),
  modalDetector: ScriptedModalDetector = ScriptedModalDetector(),
  secureFieldDetector: ScriptedSecureFieldDetector = ScriptedSecureFieldDetector(),
  emergencyStop: EmergencyStopController = EmergencyStopController(eventBus: .shared),
  configuration: ComputerUseConfiguration = ComputerUseConfiguration(
    maxIterations: 5, maxStepsPerPlan: 3, noProgressIterationThreshold: 3,
    minActionIntervalSeconds: 0),
  imageToReturn: CGImage = makeTestImage()
) async throws -> ComputerUseControlLoop {
  let policyEngine = try await makePolicyEngine(configuration: policyConfiguration)
  let screenEngine = makeScreenEngine(
    windows: windows, policyEngine: policyEngine, imageToReturn: imageToReturn)
  return ComputerUseControlLoop(
    screenEngine: screenEngine, policyEngine: policyEngine, actionExecutor: executor,
    modalDetector: modalDetector, secureFieldDetector: secureFieldDetector,
    emergencyStop: emergencyStop, eventBus: AuraEventBus.shared, configuration: configuration)
}

private func target(windowID: Int = 1) -> ComputerUseSessionTarget {
  ComputerUseSessionTarget(windowID: windowID, appBundleIdentifier: targetApp)
}

// MARK: - Bounded and stoppable

@Test("Loop completes when the planner signals done with an empty plan")
func loopCompletesOnEmptyPlan() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let loop = try await makeLoop(windows: windows)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan())

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .completed(let iterations) = outcome else {
    Issue.record("expected completed, got \(outcome)")
    return
  }
  #expect(iterations == 1)
}

@Test("Loop stops at the configured iteration ceiling and never runs unbounded")
func loopStopsAtMaxIterations() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  // A different image per call is impossible with a static fixture, so a
  // never-empty, always-`.observe` plan with a changing distinct image would
  // be needed to avoid hitting no-progress first; instead configure a
  // no-progress threshold above the iteration ceiling so the iteration bound
  // is the one that actually fires.
  let configuration = ComputerUseConfiguration(
    maxIterations: 4, maxStepsPerPlan: 3, noProgressIterationThreshold: 100,
    minActionIntervalSeconds: 0)
  let loop = try await makeLoop(windows: windows, configuration: configuration)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .iterationBudgetExhausted(let iterations) = outcome else {
    Issue.record("expected iterationBudgetExhausted, got \(outcome)")
    return
  }
  #expect(iterations == 4)
  #expect(await planner.proposeCallCount == 4)
}

@Test("A plan exceeding the maximum step count is rejected outright, not truncated")
func loopRejectsOversizedPlan() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let configuration = ComputerUseConfiguration(
    maxIterations: 5, maxStepsPerPlan: 2, noProgressIterationThreshold: 5,
    minActionIntervalSeconds: 0)
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(windows: windows, executor: executor, configuration: configuration)
  let oversizedPlan = ComputerUsePlan(steps: [
    makeStep(intent: .observe), makeStep(intent: .observe), makeStep(intent: .observe),
  ])
  let planner = ScriptedPlanner(repeating: oversizedPlan)

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .invalidPlan = outcome else {
    Issue.record("expected invalidPlan, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 0)
}

@Test("A step anchor with an out-of-bounds coordinate is rejected, not clamped")
func loopRejectsInvalidCoordinateAnchor() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(windows: windows, executor: executor)
  let badAnchor = UIAnchor(fallbackNormalizedX: 1.4, fallbackNormalizedY: 0.2)
  let planner = ScriptedPlanner(
    repeating: ComputerUsePlan(steps: [makeStep(anchor: badAnchor, intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .invalidPlan = outcome else {
    Issue.record("expected invalidPlan, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 0)
}

// MARK: - Destructive-action default deny

@Test("A destructive-intent step is blocked by default deny without any grant")
func destructiveStepBlockedByDefaultDenyWithoutGrant() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let configuration = ComputerUseConfiguration(
    maxIterations: 5, maxStepsPerPlan: 3, noProgressIterationThreshold: 3,
    minActionIntervalSeconds: 0)
  // Default PolicyConfiguration denies .destructive by default with no grant.
  let loop = try await makeLoop(windows: windows, executor: executor, configuration: configuration)
  let planner = ScriptedPlanner(
    repeating: ComputerUsePlan(steps: [makeStep(intent: .delete)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  #expect(await executor.executeCallCount == 0)
  guard case .noProgress = outcome else {
    Issue.record("expected noProgress (nothing ever executed), got \(outcome)")
    return
  }
}

@Test(
  "A mandatory-confirmation intent never executes even when a grant permits it with no confirmation"
)
func mandatoryConfirmationIntentNeverExecutesDespitePermissiveGrant() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let policyEngine = try await makePolicyEngine()
  // Deliberately overly-permissive grant: `.none` confirmation for the
  // destructive computer-use capability. The control loop must still refuse
  // to execute — this is the hard, non-bypassable guard, not merely relying
  // on the policy engine's own confirmation semantics.
  try await policyEngine.issueGrant(
    Grant(
      capability: .computerUseDestructiveAct, patterns: [.any],
      confirmationRequirement: .none))
  let screenEngine = makeScreenEngine(windows: windows, policyEngine: policyEngine)
  let loop = ComputerUseControlLoop(
    screenEngine: screenEngine, policyEngine: policyEngine, actionExecutor: executor,
    modalDetector: ScriptedModalDetector(), secureFieldDetector: ScriptedSecureFieldDetector(),
    emergencyStop: EmergencyStopController(eventBus: .shared), eventBus: .shared,
    configuration: ComputerUseConfiguration(
      maxIterations: 3, maxStepsPerPlan: 3, noProgressIterationThreshold: 3,
      minActionIntervalSeconds: 0))
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .delete)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .mandatoryConfirmationBlocked(let intent, _) = outcome else {
    Issue.record("expected mandatoryConfirmationBlocked, got \(outcome)")
    return
  }
  #expect(intent == .delete)
  #expect(await executor.executeCallCount == 0)
}

@Test("A step requiring confirmation halts the loop and surfaces the challenge")
func confirmationRequiredHaltsLoopAndSurfacesChallenge() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  // Mutation tier lands in neither allow- nor deny-by-default, so it falls
  // through to the default-confirmation-tier check (`.mutation` by default).
  let policyConfiguration = PolicyConfiguration(
    defaultConfirmationTier: .mutation,
    allowByDefaultTiers: [.observation, .reversible],
    denyByDefaultTiers: [.destructive]
  )
  let loop = try await makeLoop(
    windows: windows, policyConfiguration: policyConfiguration, executor: executor)
  let planner = ScriptedPlanner(
    repeating: ComputerUsePlan(steps: [makeStep(intent: .fillField)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .confirmationRequired(let challenge, _) = outcome else {
    Issue.record("expected confirmationRequired, got \(outcome)")
    return
  }
  #expect(challenge.requestedAction == .computerUseMutate)
  #expect(await executor.executeCallCount == 0)
}

// MARK: - Never interact with password fields

@Test("A focused secure field blocks the step and never reaches the executor")
func secureFieldFocusBlocksStepExecution() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let secureFieldDetector = ScriptedSecureFieldDetector(focusedBundleIdentifiers: [targetApp])
  let loop = try await makeLoop(
    windows: windows, executor: executor, secureFieldDetector: secureFieldDetector,
    configuration: ComputerUseConfiguration(
      maxIterations: 3, maxStepsPerPlan: 3, noProgressIterationThreshold: 3,
      minActionIntervalSeconds: 0))
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .fillField)]))

  _ = await loop.run(target: target(), objective: "test", planner: planner)

  #expect(await executor.executeCallCount == 0)
}

// MARK: - No-progress detection

@Test("Identical observations across consecutive iterations escalate to noProgress")
func noProgressEscalatesAfterConfiguredThreshold() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let configuration = ComputerUseConfiguration(
    maxIterations: 10, maxStepsPerPlan: 3, noProgressIterationThreshold: 3,
    minActionIntervalSeconds: 0)
  let loop = try await makeLoop(windows: windows, executor: executor, configuration: configuration)
  // `.observe` is allowed by default with no grant, so the step actually
  // executes each iteration — but the scripted window source always returns
  // the same image, so the observed content hash never changes.
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .noProgress(let iterations) = outcome else {
    Issue.record("expected noProgress, got \(outcome)")
    return
  }
  // The first observation is always the (trivially "progressed") baseline,
  // so 3 *consecutive* no-progress detections require a 4th observation.
  #expect(iterations == 4)
}

// MARK: - Identity change halt

@Test("An observed application identity different from the approved target halts the loop")
func identityChangeHaltsLoop() async throws {
  let windows = [makeWindow(id: 1, bundleID: "com.example.different")]
  let loop = try await makeLoop(windows: windows)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan())

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .identityChanged = outcome else {
    Issue.record("expected identityChanged, got \(outcome)")
    return
  }
  #expect(await planner.proposeCallCount == 0)
}

@Test("A step whose declared target app differs from the session target halts the loop")
func stepTargetMismatchHaltsLoop() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(windows: windows, executor: executor)
  let mismatchedStep = makeStep(intent: .observe, targetAppBundleIdentifier: "com.example.other")
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [mismatchedStep]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .identityChanged = outcome else {
    Issue.record("expected identityChanged, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 0)
}

// MARK: - Unexpected modal dialog halt

@Test("An unexpected modal dialog halts the loop before any planning occurs")
func unexpectedModalDialogHaltsLoop() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let modalDetector = ScriptedModalDetector(bundleIdentifierToReturn: "com.apple.SecurityAgent")
  let loop = try await makeLoop(windows: windows, modalDetector: modalDetector)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan())

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .unexpectedModalDialog = outcome else {
    Issue.record("expected unexpectedModalDialog, got \(outcome)")
    return
  }
  #expect(await planner.proposeCallCount == 0)
}

// MARK: - Emergency stop

@Test("An emergency stop already active before the run starts halts immediately")
func emergencyStopActiveBeforeRunHaltsImmediately() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let emergencyStop = EmergencyStopController(eventBus: .shared)
  await emergencyStop.trigger(source: .ui, reason: "user pressed stop")
  let loop = try await makeLoop(windows: windows, emergencyStop: emergencyStop)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan())

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .emergencyStopped(let iterations) = outcome else {
    Issue.record("expected emergencyStopped, got \(outcome)")
    return
  }
  #expect(iterations == 1)
  #expect(await planner.proposeCallCount == 0)
}

@Test("An emergency stop triggered mid-plan (between Plan and Act) halts before the next step executes")
func emergencyStopTriggeredMidPlanHaltsBeforeNextStep() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let emergencyStop = EmergencyStopController(eventBus: .shared)
  let loop = try await makeLoop(windows: windows, executor: executor, emergencyStop: emergencyStop)
  let twoStepPlan = ComputerUsePlan(steps: [makeStep(intent: .observe), makeStep(intent: .observe)])
  let planner = ScriptedPlanner(repeating: twoStepPlan)
  await planner.setSideEffect(
    { await emergencyStop.trigger(source: .keyboard, reason: "panic mid-plan") })

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .emergencyStopped = outcome else {
    Issue.record("expected emergencyStopped, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 0)
}

// MARK: - Structured-concurrency cancellation

@Test("Cancelling the enclosing Task halts the loop before the next step executes, like emergency stop")
func taskCancellationMidPlanHaltsBeforeNextStep() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(windows: windows, executor: executor)
  let twoStepPlan = ComputerUsePlan(steps: [makeStep(intent: .observe), makeStep(intent: .observe)])
  let planner = ScriptedPlanner(repeating: twoStepPlan)
  let box = TaskHandleBox()
  await planner.setSideEffect({ await box.cancel() })

  let task = Task<ComputerUseLoopOutcome, Never> {
    await loop.run(target: target(), objective: "test", planner: planner)
  }
  await box.set(task)
  let outcome = await task.value

  guard case .failed(let reason, _) = outcome else {
    Issue.record("expected failed (cancelled), got \(outcome)")
    return
  }
  #expect(reason.contains("cancelled"))
  #expect(await executor.executeCallCount == 0)
}

// MARK: - Rate limiting

@Test("A minimum action interval throttles a second step in the same plan")
func rateLimitBlocksSecondStepWithinInterval() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let configuration = ComputerUseConfiguration(
    maxIterations: 1, maxStepsPerPlan: 3, noProgressIterationThreshold: 5,
    minActionIntervalSeconds: 30)
  let loop = try await makeLoop(windows: windows, executor: executor, configuration: configuration)
  let twoStepPlan = ComputerUsePlan(steps: [makeStep(intent: .observe), makeStep(intent: .observe)])
  let planner = ScriptedPlanner(repeating: twoStepPlan)

  _ = await loop.run(target: target(), objective: "test", planner: planner)

  #expect(await executor.executeCallCount == 1)
}

@Test("A zero minimum action interval never throttles")
func zeroRateLimitNeverThrottles() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let configuration = ComputerUseConfiguration(
    maxIterations: 1, maxStepsPerPlan: 3, noProgressIterationThreshold: 5,
    minActionIntervalSeconds: 0)
  let loop = try await makeLoop(windows: windows, executor: executor, configuration: configuration)
  let twoStepPlan = ComputerUsePlan(steps: [makeStep(intent: .observe), makeStep(intent: .observe)])
  let planner = ScriptedPlanner(repeating: twoStepPlan)

  _ = await loop.run(target: target(), objective: "test", planner: planner)

  #expect(await executor.executeCallCount == 2)
}

// MARK: - Accessibility-preferred anchoring audit signal

@Test("The step execution outcome faithfully reports whether accessibility or coordinate anchoring was used")
func stepEventReportsAccessibilityUsage() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  await executor.setResultToReturn(UIActionExecutionResult(usedAccessibilityAnchor: true))
  let loop = try await makeLoop(windows: windows, executor: executor)
  let anchor = UIAnchor(accessibilityRole: "AXButton", accessibilityTitle: "Submit")
  let planner = ScriptedPlanner(
    repeating: ComputerUsePlan(steps: [makeStep(anchor: anchor, intent: .observe)]))

  _ = await loop.run(target: target(), objective: "test", planner: planner)

  let executed = await executor.executedSteps
  #expect(executed.first?.usedAccessibility == true)
}
