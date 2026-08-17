import AuraComputerUse
import AuraCore
import Foundation
import Testing

// The real `AXCGEventActionExecutor`/`AccessibilityModalDialogDetector`
// must not exercise live Accessibility resolution or CGEvent delivery from a
// test process. The host may or may not grant Accessibility to the runner, so
// failure-path tests use a nonexistent application plus an Accessibility-only
// anchor: an untrusted process fails at the trust gate, while a trusted process
// fails before input generation because the target application is absent.

@Test
func waitActionSucceedsWithoutRequiringAccessibilityTrust() async throws {
  let executor = AXCGEventActionExecutor(
    emergencyStop: EmergencyStopController(eventBus: .shared),
    secureFieldDetector: ScriptedSecureFieldDetector())
  let result = try await executor.execute(
    .wait(seconds: 0.01), anchor: UIAnchor(), applicationBundleIdentifier: "com.example.app",
    windowFrame: UIWindowFrame(originX: 0, originY: 0, width: 800, height: 600))
  #expect(result.usedAccessibilityAnchor == false)
}

@Test
func clickActionDegradesSafelyWithoutGeneratingInput() async {
  let executor = AXCGEventActionExecutor(
    emergencyStop: EmergencyStopController(eventBus: .shared),
    secureFieldDetector: ScriptedSecureFieldDetector())
  await #expect(throws: AuraError.self) {
    _ = try await executor.execute(
      .click, anchor: UIAnchor(accessibilityRole: "AXButton"),
      applicationBundleIdentifier: "invalid.aura.tests.nonexistent",
      windowFrame: UIWindowFrame(originX: 0, originY: 0, width: 800, height: 600))
  }
}

@Test(
  "The real executor refuses input while emergency stop is active"
)
func executorItselfRefusesInputWhileEmergencyStopped() async throws {
  let emergencyStop = EmergencyStopController(eventBus: .shared)
  await emergencyStop.trigger(source: .keyboard, reason: "panic")
  let executor = AXCGEventActionExecutor(
    emergencyStop: emergencyStop, secureFieldDetector: ScriptedSecureFieldDetector())

  // Even `.wait`, which needs no Accessibility trust at all, is refused —
  // the emergency-stop check is unconditional and comes before any other
  // branch.
  await #expect(throws: AuraError.self) {
    _ = try await executor.execute(
      .wait(seconds: 0.01), anchor: UIAnchor(), applicationBundleIdentifier: "com.example.app",
      windowFrame: UIWindowFrame(originX: 0, originY: 0, width: 800, height: 600))
  }
}

@Test
func modalDetectorReturnsNilWithoutAccessibilityTrust() async {
  let detector = AccessibilityModalDialogDetector()
  let result = await detector.detectUnexpectedModal(expectedBundleIdentifier: "com.example.app")
  #expect(result == nil)
}
