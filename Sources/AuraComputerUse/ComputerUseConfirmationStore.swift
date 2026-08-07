import AuraCore
import Foundation

// MARK: - Confirmation checkpoint

/// A persisted, hash-bound confirmation checkpoint for one computer-use
/// step (R4 section D). Storing the immutable plan fingerprint plus the
/// observation's content/structural hash and app/window identity — not the
/// mutable plan object itself — means a resumed checkpoint can fail closed
/// if any of the fields that invalidate it changed.
public struct ComputerUseConfirmationCheckpoint: Sendable, Equatable {
  public let checkpointID: UUID
  public let planFingerprint: String
  public let observationContentHash: String
  public let observationStructuralHash: String
  public let appBundleIdentifier: String
  public let windowID: Int
  /// The anchor the step targets — identity/position must not drift.
  public let anchor: UIAnchor
  public let nonce: UUID
  public let expiresAt: Date
  /// Whether this checkpoint has already been executed (one-time execution).
  public let consumed: Bool

  public init(
    checkpointID: UUID = UUID(),
    planFingerprint: String,
    observationContentHash: String,
    observationStructuralHash: String,
    appBundleIdentifier: String,
    windowID: Int,
    anchor: UIAnchor,
    nonce: UUID = UUID(),
    expiresAt: Date,
    consumed: Bool = false
  ) {
    self.checkpointID = checkpointID
    self.planFingerprint = planFingerprint
    self.observationContentHash = observationContentHash
    self.observationStructuralHash = observationStructuralHash
    self.appBundleIdentifier = appBundleIdentifier
    self.windowID = windowID
    self.anchor = anchor
    self.nonce = nonce
    self.expiresAt = expiresAt
    self.consumed = consumed
  }
}

/// Whether a resumed checkpoint is safe to execute against a fresh
/// observation, and if not, why — mirroring ADR-037's fail-closed
/// confirmation discipline applied to the computer-use path.
public enum ComputerUseConfirmationValidity: Sendable, Equatable {
  case valid
  case expired
  case alreadyConsumed
  case appIdentityChanged(expected: String, observed: String?)
  case windowChanged(expected: Int, observed: Int)
  case contentChanged
  case structuralChanged
  case anchorChanged
  case secureFieldStateChanged
  case unexpectedModalPresent
}

// MARK: - Confirmation store

/// An actor that persists and validates resumable confirmation checkpoints.
/// In-memory for this pass (matching ADR-037's in-memory transaction store),
/// with the same fail-closed philosophy: a checkpoint whose plan/observation/
/// identity/anchor/secure-field/modal state changed is rejected rather than
/// replayed, and each checkpoint executes at most once.
public actor ComputerUseConfirmationStore {
  private var checkpoints: [UUID: ComputerUseConfirmationCheckpoint] = [:]
  private let defaultTTLSeconds: TimeInterval

  public init(defaultTTLSeconds: TimeInterval = 120) {
    self.defaultTTLSeconds = defaultTTLSeconds
  }

  /// Persist a new pending checkpoint.
  public func persist(
    planFingerprint: String,
    observation: ComputerUseObservation,
    anchor: UIAnchor,
    ttlSeconds: TimeInterval? = nil
  ) -> ComputerUseConfirmationCheckpoint {
    let now = Date()
    let checkpoint = ComputerUseConfirmationCheckpoint(
      planFingerprint: planFingerprint,
      observationContentHash: observation.contentHash,
      observationStructuralHash: observation.structuralHash,
      appBundleIdentifier: observation.appBundleIdentifier ?? "",
      windowID: observation.windowID,
      anchor: anchor,
      expiresAt: now.addingTimeInterval(ttlSeconds ?? defaultTTLSeconds))
    checkpoints[checkpoint.checkpointID] = checkpoint
    return checkpoint
  }

  /// Validate a checkpoint against a freshly recaptured observation and the
  /// plan it binds to. On `.valid`, consumes the checkpoint (one-time
  /// execution) so a replay is rejected. On any failure, leaves it
  /// un-consumed and returns the reason.
  public func validateAndConsume(
    checkpointID: UUID,
    planFingerprint: String,
    recaptured: ComputerUseObservation,
    referenceDate: Date = Date()
  ) -> ComputerUseConfirmationValidity {
    guard let checkpoint = checkpoints[checkpointID] else {
      return .expired
    }
    guard !checkpoint.consumed else { return .alreadyConsumed }
    guard referenceDate < checkpoint.expiresAt else { return .expired }
    guard checkpoint.planFingerprint == planFingerprint else { return .structuralChanged }
    guard checkpoint.appBundleIdentifier == (recaptured.appBundleIdentifier ?? "") else {
      return .appIdentityChanged(
        expected: checkpoint.appBundleIdentifier, observed: recaptured.appBundleIdentifier)
    }
    guard checkpoint.windowID == recaptured.windowID else {
      return .windowChanged(expected: checkpoint.windowID, observed: recaptured.windowID)
    }
    guard checkpoint.observationContentHash == recaptured.contentHash else {
      return .contentChanged
    }
    guard checkpoint.observationStructuralHash == recaptured.structuralHash else {
      return .structuralChanged
    }
    let resolvedAnchor: UIAnchor = recaptured.controlCandidates.first.map { candidate in
      UIAnchor(
        accessibilityRole: candidate.role, accessibilityTitle: candidate.title,
        accessibilityIdentifier: candidate.identifier,
        fallbackNormalizedX: candidate.fallbackNormalizedX,
        fallbackNormalizedY: candidate.fallbackNormalizedY)
    } ?? checkpoint.anchor
    guard checkpoint.anchor == resolvedAnchor else {
      // If a candidate is present it must resolve to the same anchor the
      // plan targeted; if none is present the plan's own anchor still binds.
      return .anchorChanged
    }
    if recaptured.secureFieldFocused { return .secureFieldStateChanged }
    if recaptured.modalState != .none { return .unexpectedModalPresent }

    // Consume: one-time execution.
    checkpoints[checkpointID] = ComputerUseConfirmationCheckpoint(
      checkpointID: checkpoint.checkpointID,
      planFingerprint: checkpoint.planFingerprint,
      observationContentHash: checkpoint.observationContentHash,
      observationStructuralHash: checkpoint.observationStructuralHash,
      appBundleIdentifier: checkpoint.appBundleIdentifier,
      windowID: checkpoint.windowID,
      anchor: checkpoint.anchor,
      nonce: checkpoint.nonce,
      expiresAt: checkpoint.expiresAt,
      consumed: true)
    return .valid
  }
}
