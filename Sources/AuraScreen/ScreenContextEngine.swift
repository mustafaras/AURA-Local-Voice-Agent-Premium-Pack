import AuraCore
import AuraPolicy
import CoreGraphics
import CryptoKit
import Foundation

private struct RetainedRawFrame {
  let id: UUID
  let image: CGImage
  let capturedAt: Date
}

private struct ScreenCaptureRedaction {
  let redactions: [RedactionMatch]
  let redactedTitle: String?
}

private enum ScreenCapturePreflight {
  case blocked(ScreenCaptureBlockReason)
  case ready(ScreenWindowDescriptor)
}

/// Orchestrates approved-window screen capture: policy gating, sensitive-app
/// and self exclusion, redaction, freshness metadata, and zero-retention by
/// default.
///
/// Every real ScreenCaptureKit/Vision/Accessibility call is reached only
/// through the `ScreenWindowSource`/`TextRecognizing`/`SecureFieldDetecting`
/// protocols, so this actor's own orchestration logic — exclusion, policy
/// gating, redaction assembly, retention — is fully unit-testable with
/// deterministic fakes, independent of live screen/OCR/Accessibility state.
public actor ScreenContextEngine {
  private let windowSource: any ScreenWindowSource
  private let textRecognizer: any TextRecognizing
  private let secureFieldDetector: any SecureFieldDetecting
  private let policyEngine: PolicyEngine
  private let eventBus: AuraEventBus
  private let configuration: ScreenContextConfiguration
  private let assistantBundleIdentifier: String
  private let redactionPipeline: RedactionPipeline

  /// Retention window for opted-in raw frames, in days. Deliberately reuses
  /// the existing `PrivacyConfiguration.screenshotRetentionDays` rather than
  /// a second, duplicate field on `ScreenContextConfiguration`.
  private let screenshotRetentionDays: Int

  /// Raw captured images retained only when `configuration.retainRawFrames`
  /// is true — bounded by both count and age, so an opt-in diagnostic
  /// session cannot grow without limit or outlive its configured retention
  /// window. Empty for the entire lifetime of the engine under default
  /// configuration.
  private var retainedRawFrames: [RetainedRawFrame] = []
  private let maxRetainedFrames = 20

  public init(
    windowSource: any ScreenWindowSource,
    textRecognizer: any TextRecognizing,
    secureFieldDetector: any SecureFieldDetecting,
    policyEngine: PolicyEngine,
    eventBus: AuraEventBus = .shared,
    configuration: ScreenContextConfiguration = ScreenContextConfiguration(),
    assistantBundleIdentifier: String,
    screenshotRetentionDays: Int = PrivacyConfiguration().screenshotRetentionDays
  ) {
    self.windowSource = windowSource
    self.textRecognizer = textRecognizer
    self.secureFieldDetector = secureFieldDetector
    self.policyEngine = policyEngine
    self.eventBus = eventBus
    self.configuration = configuration
    self.assistantBundleIdentifier = assistantBundleIdentifier
    self.redactionPipeline = RedactionPipeline()
    self.screenshotRetentionDays = screenshotRetentionDays
  }

  // MARK: - Window listing

  /// List windows that are actually approved to capture: on-screen, not a
  /// sensitive application, and not the assistant's own window.
  public func listApprovedWindows() async throws(AuraError) -> [ScreenWindowDescriptor] {
    guard configuration.enabled else { return [] }
    let all = try await windowSource.listCapturableWindows()
    return all.filter { isApproved($0) }
  }

  // MARK: - Capture

  @discardableResult
  public func captureWindow(
    windowID: Int,
    region: CaptureRegion? = nil,
    actor: ActorID = .screen,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> ScreenCaptureOutcome {
    await emit(
      ScreenCaptureRequestedEvent(windowID: windowID), actor: actor, correlationID: correlationID)

    switch try await preflight(
      windowID: windowID, region: region, actor: actor,
      sessionID: sessionID, correlationID: correlationID)
    {
    case .blocked(let reason):
      return await block(reason, windowID: windowID, actor: actor, correlationID: correlationID)
    case .ready(let descriptor):
      return try await captureApprovedWindow(
        windowID: windowID, region: region, actor: actor,
        correlationID: correlationID, descriptor: descriptor)
    }
  }

  private func preflight(
    windowID: Int,
    region: CaptureRegion?,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID
  ) async throws(AuraError) -> ScreenCapturePreflight {
    guard configuration.enabled else { return .blocked(.disabledByConfiguration) }
    if let region, !region.isValid { return .blocked(.invalidRegion) }
    let windows = try await windowSource.listCapturableWindows()
    guard let descriptor = windows.first(where: { $0.windowID == windowID }) else {
      return .blocked(.windowNotFound)
    }
    guard isApproved(descriptor) else {
      let reason: ScreenCaptureBlockReason =
        descriptor.applicationBundleIdentifier == assistantBundleIdentifier
        ? .assistantSelfExclusion : .sensitiveApplication
      return .blocked(reason)
    }
    let policyRequest = PolicyEvaluationRequest(
      capability: .screenCapture,
      actor: actor,
      target: PolicyTarget(appID: descriptor.applicationBundleIdentifier),
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: correlationID
    )
    let decision = await policyEngine.evaluate(policyRequest)
    guard case .allow = decision else { return .blocked(.policyDenied) }
    return .ready(descriptor)
  }

  private func captureApprovedWindow(
    windowID: Int,
    region: CaptureRegion?,
    actor: ActorID,
    correlationID: UUID,
    descriptor: ScreenWindowDescriptor
  ) async throws(AuraError) -> ScreenCaptureOutcome {
    let image = try await windowSource.captureImage(
      windowID: windowID, region: region, maxDimension: configuration.maxCaptureDimension)

    let redaction = try await redactCapture(
      image: image, descriptor: descriptor, region: region)
    let observation = makeObservation(
      image: image, descriptor: descriptor, windowID: windowID, region: region,
      redaction: redaction)

    if configuration.retainRawFrames {
      retainRawFrame(id: observation.id, image: image, capturedAt: observation.capturedAt)
      await emit(
        ScreenRawFrameRetainedEvent(
          observationID: observation.id, retentionDays: screenshotRetentionDays,
          retainedAt: observation.capturedAt),
        actor: actor, correlationID: correlationID)
    }

    await emit(
      ScreenObservationRecordedEvent(
        observationID: observation.id, windowID: windowID,
        appBundleIdentifier: descriptor.applicationBundleIdentifier,
        redactionCount: observation.redactions.count, contentHash: observation.contentHash),
      actor: actor, correlationID: correlationID)

    return .captured(observation)
  }

  private func redactCapture(
    image: CGImage,
    descriptor: ScreenWindowDescriptor,
    region: CaptureRegion?
  ) async throws(AuraError) -> ScreenCaptureRedaction {
    let recognizedText =
      configuration.ocrRedactionEnabled
      ? try await textRecognizer.recognizeText(in: image) : []
    let secureFieldFocused: Bool
    if let bundleID = descriptor.applicationBundleIdentifier {
      secureFieldFocused = await secureFieldDetector.isSecureFieldFocused(
        applicationBundleIdentifier: bundleID)
    } else {
      secureFieldFocused = false
    }
    let userRegions = Self.regionsRelativeToCapture(
      configuration.userDefinedRedactionRegions, capturedRegion: region)
    let redactions = redactionPipeline.redactions(
      recognizedText: recognizedText, isSecureFieldFocused: secureFieldFocused,
      userDefinedRegions: userRegions, configuredPatterns: configuration.redactionPatterns)
    let titleRedactor = OutputRedactor(rules: configuration.redactionPatterns)
    return ScreenCaptureRedaction(
      redactions: redactions, redactedTitle: descriptor.title.map { titleRedactor.redact($0) })
  }

  private func makeObservation(
    image: CGImage,
    descriptor: ScreenWindowDescriptor,
    windowID: Int,
    region: CaptureRegion?,
    redaction: ScreenCaptureRedaction
  ) -> ScreenObservation {
    let capturedWidthInPoints = (region?.width ?? 1) * descriptor.frameWidth
    let capturedAt = Date()
    return ScreenObservation(
      capturedAt: capturedAt,
      freshnessDeadline: capturedAt.addingTimeInterval(configuration.freshnessSeconds),
      appBundleIdentifier: descriptor.applicationBundleIdentifier,
      appName: descriptor.applicationName, windowID: windowID,
      windowTitle: redaction.redactedTitle, frameX: descriptor.frameX, frameY: descriptor.frameY,
      frameWidth: descriptor.frameWidth, frameHeight: descriptor.frameHeight,
      capturedRegion: region, displayScale: Double(image.width) / max(capturedWidthInPoints, 1),
      redactions: redaction.redactions, contentHash: Self.contentHash(of: image),
      summary: Self.summary(appName: descriptor.applicationName, redactions: redaction.redactions),
      rawImageRetained: configuration.retainRawFrames)
  }

  /// Number of raw frames currently retained (diagnostics only).
  public func retainedFrameCount() -> Int {
    retainedRawFrames.count
  }

  /// Evict any retained raw frame whose `screenshotRetentionDays` window has
  /// elapsed as of `referenceDate`. Called automatically whenever a new
  /// frame is retained; also exposed directly so retention expiry itself is
  /// deterministically testable without waiting real days.
  @discardableResult
  public func purgeExpiredRawFrames(referenceDate: Date = Date()) -> Int {
    let cutoff = TimeInterval(screenshotRetentionDays) * 86_400
    let before = retainedRawFrames.count
    retainedRawFrames.removeAll { referenceDate.timeIntervalSince($0.capturedAt) >= cutoff }
    return before - retainedRawFrames.count
  }

  // MARK: - Exclusion

  private func isApproved(_ descriptor: ScreenWindowDescriptor) -> Bool {
    guard descriptor.isOnScreen else { return false }
    if let bundleID = descriptor.applicationBundleIdentifier {
      if bundleID == assistantBundleIdentifier { return false }
      if configuration.sensitiveApplicationBundleIdentifiers.contains(bundleID) { return false }
    }
    return true
  }

  // MARK: - Region math

  /// Clip window-relative `regions` to `capturedRegion` and re-express the
  /// surviving parts relative to it. `capturedRegion == nil` (whole window
  /// captured) returns `regions` unchanged. A region with no overlap at all
  /// is dropped — it is not visible in this particular capture.
  static func regionsRelativeToCapture(
    _ regions: [UserDefinedRedactionRegion], capturedRegion: CaptureRegion?
  ) -> [UserDefinedRedactionRegion] {
    guard let capturedRegion, capturedRegion.width > 0, capturedRegion.height > 0 else {
      return capturedRegion == nil ? regions : []
    }
    return regions.compactMap { region in
      let clippedMinX = max(region.originX, capturedRegion.originX)
      let clippedMinY = max(region.originY, capturedRegion.originY)
      let clippedMaxX = min(
        region.originX + region.width, capturedRegion.originX + capturedRegion.width)
      let clippedMaxY = min(
        region.originY + region.height, capturedRegion.originY + capturedRegion.height)
      guard clippedMaxX > clippedMinX, clippedMaxY > clippedMinY else { return nil }
      return UserDefinedRedactionRegion(
        originX: (clippedMinX - capturedRegion.originX) / capturedRegion.width,
        originY: (clippedMinY - capturedRegion.originY) / capturedRegion.height,
        width: (clippedMaxX - clippedMinX) / capturedRegion.width,
        height: (clippedMaxY - clippedMinY) / capturedRegion.height
      )
    }
  }

  // MARK: - Retention

  private func retainRawFrame(id: UUID, image: CGImage, capturedAt: Date) {
    purgeExpiredRawFrames(referenceDate: capturedAt)
    retainedRawFrames.append(RetainedRawFrame(id: id, image: image, capturedAt: capturedAt))
    if retainedRawFrames.count > maxRetainedFrames {
      retainedRawFrames.removeFirst(retainedRawFrames.count - maxRetainedFrames)
    }
  }

  // MARK: - Helpers

  private func block(
    _ reason: ScreenCaptureBlockReason, windowID: Int, actor: ActorID, correlationID: UUID
  ) async -> ScreenCaptureOutcome {
    await emit(
      ScreenCaptureBlockedEvent(windowID: windowID, reason: reason), actor: actor,
      correlationID: correlationID)
    return .blocked(reason: reason)
  }

  private static func contentHash(of image: CGImage) -> String {
    let data: Data = (image.dataProvider?.data as Data?) ?? Data()
    return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
  }

  private static func summary(appName: String?, redactions: [RedactionMatch]) -> String {
    let appDescription = appName ?? "unknown application"
    guard !redactions.isEmpty else {
      return "Captured window of \(appDescription); no redactions applied."
    }
    let categoryCounts = Dictionary(grouping: redactions, by: \.category)
      .map { "\($0.value.count) \($0.key.rawValue)" }
      .sorted()
      .joined(separator: ", ")
    return
      "Captured window of \(appDescription); redacted \(redactions.count) "
      + "region(s): \(categoryCounts)."
  }

  private func emit<Payload: EventPayload>(
    _ payload: Payload, actor: ActorID, correlationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: correlationID, actor: actor,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }
}
