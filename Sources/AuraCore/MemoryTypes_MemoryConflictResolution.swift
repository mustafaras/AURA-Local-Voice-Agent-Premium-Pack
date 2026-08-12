import Foundation

// MARK: - Conflict record

/// How a detected memory conflict was resolved. `nil` on `MemoryConflict`
/// means still unresolved.
public enum MemoryConflictResolution: Codable, Sendable, Equatable {
  /// The new record was accepted as an explicit correction of the existing
  /// one (a subsequent `supersedes`-linked record was appended).
  case supersededExisting
  /// The existing record was kept; the new, conflicting record stands as a
  /// disagreement rather than a correction.
  case keptExisting(reason: String)
  /// Both records are legitimately valid simultaneously (e.g. genuinely
  /// different scopes that were not distinguished in the subject key).
  case bothRetained(reason: String)
}
