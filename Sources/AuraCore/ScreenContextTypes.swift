import Foundation

// MARK: - Window descriptor

/// A source-agnostic description of one capturable window.
///
/// Real `SCWindow`/`SCRunningApplication` instances (`ScreenCaptureKit`) have
/// no public initializer — they can only come from `SCShareableContent`, so
/// this plain, constructible struct is what makes window filtering and
/// redaction logic testable without a live capture session.
public struct ScreenWindowDescriptor: Codable, Sendable, Equatable, Identifiable {
  public var id: Int { windowID }
  public let windowID: Int
  public let title: String?
  public let applicationBundleIdentifier: String?
  public let applicationName: String?
  public let frameX: Double
  public let frameY: Double
  public let frameWidth: Double
  public let frameHeight: Double
  public let isOnScreen: Bool

  public init(
    windowID: Int,
    title: String?,
    applicationBundleIdentifier: String?,
    applicationName: String?,
    frameX: Double,
    frameY: Double,
    frameWidth: Double,
    frameHeight: Double,
    isOnScreen: Bool
  ) {
    self.windowID = windowID
    self.title = title
    self.applicationBundleIdentifier = applicationBundleIdentifier
    self.applicationName = applicationName
    self.frameX = frameX
    self.frameY = frameY
    self.frameWidth = frameWidth
    self.frameHeight = frameHeight
    self.isOnScreen = isOnScreen
  }
}

// MARK: - Recognized text region

/// One OCR-recognized text region from a captured window image.
///
/// Bounding box fields are normalized `[0, 1]` fractions of the image,
/// matching `Vision`'s `VNRecognizedTextObservation.boundingBox` convention,
/// so `RedactionPipeline` never needs to know the image's pixel dimensions.
public struct RecognizedTextRegion: Sendable, Equatable {
  public let text: String
  public let boundingBoxX: Double
  public let boundingBoxY: Double
  public let boundingBoxWidth: Double
  public let boundingBoxHeight: Double

  public init(
    text: String,
    boundingBoxX: Double,
    boundingBoxY: Double,
    boundingBoxWidth: Double,
    boundingBoxHeight: Double
  ) {
    self.text = text
    self.boundingBoxX = boundingBoxX
    self.boundingBoxY = boundingBoxY
    self.boundingBoxWidth = boundingBoxWidth
    self.boundingBoxHeight = boundingBoxHeight
  }
}

// MARK: - Redaction

/// Why a region of a captured window was masked.
///
/// "Password managers" and "private notifications" from the normative spec
/// are deliberately not separate cases here — they are enforced as hard
/// pre-capture exclusions (the whole window is never captured; see
/// `ScreenCaptureBlockReason.sensitiveApplication`), which is a strictly
/// stronger guarantee than post-hoc pixel redaction within a capture that
/// happened anyway.
public enum RedactionCategory: String, Codable, Sendable, Equatable, CaseIterable {
  case secureTextField
  case authenticationCode
  case financialData
  case userDefinedRegion
  case patternMatchedSecret
}

/// One masked region of a captured window. Deliberately carries only a
/// non-sensitive `patternDescription` (e.g. "16-digit-card-shaped"), never
/// the matched text itself — the whole point of redaction is that the
/// sensitive content does not survive into the observation.
public struct RedactionMatch: Sendable, Equatable {
  public let category: RedactionCategory
  public let boundingBoxX: Double
  public let boundingBoxY: Double
  public let boundingBoxWidth: Double
  public let boundingBoxHeight: Double
  public let patternDescription: String

  public init(
    category: RedactionCategory,
    boundingBoxX: Double,
    boundingBoxY: Double,
    boundingBoxWidth: Double,
    boundingBoxHeight: Double,
    patternDescription: String
  ) {
    self.category = category
    self.boundingBoxX = boundingBoxX
    self.boundingBoxY = boundingBoxY
    self.boundingBoxWidth = boundingBoxWidth
    self.boundingBoxHeight = boundingBoxHeight
    self.patternDescription = patternDescription
  }
}

/// A user-defined rectangular region (normalized `[0, 1]`, window-relative)
/// that is always redacted regardless of content.
public struct UserDefinedRedactionRegion: Codable, Sendable, Equatable {
  public let originX: Double
  public let originY: Double
  public let width: Double
  public let height: Double

  public init(originX: Double, originY: Double, width: Double, height: Double) {
    self.originX = originX
    self.originY = originY
    self.width = width
    self.height = height
  }
}

// MARK: - Capture scoping

/// A sub-rectangle of a window to capture, instead of the whole window.
/// Normalized `[0, 1]`, window-relative — the same convention as
/// `RecognizedTextRegion`/`RedactionMatch`/`UserDefinedRedactionRegion` — so
/// callers never need to know a window's real point/pixel dimensions.
///
/// Region scoping is deliberately always a sub-scope of an already-approved
/// window, never an independent screen rectangle: an unscoped display region
/// could straddle a sensitive application's window that was never itself
/// approved, silently bypassing sensitive-app exclusion. Scoping to "this
/// part of this window" preserves the same exclusion guarantees as
/// window-scoped capture.
public struct CaptureRegion: Codable, Sendable, Equatable {
  public let originX: Double
  public let originY: Double
  public let width: Double
  public let height: Double

  public init(originX: Double, originY: Double, width: Double, height: Double) {
    self.originX = originX
    self.originY = originY
    self.width = width
    self.height = height
  }

  /// Whether this region is fully within `[0, 1]` on both axes with a
  /// strictly positive area — an "approved region" must satisfy this before
  /// any capture is attempted.
  public var isValid: Bool {
    guard width > 0, height > 0 else { return false }
    guard originX >= 0, originY >= 0 else { return false }
    guard originX + width <= 1, originY + height <= 1 else { return false }
    return true
  }
}

// MARK: - Capture outcome

/// Why a capture request never produced an observation.
public enum ScreenCaptureBlockReason: String, Codable, Sendable, Equatable {
  case disabledByConfiguration
  case sensitiveApplication
  case assistantSelfExclusion
  case policyDenied
  case windowNotFound
  /// The window exists but is not on screen. Capturing an off-screen or
  /// hidden window is refused; reported distinctly from
  /// `sensitiveApplication` so a hidden-window refusal is never mislabelled
  /// as a sensitive-application refusal in evidence.
  case windowNotVisible
  case invalidRegion
}

/// A structured, redaction-safe record of one window capture. Never carries
/// the raw image — "store structured summaries and hashes, not screenshots,
/// unless diagnostic retention is explicitly enabled."
public struct ScreenObservation: Sendable, Equatable, Identifiable {
  public let id: UUID
  public let capturedAt: Date
  public let freshnessDeadline: Date
  public let appBundleIdentifier: String?
  public let appName: String?
  public let windowID: Int
  /// The window title, itself redacted if it matches a configured secret
  /// pattern (window titles can leak content, e.g. a bank statement's PDF
  /// filename).
  public let windowTitle: String?
  public let frameX: Double
  public let frameY: Double
  public let frameWidth: Double
  public let frameHeight: Double
  /// The sub-region actually captured, window-relative and normalized; `nil`
  /// means the whole window was captured.
  public let capturedRegion: CaptureRegion?
  public let displayScale: Double
  public let redactions: [RedactionMatch]
  /// SHA-256 of the raw captured image bytes — enough to prove what was
  /// captured and detect duplicates, without retaining the image itself.
  public let contentHash: String
  /// Non-sensitive, human-readable description of what was captured and
  /// what was redacted (never the redacted content itself).
  public let summary: String
  /// Whether the raw image was retained in memory for this observation
  /// (only possible when diagnostic retention is explicitly enabled).
  public let rawImageRetained: Bool

  public var isFresh: Bool {
    Date() < freshnessDeadline
  }

  public init(
    id: UUID = UUID(),
    capturedAt: Date,
    freshnessDeadline: Date,
    appBundleIdentifier: String?,
    appName: String?,
    windowID: Int,
    windowTitle: String?,
    frameX: Double,
    frameY: Double,
    frameWidth: Double,
    frameHeight: Double,
    capturedRegion: CaptureRegion? = nil,
    displayScale: Double,
    redactions: [RedactionMatch],
    contentHash: String,
    summary: String,
    rawImageRetained: Bool
  ) {
    self.id = id
    self.capturedAt = capturedAt
    self.freshnessDeadline = freshnessDeadline
    self.appBundleIdentifier = appBundleIdentifier
    self.appName = appName
    self.windowID = windowID
    self.windowTitle = windowTitle
    self.frameX = frameX
    self.frameY = frameY
    self.frameWidth = frameWidth
    self.frameHeight = frameHeight
    self.capturedRegion = capturedRegion
    self.displayScale = displayScale
    self.redactions = redactions
    self.contentHash = contentHash
    self.summary = summary
    self.rawImageRetained = rawImageRetained
  }
}

/// Result of a `ScreenContextEngine.captureWindow` request.
public enum ScreenCaptureOutcome: Sendable, Equatable {
  case captured(ScreenObservation)
  case blocked(reason: ScreenCaptureBlockReason)
}
