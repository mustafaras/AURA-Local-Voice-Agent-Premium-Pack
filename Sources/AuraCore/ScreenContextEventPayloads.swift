import Foundation

// MARK: - Screen context event payloads

/// Emitted when a window capture is requested, before any policy or
/// exclusion check runs.
public struct ScreenCaptureRequestedEvent: EventPayload {
  public static let eventType = "screen.capture.requested"

  public let windowID: Int
  public let requestedAt: Date

  public init(windowID: Int, requestedAt: Date = Date()) {
    self.windowID = windowID
    self.requestedAt = requestedAt
  }
}

/// Emitted when a capture request is blocked before any image is captured.
public struct ScreenCaptureBlockedEvent: EventPayload {
  public static let eventType = "screen.capture.blocked"

  public let windowID: Int
  public let reason: ScreenCaptureBlockReason
  public let blockedAt: Date

  public init(windowID: Int, reason: ScreenCaptureBlockReason, blockedAt: Date = Date()) {
    self.windowID = windowID
    self.reason = reason
    self.blockedAt = blockedAt
  }
}

/// Emitted when a `ScreenObservation` is successfully recorded. Carries only
/// metadata — never the raw image or unredacted text.
public struct ScreenObservationRecordedEvent: EventPayload {
  public static let eventType = "screen.observation.recorded"

  public let observationID: UUID
  public let windowID: Int
  public let appBundleIdentifier: String?
  public let redactionCount: Int
  public let contentHash: String
  public let recordedAt: Date

  public init(
    observationID: UUID,
    windowID: Int,
    appBundleIdentifier: String?,
    redactionCount: Int,
    contentHash: String,
    recordedAt: Date = Date()
  ) {
    self.observationID = observationID
    self.windowID = windowID
    self.appBundleIdentifier = appBundleIdentifier
    self.redactionCount = redactionCount
    self.contentHash = contentHash
    self.recordedAt = recordedAt
  }
}

/// Emitted only on the rare, explicitly-opted-in path where a raw captured
/// image is retained in memory for diagnostics — auditable precisely because
/// it should almost never fire.
public struct ScreenRawFrameRetainedEvent: EventPayload {
  public static let eventType = "screen.rawFrame.retained"

  public let observationID: UUID
  public let retentionDays: Int
  public let retainedAt: Date

  public init(observationID: UUID, retentionDays: Int, retainedAt: Date = Date()) {
    self.observationID = observationID
    self.retentionDays = retentionDays
    self.retainedAt = retainedAt
  }
}
