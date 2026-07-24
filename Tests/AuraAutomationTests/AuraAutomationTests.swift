import AuraAutomation
import AuraCore
import Foundation
import Testing

@Suite("Native macOS automation coordinator")
struct AuraAutomationTests {

  @Test func targetImportsAndCompiles() {
    // Bootstrap-only smoke test: the target exists and builds.
    #expect(true)
  }

  @Test func discoverApplicationsEmitsEvent() async {
    let spy = ApplicationControllerSpy()
    let automation = AuraAutomation(
      config: AutomationConfiguration(),
      applicationController: spy,
      accessibilityHealth: AccessibilityHealth(),
      accessibilityObserver: AccessibilityObserverSpy()
    )
    await automation.discoverApplications()
    #expect(spy.runningApplicationsCallCount == 1)
  }

  @Test func launchApplicationEmitsEvent() async {
    let spy = ApplicationControllerSpy()
    let automation = AuraAutomation(
      config: AutomationConfiguration(),
      applicationController: spy,
      accessibilityHealth: AccessibilityHealth(),
      accessibilityObserver: AccessibilityObserverSpy()
    )
    try? await automation.launchApplication(bundleIdentifier: "com.example.app")
    #expect(spy.launchCallCount == 1)
  }

  @Test func emptyBundleIdentifierLaunchFails() async {
    let spy = ApplicationControllerSpy()
    let automation = AuraAutomation(
      config: AutomationConfiguration(),
      applicationController: spy,
      accessibilityHealth: AccessibilityHealth(),
      accessibilityObserver: AccessibilityObserverSpy()
    )
    await #expect(throws: AuraError.self) {
      try await automation.launchApplication(bundleIdentifier: "")
    }
  }
}

// MARK: - Test doubles

final class ApplicationControllerSpy: ApplicationControlling, @unchecked Sendable {
  nonisolated(unsafe) var runningApplicationsCallCount = 0
  nonisolated(unsafe) var launchCallCount = 0
  nonisolated(unsafe) var activateCallCount = 0
  nonisolated(unsafe) var hideCallCount = 0
  nonisolated(unsafe) var quitCallCount = 0

  func runningApplications() -> [NativeApplicationDescriptor] {
    runningApplicationsCallCount += 1
    return [
      NativeApplicationDescriptor(
        bundleIdentifier: "com.example.app",
        name: "Example",
        processID: 123,
        isActive: true,
        isHidden: false
      )
    ]
  }

  func launchApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    launchCallCount += 1
    guard !bundleIdentifier.isEmpty else {
      throw AuraError.automationError("bundleIdentifier must not be empty")
    }
    return NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier,
      name: "Example",
      processID: 123,
      isActive: true,
      isHidden: false
    )
  }

  func activateApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    activateCallCount += 1
    return NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier,
      name: "Example",
      processID: 123,
      isActive: true,
      isHidden: false
    )
  }

  func hideApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    hideCallCount += 1
    return NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier,
      name: "Example",
      processID: 123,
      isActive: false,
      isHidden: true
    )
  }

  func quitApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    quitCallCount += 1
    return NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier,
      name: "Example",
      processID: 123,
      isActive: false,
      isHidden: false
    )
  }
}

final class AccessibilityObserverSpy: AccessibilityObserving {
  func observeFirstElement(
    bundleIdentifier: String,
    role: String?,
    title: String?,
    timeout: TimeInterval
  ) async throws(AuraError) -> AccessibleElementObservation {
    return AccessibleElementObservation(
      bundleIdentifier: bundleIdentifier,
      processID: 123,
      elementRole: role ?? "button",
      elementTitle: title ?? "OK",
      elementValue: nil,
      timestamp: Date()
    )
  }
}
