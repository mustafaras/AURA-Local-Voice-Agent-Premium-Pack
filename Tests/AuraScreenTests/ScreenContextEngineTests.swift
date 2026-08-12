import AuraCore
import AuraPolicy
import CoreGraphics
import Foundation
import Testing

@testable import AuraScreen

func makePolicyEngine(denyScreenCapture: Bool = false) async throws -> PolicyEngine {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraScreenTests", category: "policy"))
  let engine = try await PolicyEngine(
    configuration: PolicyConfiguration(), eventBus: bus, store: nil)
  if denyScreenCapture {
    try await engine.upsertDenyRule(
      DenyRule(capability: .screenCapture, reason: "test deny rule"))
  }
  return engine
}

func makeEngine(
  windows: [ScreenWindowDescriptor],
  configuration: ScreenContextConfiguration,
  textRecognizer: ScriptedTextRecognizer = ScriptedTextRecognizer(),
  secureFieldDetector: ScriptedSecureFieldDetector = ScriptedSecureFieldDetector(),
  policyEngine: PolicyEngine? = nil,
  assistantBundleIdentifier: String = "ai.aura.local",
  screenshotRetentionDays: Int = PrivacyConfiguration().screenshotRetentionDays
) async throws -> (ScreenContextEngine, ScriptedWindowSource) {
  let windowSource = ScriptedWindowSource(windows: windows)
  let policy: PolicyEngine
  if let policyEngine {
    policy = policyEngine
  } else {
    policy = try await makePolicyEngine()
  }
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraScreenTests", category: "engine"))
  let engine = ScreenContextEngine(
    windowSource: windowSource, textRecognizer: textRecognizer,
    secureFieldDetector: secureFieldDetector, policyEngine: policy, eventBus: bus,
    configuration: configuration, assistantBundleIdentifier: assistantBundleIdentifier,
    screenshotRetentionDays: screenshotRetentionDays)
  return (engine, windowSource)
}

// MARK: - Window listing / exclusion

@Test
func listApprovedWindowsExcludesSensitiveSelfAndOffscreen() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [
    makeWindow(id: 1, bundleID: "com.example.normal"),
    makeWindow(id: 2, bundleID: "com.1password.1password"),
    makeWindow(id: 3, bundleID: "ai.aura.local"),
    makeWindow(id: 4, bundleID: "com.example.offscreen", isOnScreen: false),
  ]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)

  let approved = try await engine.listApprovedWindows()

  #expect(approved.map(\.windowID) == [1])
}

@Test
func listApprovedWindowsReturnsEmptyWhenDisabled() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = false
  let windows = [makeWindow(id: 1)]
  let (engine, windowSource) = try await makeEngine(windows: windows, configuration: configuration)

  let approved = try await engine.listApprovedWindows()

  #expect(approved.isEmpty)
  let callCount = await windowSource.captureImageCallCount
  #expect(callCount == 0)
}

// MARK: - Capture blocking

@Test
func captureBlockedWhenDisabledByConfigurationAndNeverTouchesCaptureSource() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = false
  let windows = [makeWindow(id: 1)]
  let (engine, windowSource) = try await makeEngine(windows: windows, configuration: configuration)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .disabledByConfiguration)
  let callCount = await windowSource.captureImageCallCount
  #expect(callCount == 0)
}

@Test
func captureBlockedForSensitiveApplication() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "com.bitwarden.desktop")]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .sensitiveApplication)
}

@Test
func captureBlockedForAssistantSelfExclusion() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "ai.aura.local")]
  let (engine, _) = try await makeEngine(
    windows: windows, configuration: configuration, assistantBundleIdentifier: "ai.aura.local")

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .assistantSelfExclusion)
}

@Test
func captureBlockedWhenWindowNotFound() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let (engine, _) = try await makeEngine(windows: [], configuration: configuration)

  let outcome = try await engine.captureWindow(windowID: 999)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .windowNotFound)
}

@Test
func captureBlockedWhenPolicyDenies() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "com.example.normal")]
  let denyingPolicy = try await makePolicyEngine(denyScreenCapture: true)
  let (engine, _) = try await makeEngine(
    windows: windows, configuration: configuration, policyEngine: denyingPolicy)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .policyDenied)
}

// MARK: - Successful capture and redaction

@Test
func captureSucceedsAndRedactsRecognizedFinancialData() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, title: "My Bank Statement", bundleID: "com.example.normal")]
  let region = RecognizedTextRegion(
    text: "Account balance card 4111 1111 1111 1111", boundingBoxX: 0.1, boundingBoxY: 0.1,
    boundingBoxWidth: 0.4, boundingBoxHeight: 0.05)
  let recognizer = ScriptedTextRecognizer(regionsToReturn: [region])
  let (engine, _) = try await makeEngine(
    windows: windows, configuration: configuration, textRecognizer: recognizer)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .captured(let observation) = outcome else {
    Issue.record("expected captured, got \(outcome)")
    return
  }
  #expect(observation.redactions.contains { $0.category == .financialData })
  #expect(observation.appBundleIdentifier == "com.example.normal")
  #expect(!observation.contentHash.isEmpty)
}

@Test
func captureNeverRetainsRawFrameByDefault() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1)]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .captured(let observation) = outcome else {
    Issue.record("expected captured, got \(outcome)")
    return
  }
  #expect(observation.rawImageRetained == false)
  let retainedCount = await engine.retainedFrameCount()
  #expect(retainedCount == 0)
}

@Test
func captureRetainsRawFrameOnlyWhenExplicitlyOptedIn() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  configuration.retainRawFrames = true
  let windows = [makeWindow(id: 1)]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .captured(let observation) = outcome else {
    Issue.record("expected captured, got \(outcome)")
    return
  }
  #expect(observation.rawImageRetained == true)
  let retainedCount = await engine.retainedFrameCount()
  #expect(retainedCount == 1)
}

@Test
func retainedRawFramesExpireAfterConfiguredRetentionWindow() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  configuration.retainRawFrames = true
  let windows = [makeWindow(id: 1)]
  let (engine, _) = try await makeEngine(
    windows: windows, configuration: configuration, screenshotRetentionDays: 1)

  let outcome = try await engine.captureWindow(windowID: 1)
  guard case .captured = outcome else {
    Issue.record("expected captured, got \(outcome)")
    return
  }
  #expect(await engine.retainedFrameCount() == 1)

  // Just under the 1-day window: still retained.
  let almostExpired = await engine.purgeExpiredRawFrames(
    referenceDate: Date().addingTimeInterval(23 * 3600))
  #expect(almostExpired == 0)
  #expect(await engine.retainedFrameCount() == 1)

  // Past the 1-day window: purged.
  let purgedCount = await engine.purgeExpiredRawFrames(
    referenceDate: Date().addingTimeInterval(25 * 3600))
  #expect(purgedCount == 1)
  #expect(await engine.retainedFrameCount() == 0)
}
