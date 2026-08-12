import AuraCore
import AuraPolicy
import CoreGraphics
import Foundation
import Testing

@testable import AuraScreen

@Test
func captureRespectsSecureFieldFocusAndMasksEntireFrame() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "com.example.normal")]
  let recognizer = ScriptedTextRecognizer(
    regionsToReturn: [
      RecognizedTextRegion(
        text: "unrelated visible text", boundingBoxX: 0.1, boundingBoxY: 0.1, boundingBoxWidth: 0.3,
        boundingBoxHeight: 0.05)
    ])
  let secureFieldDetector = ScriptedSecureFieldDetector(focusedBundleIdentifiers: [
    "com.example.normal"
  ])
  let (engine, _) = try await makeEngine(
    windows: windows, configuration: configuration, textRecognizer: recognizer,
    secureFieldDetector: secureFieldDetector)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .captured(let observation) = outcome else {
    Issue.record("expected captured, got \(outcome)")
    return
  }
  #expect(observation.redactions.count == 1)
  #expect(observation.redactions.first?.category == .secureTextField)
}

@Test
func freshnessDeadlineReflectsConfiguredWindowAndObservationStartsFresh() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  configuration.freshnessSeconds = 30
  let windows = [makeWindow(id: 1)]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .captured(let observation) = outcome else {
    Issue.record("expected captured, got \(outcome)")
    return
  }
  #expect(observation.isFresh)
  let deltaSeconds = observation.freshnessDeadline.timeIntervalSince(observation.capturedAt)
  #expect(abs(deltaSeconds - 30) < 0.01)
}

@Test
func sensitiveWindowTitleIsRedactedInObservation() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [
    makeWindow(
      id: 1, title: "Statement - Card 4111111111111111.pdf", bundleID: "com.example.normal")
  ]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .captured(let observation) = outcome else {
    Issue.record("expected captured, got \(outcome)")
    return
  }
  #expect(observation.windowTitle?.contains("4111111111111111") == false)
}

// MARK: - Notification Center exclusion

@Test
func captureBlockedForNotificationCenterApplication() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "com.apple.notificationcenterui")]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)

  let outcome = try await engine.captureWindow(windowID: 1)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .sensitiveApplication)
}

// MARK: - Region scoping

@Test
func captureWithValidRegionRecordsRegionAndForwardsItToCaptureSource() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "com.example.normal")]
  let (engine, windowSource) = try await makeEngine(windows: windows, configuration: configuration)
  let region = CaptureRegion(originX: 0.1, originY: 0.2, width: 0.5, height: 0.3)

  let outcome = try await engine.captureWindow(windowID: 1, region: region)

  guard case .captured(let observation) = outcome else {
    Issue.record("expected captured, got \(outcome)")
    return
  }
  #expect(observation.capturedRegion == region)
  let forwardedRegion = await windowSource.lastRequestedRegion
  #expect(forwardedRegion == region)
}

@Test
func captureBlockedForOutOfBoundsRegionAndNeverCallsCaptureSource() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "com.example.normal")]
  let (engine, windowSource) = try await makeEngine(windows: windows, configuration: configuration)
  let region = CaptureRegion(originX: 0.8, originY: 0.0, width: 0.5, height: 0.5)  // x + width > 1

  let outcome = try await engine.captureWindow(windowID: 1, region: region)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .invalidRegion)
  let callCount = await windowSource.captureImageCallCount
  #expect(callCount == 0)
}

@Test
func captureBlockedForZeroSizedRegion() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "com.example.normal")]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)
  let region = CaptureRegion(originX: 0.1, originY: 0.1, width: 0, height: 0.5)

  let outcome = try await engine.captureWindow(windowID: 1, region: region)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .invalidRegion)
}

@Test
func captureBlockedForNegativeOriginRegion() async throws {
  var configuration = ScreenContextConfiguration()
  configuration.enabled = true
  let windows = [makeWindow(id: 1, bundleID: "com.example.normal")]
  let (engine, _) = try await makeEngine(windows: windows, configuration: configuration)
  let region = CaptureRegion(originX: -0.1, originY: 0.1, width: 0.5, height: 0.5)

  let outcome = try await engine.captureWindow(windowID: 1, region: region)

  guard case .blocked(let reason) = outcome else {
    Issue.record("expected blocked, got \(outcome)")
    return
  }
  #expect(reason == .invalidRegion)
}

// MARK: - Region math

@Test
func regionsRelativeToCaptureClipsAndTranslatesOverlappingRegion() {
  let userRegion = UserDefinedRedactionRegion(originX: 0.0, originY: 0.0, width: 0.5, height: 0.5)
  let capturedRegion = CaptureRegion(originX: 0.25, originY: 0.25, width: 0.5, height: 0.5)

  let result = ScreenContextEngine.regionsRelativeToCapture(
    [userRegion], capturedRegion: capturedRegion)

  #expect(result.count == 1)
  #expect(result.first?.originX == 0)
  #expect(result.first?.originY == 0)
  #expect(result.first?.width == 0.5)
  #expect(result.first?.height == 0.5)
}

@Test
func regionsRelativeToCaptureDropsNonOverlappingRegion() {
  let userRegion = UserDefinedRedactionRegion(originX: 0.0, originY: 0.0, width: 0.2, height: 0.2)
  let capturedRegion = CaptureRegion(originX: 0.5, originY: 0.5, width: 0.5, height: 0.5)

  let result = ScreenContextEngine.regionsRelativeToCapture(
    [userRegion], capturedRegion: capturedRegion)

  #expect(result.isEmpty)
}

@Test
func regionsRelativeToCaptureReturnsUnchangedWhenWholeWindowCaptured() {
  let userRegion = UserDefinedRedactionRegion(originX: 0.1, originY: 0.1, width: 0.2, height: 0.2)

  let result = ScreenContextEngine.regionsRelativeToCapture([userRegion], capturedRegion: nil)

  #expect(result == [userRegion])
}

// MARK: - ScreenCaptureKitWindowSource pure math

@Test
func absoluteSourceRectTranslatesWindowRelativeRegionToDisplaySpace() {
  let windowFrame = CGRect(x: 100, y: 50, width: 800, height: 600)
  let region = CaptureRegion(originX: 0.25, originY: 0.5, width: 0.5, height: 0.25)

  let rect = ScreenCaptureKitWindowSource.absoluteSourceRect(
    windowFrame: windowFrame, region: region)

  #expect(rect.origin.x == 300)
  #expect(rect.origin.y == 350)
  #expect(rect.size.width == 400)
  #expect(rect.size.height == 150)
}

@Test
func scaledDimensionsCapsToMaxDimensionPreservingAspectRatio() {
  let (width, height) = ScreenCaptureKitWindowSource.scaledDimensions(
    width: 1600, height: 800, maxDimension: 800)

  #expect(width == 800)
  #expect(height == 400)
}

@Test
func scaledDimensionsNeverScalesUp() {
  let (width, height) = ScreenCaptureKitWindowSource.scaledDimensions(
    width: 400, height: 300, maxDimension: 2048)

  #expect(width == 400)
  #expect(height == 300)
}
