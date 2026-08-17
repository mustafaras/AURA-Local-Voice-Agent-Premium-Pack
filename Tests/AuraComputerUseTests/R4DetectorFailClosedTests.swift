@preconcurrency import ApplicationServices
import AuraComputerUse
import AuraCore
import AuraScreen
import Foundation
import Testing

// SP-008 follow-up — the layer *beneath* the adversarial guards.
//
// `R4AdversarialSafetyTests` proves the control flow refuses when a detector
// says "secure field" or "unexpected modal". This file covers the case that
// flow could not see: a detector that cannot answer at all.
//
// Both production detectors used to translate every Accessibility failure into
// "nothing found" — the shape named by RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL,
// where a detector silently returning `false` makes every guard above it inert
// while all tests still pass. An unreadable state is now `indeterminate`, and
// callers refuse on it under its own name.

// MARK: - Probe contracts

@Test("An unreadable secure-field state refuses input, exactly like a detected one")
func indeterminateSecureFieldProbeRefusesInput() {
  #expect(SecureFieldProbe.focused.refusesInput)
  #expect(SecureFieldProbe.indeterminate("cannotComplete").refusesInput)
  // The single case that may proceed is a *completed* negative answer.
  #expect(!SecureFieldProbe.notFocused.refusesInput)
}

@Test("A yes/no detector still maps onto the probe contract unchanged")
func booleanDetectorsKeepTheirMeaningUnderTheProbeDefault() async {
  let focused = ScriptedSecureFieldDetector(focusedBundleIdentifiers: ["com.example.app"])
  let clear = ScriptedSecureFieldDetector()

  #expect(await focused.probeSecureField(applicationBundleIdentifier: "com.example.app") == .focused)
  #expect(
    await clear.probeSecureField(applicationBundleIdentifier: "com.example.app") == .notFocused)
}

// MARK: - Accessibility error classification

@Test("Only a definitive empty answer counts as an absence")
func determinedAbsenceCoversOnlyDefinitiveEmptyAnswers() {
  // These say "the attribute has no value / the element is gone" — nothing is
  // focused, which is a real answer.
  for error in [AXError.noValue, .attributeUnsupported, .invalidUIElement] {
    #expect(AccessibilityProbeClassification.isDeterminedAbsence(error))
  }
}

@Test("A query that did not complete is never treated as an absence")
func failedQueriesAreNeverTreatedAsAbsence() {
  // The falsifier for this whole change: if any of these ever classifies as an
  // absence, an unreadable credential surface reads as "clear" again.
  for error in [
    AXError.cannotComplete, .apiDisabled, .notImplemented, .failure, .illegalArgument,
    .actionUnsupported, .notificationUnsupported, .parameterizedAttributeUnsupported,
    .notEnoughPrecision, .invalidUIElementObserver,
  ] {
    #expect(!AccessibilityProbeClassification.isDeterminedAbsence(error))
  }
}

@Test("Error descriptions are stable, non-empty and carry no captured content")
func errorDescriptionsAreStableAndContentFree() {
  #expect(AccessibilityProbeClassification.describe(.cannotComplete) == "cannotComplete")
  #expect(AccessibilityProbeClassification.describe(.apiDisabled) == "apiDisabled")
  #expect(AccessibilityProbeClassification.describe(.noValue) == "noValue")
}

// MARK: - The real detector's own consistency

@Test("The real secure-field detector's boolean answer is its probe, failing closed")
func realDetectorBooleanAnswerAgreesWithItsProbe() async {
  // Environment-independent: whatever this machine's Accessibility state is,
  // the boolean contract must equal the probe's fail-closed collapse. This
  // catches a future edit that reintroduces "unknown means no" in one path
  // while leaving the other correct.
  let detector = AccessibilitySecureFieldDetector()
  let probe = await detector.probeSecureField(applicationBundleIdentifier: "com.example.absent")
  let boolean = await detector.isSecureFieldFocused(
    applicationBundleIdentifier: "com.example.absent")

  #expect(boolean == probe.refusesInput)
}

// MARK: - Control loop

@Test("An unreadable secure-field state halts the session under its own reason")
func unreadableSecureFieldStateHaltsWithItsOwnReason() async throws {
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(
    windows: [makeWindow(id: 1, bundleID: targetApp)], executor: executor,
    secureFieldDetector: ScriptedSecureFieldDetector(
      probeOverride: .indeterminate("focused-element read failed: cannotComplete")))
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .failed(let reason, _) = outcome else {
    Issue.record("expected failed, got \(outcome)")
    return
  }
  #expect(reason.contains("secure-field check unavailable"))
  #expect(reason.contains("cannotComplete"))
  #expect(await executor.executeCallCount == 0)
}

@Test("An unreadable modal state halts, and is not reported as a detected dialog")
func unreadableModalStateHalts() async throws {
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(
    windows: [makeWindow(id: 1, bundleID: targetApp)], executor: executor,
    modalDetector: ScriptedModalDetector(
      probeOverride: .indeterminate("modal-attribute read failed: apiDisabled")))
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  guard case .failed(let reason, _) = outcome else {
    Issue.record("expected failed, got \(outcome)")
    return
  }
  #expect(reason.contains("modal check unavailable"))
  #expect(reason.contains("apiDisabled"))
  #expect(await executor.executeCallCount == 0)
}

@Test("A completed negative answer still lets the session proceed")
func determinedNegativeAnswersDoNotBlockTheSession() async throws {
  let executor = ScriptedActionExecutor()
  let loop = try await makeLoop(
    windows: [makeWindow(id: 1, bundleID: targetApp)], executor: executor,
    modalDetector: ScriptedModalDetector(probeOverride: ModalProbe.none),
    secureFieldDetector: ScriptedSecureFieldDetector(probeOverride: .notFocused))
  let planner = ScriptedPlanner(repeating: ComputerUsePlan(steps: [makeStep(intent: .observe)]))

  let outcome = await loop.run(target: target(), objective: "test", planner: planner)

  // The guard must not become a blanket refusal: a detector that answers
  // cleanly still permits the session it was always meant to permit.
  if case .failed(let reason, _) = outcome {
    Issue.record("a determined negative answer halted the session: \(reason)")
  }
  #expect(await executor.executeCallCount > 0)
}

// MARK: - Executor

@Test("The real executor refuses input when the secure-field state is unreadable")
func executorRefusesWhenSecureFieldStateIsUnreadable() async {
  let executor = AXCGEventActionExecutor(
    emergencyStop: EmergencyStopController(eventBus: .shared),
    secureFieldDetector: ScriptedSecureFieldDetector(
      probeOverride: .indeterminate("subrole read failed: cannotComplete")))

  await #expect(throws: AuraError.self) {
    _ = try await executor.execute(
      .typeText("correct horse battery staple"),
      anchor: UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.5),
      applicationBundleIdentifier: "com.example.app",
      windowFrame: UIWindowFrame(originX: 0, originY: 0, width: 800, height: 600))
  }
}

@Test("Waiting stays permitted even when the secure-field state is unreadable")
func executorStillPermitsWaitingWhenStateIsUnreadable() async throws {
  let executor = AXCGEventActionExecutor(
    emergencyStop: EmergencyStopController(eventBus: .shared),
    secureFieldDetector: ScriptedSecureFieldDetector(
      probeOverride: .indeterminate("accessibility not trusted")))

  // `.wait` generates no input, and it is how a caller yields to the user
  // while a credential prompt is on screen — blocking it would turn a safety
  // guard into a deadlock.
  let result = try await executor.execute(
    .wait(seconds: 0),
    anchor: UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.5),
    applicationBundleIdentifier: "com.example.app",
    windowFrame: UIWindowFrame(originX: 0, originY: 0, width: 800, height: 600))

  #expect(!result.usedAccessibilityAnchor)
}
