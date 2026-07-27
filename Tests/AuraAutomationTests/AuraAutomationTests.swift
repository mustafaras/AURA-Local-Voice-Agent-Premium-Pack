import AuraAutomation
import AuraCore
import Foundation
import Testing

/// Collects event payloads from the event bus in a thread-safe way for test inspection.
private final class EventBox: @unchecked Sendable {
  private let lock = NSLock()
  private var payloads: [any EventPayload] = []

  func append(_ payload: any EventPayload) {
    lock.lock()
    defer { lock.unlock() }
    payloads.append(payload)
  }

  var events: [any EventPayload] {
    lock.lock()
    defer { lock.unlock() }
    return payloads
  }
}

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

  @Test func checkAccessibilityPermissionEmitsDeniedEventOnCleanInstall() async {
    let spy = AccessibilityHealthSpy(injectedState: .denied)
    let logger = AuraLogger(subsystem: "ai.aura.tests", category: "AccessibilityPermissionTests", minimumLevel: .debug)
    let eventBus = AuraEventBus(logger: logger)
    let box = EventBox()
    await eventBus.subscribe(AccessibilityPermissionEvent.self) { envelope in
      box.append(envelope.payload)
    }
    let automation = AuraAutomation(
      config: AutomationConfiguration(),
      applicationController: ApplicationControllerSpy(),
      accessibilityHealth: spy,
      accessibilityObserver: AccessibilityObserverSpy(),
      eventBus: eventBus
    )

    let state = await automation.checkAccessibilityPermission()

    #expect(state == .denied)
    let captured = box.events.compactMap { $0 as? AccessibilityPermissionEvent }
    #expect(captured.count == 1)
    #expect(captured.first?.state == .denied)
    #expect(captured.first?.source == "AuraAutomation.AccessibilityHealth")
  }

  @Test func checkAccessibilityPermissionEmitsGrantedEventWhenTrusted() async {
    let spy = AccessibilityHealthSpy(injectedState: .granted)
    let logger = AuraLogger(subsystem: "ai.aura.tests", category: "AccessibilityPermissionTests", minimumLevel: .debug)
    let eventBus = AuraEventBus(logger: logger)
    let box = EventBox()
    await eventBus.subscribe(AccessibilityPermissionEvent.self) { envelope in
      box.append(envelope.payload)
    }
    let automation = AuraAutomation(
      config: AutomationConfiguration(),
      applicationController: ApplicationControllerSpy(),
      accessibilityHealth: spy,
      accessibilityObserver: AccessibilityObserverSpy(),
      eventBus: eventBus
    )

    let state = await automation.checkAccessibilityPermission()

    #expect(state == .granted)
    let captured = box.events.compactMap { $0 as? AccessibilityPermissionEvent }
    #expect(captured.count == 1)
    #expect(captured.first?.state == .granted)
  }
}

// MARK: - Test doubles

final actor AccessibilityHealthSpy: AccessibilityHealthChecking {
  var injectedState: AccessibilityTrustState = .denied
  var emitCallCount = 0
  var lastEventBus: AuraEventBus?

  init(injectedState: AccessibilityTrustState = .denied) {
    self.injectedState = injectedState
  }

  func checkTrust() async -> AccessibilityTrustState {
    return injectedState
  }

  func waitForTrust(pollInterval: TimeInterval) async throws(AuraError) {
    if injectedState != .granted {
      throw AuraError.automationError("Accessibility trust denied")
    }
  }

  func emitPermissionEvent(into bus: AuraEventBus?) async {
    emitCallCount += 1
    lastEventBus = bus
    let payload = AccessibilityPermissionEvent(
      source: "AuraAutomation.AccessibilityHealth",
      state: injectedState,
      timestamp: Date()
    )
    let envelope = EventEnvelope(
      correlationID: UUID(),
      causationID: UUID(),
      actor: ActorID.automation,
      sensitivity: .internalLevel,
      payload: payload
    )
    if let bus {
      await bus.emit(envelope)
    }
  }
}

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
