import AuraComputerUse
import AuraCore
import Foundation
import Testing

// The real `AXCGEventActionExecutor`/`AccessibilityModalDialogDetector`
// cannot exercise live Accessibility resolution or CGEvent delivery in this
// sandboxed CommandLineTools environment (no granted Accessibility
// permission, likely no real display) — matching the established Phase 1/2/
// 6/17 precedent of "real, header-verified API, safe-degradation tested,
// live-hardware validation deferred." These tests only prove the executor
// degrades safely (a typed error, never a crash or hang) rather than
// silently pretending to succeed.

@Test
func waitActionSucceedsWithoutRequiringAccessibilityTrust() async throws {
  let executor = AXCGEventActionExecutor(emergencyStop: EmergencyStopController(eventBus: .shared))
  let result = try await executor.execute(
    .wait(seconds: 0.01), anchor: UIAnchor(), applicationBundleIdentifier: "com.example.app",
    windowFrameX: 0, windowFrameY: 0, windowFrameWidth: 800, windowFrameHeight: 600)
  #expect(result.usedAccessibilityAnchor == false)
}

@Test
func clickActionDegradesSafelyWithoutAccessibilityTrust() async {
  let executor = AXCGEventActionExecutor(emergencyStop: EmergencyStopController(eventBus: .shared))
  await #expect(throws: AuraError.self) {
    _ = try await executor.execute(
      .click, anchor: UIAnchor(fallbackNormalizedX: 0.5, fallbackNormalizedY: 0.5),
      applicationBundleIdentifier: "com.example.app", windowFrameX: 0, windowFrameY: 0,
      windowFrameWidth: 800, windowFrameHeight: 600)
  }
}

@Test("The real executor refuses to generate input while emergency stop is active, independent of any caller checking first")
func executorItselfRefusesInputWhileEmergencyStopped() async throws {
  let emergencyStop = EmergencyStopController(eventBus: .shared)
  await emergencyStop.trigger(source: .keyboard, reason: "panic")
  let executor = AXCGEventActionExecutor(emergencyStop: emergencyStop)

  // Even `.wait`, which needs no Accessibility trust at all, is refused —
  // the emergency-stop check is unconditional and comes before any other
  // branch.
  await #expect(throws: AuraError.self) {
    _ = try await executor.execute(
      .wait(seconds: 0.01), anchor: UIAnchor(), applicationBundleIdentifier: "com.example.app",
      windowFrameX: 0, windowFrameY: 0, windowFrameWidth: 800, windowFrameHeight: 600)
  }
}

@Test
func modalDetectorReturnsNilWithoutAccessibilityTrust() async {
  let detector = AccessibilityModalDialogDetector()
  let result = await detector.detectUnexpectedModal(expectedBundleIdentifier: "com.example.app")
  #expect(result == nil)
}
