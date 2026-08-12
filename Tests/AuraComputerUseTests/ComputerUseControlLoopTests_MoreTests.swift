import AuraComputerUse
import AuraCore
import AuraPolicy
import AuraScreen
import CoreGraphics
import Foundation
import Testing

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
  await emergencyStop.trigger(source: .userInterface, reason: "user pressed stop")
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

@Test(
  "An emergency stop triggered mid-plan (between Plan and Act) halts before the next step executes")
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

@Test(
  "Cancelling the enclosing Task halts the loop before the next step executes, like emergency stop")
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

@Test(
  "The step outcome reports the anchoring mode used"
)
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
