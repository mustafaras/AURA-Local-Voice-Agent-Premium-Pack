import AuraCore
import AuraScreen
import Foundation

// MARK: - Accessibility-tree summary

/// A bounded, redaction-safe summary of one element in the approved target
/// application's Accessibility tree. Deliberately carries only the fields
/// the R4 observation contract names (roles/labels/identifiers/values/
/// states/actions) — never raw frame data or the full tree — and never
/// includes the content of a secure field.
public struct ComputerUseAccessibilityElement: Sendable, Equatable {
  public let role: String
  public let title: String?
  public let identifier: String?
  public let value: String?
  public let actions: [String]
  public let isEnabled: Bool
  public let isFocused: Bool

  public init(
    role: String,
    title: String? = nil,
    identifier: String? = nil,
    value: String? = nil,
    actions: [String] = [],
    isEnabled: Bool = true,
    isFocused: Bool = false
  ) {
    self.role = role
    self.title = title
    self.identifier = identifier
    self.value = value
    self.actions = actions
    self.isEnabled = isEnabled
    self.isFocused = isFocused
  }
}

// MARK: - Semantic control candidates

/// A control the planner may target, derived from the Accessibility tree.
/// Anchoring prefers these semantic candidates over raw coordinates per
/// ADR-019 decision 5.
public struct ComputerUseControlCandidate: Sendable, Equatable {
  public let role: String
  public let title: String?
  public let identifier: String?
  /// A normalized, window-relative coordinate fallback, matching
  /// `UIAnchor`'s convention.
  public let fallbackNormalizedX: Double?
  public let fallbackNormalizedY: Double?

  public init(
    role: String,
    title: String? = nil,
    identifier: String? = nil,
    fallbackNormalizedX: Double? = nil,
    fallbackNormalizedY: Double? = nil
  ) {
    self.role = role
    self.title = title
    self.identifier = identifier
    self.fallbackNormalizedX = fallbackNormalizedX
    self.fallbackNormalizedY = fallbackNormalizedY
  }
}

// MARK: - Capture/redaction provenance

/// Which source produced the observation content and whether any redaction
/// was applied — the prompt's "capture/redaction provenance."
public struct ComputerUseCaptureProvenance: Sendable, Equatable {
  public let capturedAt: Date
  public let source: ComputerUseObservationSource
  public let redactionCount: Int
  public let rawImageRetained: Bool

  public init(
    capturedAt: Date,
    source: ComputerUseObservationSource,
    redactionCount: Int,
    rawImageRetained: Bool
  ) {
    self.capturedAt = capturedAt
    self.source = source
    self.redactionCount = redactionCount
    self.rawImageRetained = rawImageRetained
  }
}

/// Where the observation's content came from — Accessibility tree, OCR/redacted
/// text, or both. Prefer Accessibility data per the R4 prompt.
public enum ComputerUseObservationSource: String, Sendable, Equatable, CaseIterable {
  case accessibility
  case ocrRedacted
  case accessibilityAndOcr
}

// MARK: - Modal state

/// Modal/sensitive-window state relevant to whether the planner may act.
public enum ComputerUseModalState: String, Sendable, Equatable, CaseIterable {
  case none
  case unexpectedModalPresent
  case sensitiveSurfacePresent
}

// MARK: - Production observation

/// The bounded observation a `ComputerUsePlanning` conformer consumes in R4 —
/// composes over a redaction-safe `ScreenObservation` and adds the
/// planner-relevant structured fields the prompt's "Observation contract"
/// names. Never retains the raw frame by default.
public struct ComputerUseObservation: Sendable, Equatable, Identifiable {
  public let id: UUID
  /// The underlying redaction-safe screen capture this observation derives
  /// from. `contentHash`/`windowID`/`appBundleIdentifier`/frame live here.
  public let screen: ScreenObservation
  /// Bounded Accessibility-tree summary (roles/labels/identifiers/values/
  /// states/actions) for the approved target app — never the full tree.
  public let accessibilityElements: [ComputerUseAccessibilityElement]
  /// Semantic control candidates the planner may target.
  public let controlCandidates: [ComputerUseControlCandidate]
  /// Whether a secure field is focused in the target application (never its
  /// content).
  public let secureFieldFocused: Bool
  /// Modal / sensitive-window state.
  public let modalState: ComputerUseModalState
  /// Structural hash over the accessibility summary + candidates — distinct
  /// from the raw image `contentHash` on `screen`. "Hash change alone is
  /// insufficient for success" (R4 Verification) means a planner/verifier
  /// must use semantic postconditions, but this structural hash is a valid
  /// additional signal.
  public let structuralHash: String
  /// Capture/redaction provenance.
  public let provenance: ComputerUseCaptureProvenance

  public var isFresh: Bool { screen.isFresh }
  public var appBundleIdentifier: String? { screen.appBundleIdentifier }
  public var windowID: Int { screen.windowID }
  public var contentHash: String { screen.contentHash }

  public init(
    id: UUID = UUID(),
    screen: ScreenObservation,
    accessibilityElements: [ComputerUseAccessibilityElement],
    controlCandidates: [ComputerUseControlCandidate],
    secureFieldFocused: Bool,
    modalState: ComputerUseModalState,
    structuralHash: String,
    provenance: ComputerUseCaptureProvenance
  ) {
    self.id = id
    self.screen = screen
    self.accessibilityElements = accessibilityElements
    self.controlCandidates = controlCandidates
    self.secureFieldFocused = secureFieldFocused
    self.modalState = modalState
    self.structuralHash = structuralHash
    self.provenance = provenance
  }
}
