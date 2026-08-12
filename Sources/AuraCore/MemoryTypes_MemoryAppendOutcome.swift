import Foundation

// MARK: - Append outcome

/// Result of `MemoryEngine.append`.
public enum MemoryAppendOutcome: Sendable, Equatable {
  /// Recorded with no detected conflict (including intentional
  /// supersession, which is never treated as a surprise conflict).
  case recorded(MemoryRecord)
  /// Recorded, but a conflict was also detected and recorded against a
  /// prior active record for the same key.
  case recordedWithConflict(MemoryRecord, MemoryConflict)
}
