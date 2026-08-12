import Foundation

// MARK: - Retention policy

/// How long a memory record may be retained before it is eligible for
/// automatic purge by `MemoryEngine.enforceRetention`.
public enum MemoryRetentionPolicy: Codable, Sendable, Equatable {
  /// Purged `seconds` after `createdAt` — e.g. an ephemeral audio buffer.
  case ephemeral(seconds: TimeInterval)
  /// Purged when the owning session ends (enforced by the caller passing
  /// the session's end time to `enforceRetention`; the engine itself has no
  /// session-lifecycle awareness).
  case sessionScoped
  /// Retained until explicitly corrected or deleted — project facts,
  /// user-approved preferences, procedural knowledge.
  case indefinite
  /// Fixed, long-lived compliance retention for audit/security records.
  /// Records under this policy can never be deleted by
  /// `MemoryEngine.deleteRecord` (only `enforceRetention`, after the
  /// retention window elapses, may remove them) — audit history must not be
  /// user-erasable on demand.
  case auditRetention(days: Int)
}
