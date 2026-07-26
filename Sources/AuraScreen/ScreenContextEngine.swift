import AuraCore
import AuraPolicy
import CoreGraphics
import CryptoKit
import Foundation

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
  private var retainedRawFrames: [(id: UUID, image: CGImage, capturedAt: Date)] = []
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
    await emit(ScreenCaptureRequestedEvent(windowID: windowID), actor: actor, correlationID: correlationID)

    guard configuration.enabled else {
      return await block(.disabledByConfiguration, windowID: windowID, actor: actor, correlationID: correlationID)
    }

    if let region, !region.isValid {
      return await block(.invalidRegion, windowID: windowID, actor: actor, correlationID: correlationID)
    }

    let windows = try await windowSource.listCapturableWindows()
    guard let descriptor = windows.first(where: { $0.windowID == windowID }) else {
      return await block(.windowNotFound, windowID: windowID, actor: actor, correlationID: correlationID)
    }

    guard isApproved(descriptor) else {
      let reason: ScreenCaptureBlockReason =
        descriptor.applicationBundleIdentifier == assistantBundleIdentifier
        ? .assistantSelfExclusion : .sensitiveApplication
      return await block(reason, windowID: windowID, actor: actor, correlationID: correlationID)
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
    guard case .allow = decision else {
      return await block(.policyDenied, windowID: windowID, actor: actor, correlationID: correlationID)
    }

    let image = try await windowSource.captureImage(
      windowID: windowID, region: region, maxDimension: configuration.maxCaptureDimension)

    let recognizedText: [RecognizedTextRegion]
    if configuration.ocrRedactionEnabled {
      recognizedText = try await textRecognizer.recognizeText(in: image)
    } else {
      recognizedText = []
    }

    let isSecureFieldFocused: Bool
    if let bundleID = descriptor.applicationBundleIdentifier {
      isSecureFieldFocused = await secureFieldDetector.isSecureFieldFocused(
        applicationBundleIdentifier: bundleID)
    } else {
      isSecureFieldFocused = false
    }

    // `recognizedText` bounding boxes are already relative to the captured
    // (possibly cropped) image. User-defined regions are always window-
    // relative, so when a sub-region was captured they must be clipped to
    // the captured area and re-expressed relative to it — otherwise a
    // region entirely outside the captured area would either be silently
    // wrong or, worse, be reported as covering the wrong part of the image.
    let userRegionsForThisCapture = Self.regionsRelativeToCapture(
      configuration.userDefinedRedactionRegions, capturedRegion: region)

    let redactions = redactionPipeline.redactions(
      recognizedText: recognizedText,
      isSecureFieldFocused: isSecureFieldFocused,
      userDefinedRegions: userRegionsForThisCapture,
      configuredPatterns: configuration.redactionPatterns
    )

    let titleRedactor = OutputRedactor(rules: configuration.redactionPatterns)
    let redactedTitle = descriptor.title.map { titleRedactor.redact($0) }

    let capturedWidthInPoints = (region?.width ?? 1) * descriptor.frameWidth
    let capturedAt = Date()
    let observation = ScreenObservation(
      capturedAt: capturedAt,
      freshnessDeadline: capturedAt.addingTimeInterval(configuration.freshnessSeconds),
      appBundleIdentifier: descriptor.applicationBundleIdentifier,
      appName: descriptor.applicationName,
      windowID: windowID,
      windowTitle: redactedTitle,
      frameX: descriptor.frameX,
      frameY: descriptor.frameY,
      frameWidth: descriptor.frameWidth,
      frameHeight: descriptor.frameHeight,
      capturedRegion: region,
      displayScale: Double(image.width) / max(capturedWidthInPoints, 1),
      redactions: redactions,
      contentHash: Self.contentHash(of: image),
      summary: Self.summary(appName: descriptor.applicationName, redactions: redactions),
      rawImageRetained: configuration.retainRawFrames
    )

    if configuration.retainRawFrames {
      retainRawFrame(id: observation.id, image: image, capturedAt: capturedAt)
      await emit(
        ScreenRawFrameRetainedEvent(
          observationID: observation.id, retentionDays: screenshotRetentionDays,
          retainedAt: capturedAt),
        actor: actor, correlationID: correlationID)
    }

    await emit(
      ScreenObservationRecordedEvent(
        observationID: observation.id, windowID: windowID,
        appBundleIdentifier: descriptor.applicationBundleIdentifier,
        redactionCount: redactions.count, contentHash: observation.contentHash),
      actor: actor, correlationID: correlationID)

    return .captured(observation)
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
      let x0 = max(region.x, capturedRegion.x)
      let y0 = max(region.y, capturedRegion.y)
      let x1 = min(region.x + region.width, capturedRegion.x + capturedRegion.width)
      let y1 = min(region.y + region.height, capturedRegion.y + capturedRegion.height)
      guard x1 > x0, y1 > y0 else { return nil }
      return UserDefinedRedactionRegion(
        x: (x0 - capturedRegion.x) / capturedRegion.width,
        y: (y0 - capturedRegion.y) / capturedRegion.height,
        width: (x1 - x0) / capturedRegion.width,
        height: (y1 - y0) / capturedRegion.height
      )
    }
  }

  // MARK: - Retention

  private func retainRawFrame(id: UUID, image: CGImage, capturedAt: Date) {
    purgeExpiredRawFrames(referenceDate: capturedAt)
    retainedRawFrames.append((id, image, capturedAt))
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
    return "Captured window of \(appDescription); redacted \(redactions.count) region(s): \(categoryCounts)."
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
