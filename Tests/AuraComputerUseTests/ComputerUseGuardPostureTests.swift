import AuraComputerUse
import AuraCore
import AuraPolicy
import AuraScreen
import Foundation
import Testing

/// ADR-064 (PA-0 G0-4, owner decision D-2): every computer-use structural
/// guard is lifted under `ComputerUseGuardPosture.ownerTrust` and still
/// refuses under `.structural`; the emergency stop stops both. Each pair
/// below mirrors an existing guard-mechanics test (which now runs under an
/// explicit `.structural`) with the same fixture under `.ownerTrust`.

private let tightConfiguration = ComputerUseConfiguration(
  maxIterations: 3, maxStepsPerPlan: 3, noProgressIterationThreshold: 3,
  minActionIntervalSeconds: 0)

// MARK: - Presets and derivation

@Test("the production posture is derived from OwnerTrustPosture, never hard-coded")
func productionPostureDerivesFromSwitch() {
  #expect(OwnerTrustPosture.isEnabled)
  #expect(ComputerUseGuardPosture.production == .ownerTrust)
  #expect(ComputerUseGuardPosture.structural != .ownerTrust)
  // Every flag differs between the presets — no guard is accidentally
  // shared by both.
  #expect(ComputerUseGuardPosture.structural.enforcesMandatoryConfirmation)
  #expect(ComputerUseGuardPosture.structural.refusesSecureFields)
  #expect(ComputerUseGuardPosture.structural.haltsOnUnexpectedModal)
  #expect(ComputerUseGuardPosture.structural.haltsOnNoProgress)
  #expect(ComputerUseGuardPosture.structural.enforcesMaxStepsPerPlan)
  #expect(!ComputerUseGuardPosture.ownerTrust.enforcesMandatoryConfirmation)
  #expect(!ComputerUseGuardPosture.ownerTrust.refusesSecureFields)
  #expect(!ComputerUseGuardPosture.ownerTrust.haltsOnUnexpectedModal)
  #expect(!ComputerUseGuardPosture.ownerTrust.haltsOnNoProgress)
  #expect(!ComputerUseGuardPosture.ownerTrust.enforcesMaxStepsPerPlan)
}

// MARK: - (A) Mandatory-confirmation intents

@Test("ownerTrust: a mandatory-confirmation intent executes on a bare .allow")
func ownerTrustExecutesMandatoryConfirmationIntent() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let policyEngine = try await makePolicyEngine()
  try await policyEngine.issueGrant(
    Grant(
      capability: .computerUseDestructiveAct, patterns: [.any],
      confirmationRequirement: .none))
  let screenEngine = makeScreenEngine(windows: windows, policyEngine: policyEngine)
  let loop = ComputerUseControlLoop(
    screenEngine: screenEngine, policyEngine: policyEngine, actionExecutor: executor,
    modalDetector: ScriptedModalDetector(), secureFieldDetector: ScriptedSecureFieldDetector(),
    emergencyStop: EmergencyStopController(eventBus: .shared), eventBus: .shared,
    configuration: tightConfiguration, guardPosture: .ownerTrust)
  // One `.send` step, then done.
  let planner = ScriptedPlanner(
    plans: [ComputerUsePlan(steps: [makeStep(intent: .send)]), ComputerUsePlan()])

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .completed = outcome else {
    Issue.record("expected completed, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 1)
}

@Test("structural: the same mandatory-confirmation intent is still blocked")
func structuralStillBlocksMandatoryConfirmationIntent() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let policyEngine = try await makePolicyEngine()
  try await policyEngine.issueGrant(
    Grant(
      capability: .computerUseDestructiveAct, patterns: [.any],
      confirmationRequirement: .none))
  let screenEngine = makeScreenEngine(windows: windows, policyEngine: policyEngine)
  let loop = ComputerUseControlLoop(
    screenEngine: screenEngine, policyEngine: policyEngine, actionExecutor: executor,
    modalDetector: ScriptedModalDetector(), secureFieldDetector: ScriptedSecureFieldDetector(),
    emergencyStop: EmergencyStopController(eventBus: .shared), eventBus: .shared,
    configuration: tightConfiguration, guardPosture: .structural)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .send)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .mandatoryConfirmationBlocked(let intent, _) = outcome else {
    Issue.record("expected mandatoryConfirmationBlocked, got \(outcome)")
    return
  }
  #expect(intent == .send)
  #expect(await executor.executeCallCount == 0)
}

// MARK: - (B) Secure fields — loop

@Test("ownerTrust: a focused secure field no longer blocks a step in the loop")
func ownerTrustLoopIgnoresFocusedSecureField() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let secureFieldDetector = ScriptedSecureFieldDetector(focusedBundleIdentifiers: [targetApp])
  let loop = try await makeLoop(
    windows: windows, executor: executor, secureFieldDetector: secureFieldDetector,
    configuration: tightConfiguration, guardPosture: .ownerTrust)
  let planner = ScriptedPlanner(
    plans: [ComputerUsePlan(steps: [makeStep(intent: .observe)]), ComputerUsePlan()])

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .completed = outcome else {
    Issue.record("expected completed, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 1)
}

@Test("ownerTrust: an indeterminate secure-field probe no longer fails the loop")
func ownerTrustLoopIgnoresIndeterminateSecureField() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let secureFieldDetector = ScriptedSecureFieldDetector(
    probeOverride: .indeterminate("accessibility not trusted"))
  let loop = try await makeLoop(
    windows: windows, executor: executor, secureFieldDetector: secureFieldDetector,
    configuration: tightConfiguration, guardPosture: .ownerTrust)
  let planner = ScriptedPlanner(
    plans: [ComputerUsePlan(steps: [makeStep(intent: .observe)]), ComputerUsePlan()])

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .completed = outcome else {
    Issue.record("expected completed, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 1)
}

@Test("structural: a focused secure field still blocks the step in the loop")
func structuralLoopStillRefusesFocusedSecureField() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let secureFieldDetector = ScriptedSecureFieldDetector(focusedBundleIdentifiers: [targetApp])
  let loop = try await makeLoop(
    windows: windows, executor: executor, secureFieldDetector: secureFieldDetector,
    configuration: tightConfiguration, guardPosture: .structural)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .secureFieldBlocked = outcome else {
    Issue.record("expected secureFieldBlocked, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 0)
}

// MARK: - (B) Secure fields — executor

@Test("ownerTrust: the executor no longer refuses input while a secure field is focused")
func ownerTrustExecutorIgnoresSecureField() async throws {
  let executor = AXCGEventActionExecutor(
    emergencyStop: EmergencyStopController(eventBus: .shared),
    secureFieldDetector: ScriptedSecureFieldDetector(focusedBundleIdentifiers: [targetApp]),
    guardPosture: .ownerTrust)
  // The next gate after the (skipped) secure-field probe is the
  // Accessibility trust check, which the test host does not hold. The
  // distinguishing fact is the *reason*: it must not be the secure-field
  // refusal any more.
  do {
    _ = try await executor.execute(
      .click, anchor: UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.5),
      applicationBundleIdentifier: targetApp,
      windowFrame: UIWindowFrame(originX: 0, originY: 0, width: 800, height: 600))
  } catch {
    let message = String(describing: error)
    #expect(!message.contains("secure field"), "still refused on secure field: \(message)")
    #expect(!message.contains("secure-field"), "still refused on secure field: \(message)")
  }
}

@Test("structural: the executor still refuses input while a secure field is focused")
func structuralExecutorStillRefusesSecureField() async throws {
  let executor = AXCGEventActionExecutor(
    emergencyStop: EmergencyStopController(eventBus: .shared),
    secureFieldDetector: ScriptedSecureFieldDetector(focusedBundleIdentifiers: [targetApp]),
    guardPosture: .structural)
  do {
    _ = try await executor.execute(
      .click, anchor: UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.5),
      applicationBundleIdentifier: targetApp,
      windowFrame: UIWindowFrame(originX: 0, originY: 0, width: 800, height: 600))
    Issue.record("expected a secure-field refusal")
  } catch {
    #expect(String(describing: error).contains("secure field"))
  }
}

// MARK: - (B) Sensitive-application exclusion (screen context)

@Test("ownerTrust: a password-manager window is listed and its capture is not excluded")
func ownerTrustListsSensitiveApplicationWindows() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [
    makeWindow(id: 1, bundleID: "com.example.normal"),
    makeWindow(id: 2, bundleID: "com.1password.1password"),
    makeWindow(id: 3, bundleID: "ai.aura.local"),
  ]
  let policyEngine = try await makePolicyEngine()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraComputerUseTests", category: "screen"))
  let engine = ScreenContextEngine(
    windowSource: ScriptedWindowSource(windows: windows, imageToReturn: makeTestImage()),
    textRecognizer: ScriptedTextRecognizer(),
    secureFieldDetector: ScriptedSecureFieldDetector(), policyEngine: policyEngine, eventBus: bus,
    configuration: configuration, assistantBundleIdentifier: "ai.aura.local",
    sensitiveApplicationExclusionEnabled: false)

  let approved = try await engine.listApprovedWindows().map(\.windowID)

  // The password manager is now approved; the assistant's own window is
  // still excluded — self-exclusion is not governed by the posture.
  #expect(approved.contains(2))
  #expect(!approved.contains(3))
}

@Test("structural: the same password-manager window is still excluded")
func structuralStillExcludesSensitiveApplicationWindows() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [
    makeWindow(id: 1, bundleID: "com.example.normal"),
    makeWindow(id: 2, bundleID: "com.1password.1password"),
  ]
  let policyEngine = try await makePolicyEngine()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraComputerUseTests", category: "screen"))
  let engine = ScreenContextEngine(
    windowSource: ScriptedWindowSource(windows: windows, imageToReturn: makeTestImage()),
    textRecognizer: ScriptedTextRecognizer(),
    secureFieldDetector: ScriptedSecureFieldDetector(), policyEngine: policyEngine, eventBus: bus,
    configuration: configuration, assistantBundleIdentifier: "ai.aura.local",
    sensitiveApplicationExclusionEnabled: true)

  let approved = try await engine.listApprovedWindows().map(\.windowID)

  #expect(approved == [1])
}

// MARK: - (C) Unexpected modal

@Test("ownerTrust: an unexpected modal dialog no longer halts the loop")
func ownerTrustIgnoresUnexpectedModal() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let modalDetector = ScriptedModalDetector(bundleIdentifierToReturn: "com.apple.SecurityAgent")
  let loop = try await makeLoop(
    windows: windows, modalDetector: modalDetector, guardPosture: .ownerTrust)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan())

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .completed = outcome else {
    Issue.record("expected completed, got \(outcome)")
    return
  }
  #expect(await planner.proposeCallCount == 1)
}

@Test("structural: an unexpected modal dialog still halts the loop")
func structuralStillHaltsOnUnexpectedModal() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let modalDetector = ScriptedModalDetector(bundleIdentifierToReturn: "com.apple.SecurityAgent")
  let loop = try await makeLoop(
    windows: windows, modalDetector: modalDetector, guardPosture: .structural)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan())

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .unexpectedModalDialog = outcome else {
    Issue.record("expected unexpectedModalDialog, got \(outcome)")
    return
  }
  #expect(await planner.proposeCallCount == 0)
}

// MARK: - (C) No progress

@Test("ownerTrust: identical observations never escalate to noProgress; maxIterations bounds the run")
func ownerTrustNeverHaltsOnNoProgress() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let configuration = ComputerUseConfiguration(
    maxIterations: 6, maxStepsPerPlan: 3, noProgressIterationThreshold: 2,
    minActionIntervalSeconds: 0)
  let loop = try await makeLoop(
    windows: windows, executor: executor, configuration: configuration,
    guardPosture: .ownerTrust)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .iterationBudgetExhausted(let iterations) = outcome else {
    Issue.record("expected iterationBudgetExhausted, got \(outcome)")
    return
  }
  #expect(iterations == 6)
  #expect(await executor.executeCallCount == 6)
}

@Test("structural: identical observations still escalate to noProgress")
func structuralStillHaltsOnNoProgress() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let executor = ScriptedActionExecutor()
  let configuration = ComputerUseConfiguration(
    maxIterations: 6, maxStepsPerPlan: 3, noProgressIterationThreshold: 2,
    minActionIntervalSeconds: 0)
  let loop = try await makeLoop(
    windows: windows, executor: executor, configuration: configuration,
    guardPosture: .structural)
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .noProgress = outcome else {
    Issue.record("expected noProgress, got \(outcome)")
    return
  }
}

// MARK: - (C) Per-plan step ceiling

@Test("ownerTrust: a plan longer than maxStepsPerPlan executes in full")
func ownerTrustExecutesOversizedPlan() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let configuration = ComputerUseConfiguration(
    maxIterations: 5, maxStepsPerPlan: 2, noProgressIterationThreshold: 5,
    minActionIntervalSeconds: 0)
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(
    windows: windows, executor: executor, configuration: configuration,
    guardPosture: .ownerTrust)
  let oversizedPlan = ComputerUsePlan(steps: [
    makeStep(intent: .observe), makeStep(intent: .observe), makeStep(intent: .observe),
  ])
  let planner = ScriptedPlanner(plans: [oversizedPlan, ComputerUsePlan()])

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .completed = outcome else {
    Issue.record("expected completed, got \(outcome)")
    return
  }
  #expect(await executor.executeCallCount == 3)
}

@Test("structural: a plan longer than maxStepsPerPlan is still rejected")
func structuralStillRejectsOversizedPlan() async throws {
  let windows = [makeWindow(id: 1, bundleID: targetApp)]
  let configuration = ComputerUseConfiguration(
    maxIterations: 5, maxStepsPerPlan: 2, noProgressIterationThreshold: 5,
    minActionIntervalSeconds: 0)
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(
    windows: windows, executor: executor, configuration: configuration,
    guardPosture: .structural)
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

// MARK: - Kept: emergency stop (D-2 exception) under both presets

@Test("emergency stop halts the loop under ownerTrust exactly as under structural")
func emergencyStopHaltsBothPostures() async throws {
  for posture in [ComputerUseGuardPosture.ownerTrust, .structural] {
    let windows = [makeWindow(id: 1, bundleID: targetApp)]
    let emergencyStop = EmergencyStopController(eventBus: .shared)
    await emergencyStop.trigger(source: .userInterface, reason: "user pressed stop")
    let loop = try await makeLoop(
      windows: windows, emergencyStop: emergencyStop, guardPosture: posture)
    let planner = ScriptedPlanner(repeating: ComputerUsePlan())

    let outcome = await loop.run(target: target(), objective: "test", planner: planner)

    guard case .emergencyStopped = outcome else {
      Issue.record("expected emergencyStopped under \(posture), got \(outcome)")
      return
    }
    #expect(await planner.proposeCallCount == 0)
  }
}

@Test("emergency stop refuses executor input under ownerTrust exactly as under structural")
func emergencyStopRefusesExecutorUnderBothPostures() async throws {
  for posture in [ComputerUseGuardPosture.ownerTrust, .structural] {
    let emergencyStop = EmergencyStopController(eventBus: .shared)
    await emergencyStop.trigger(source: .userInterface, reason: "user pressed stop")
    let executor = AXCGEventActionExecutor(
      emergencyStop: emergencyStop, secureFieldDetector: ScriptedSecureFieldDetector(),
      guardPosture: posture)
    do {
      _ = try await executor.execute(
        .wait(seconds: 0), anchor: UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.5),
        applicationBundleIdentifier: targetApp,
        windowFrame: UIWindowFrame(originX: 0, originY: 0, width: 800, height: 600))
      Issue.record("expected an emergency-stop refusal under \(posture)")
    } catch {
      #expect(String(describing: error).contains("Emergency stop"))
    }
  }
}
