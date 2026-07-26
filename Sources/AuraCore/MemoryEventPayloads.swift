import Foundation

// MARK: - Memory engine event payloads

/// Emitted when a new memory record is appended.
public struct MemoryRecordAppendedEvent: EventPayload {
  public static let eventType = "memory.record.appended"

  public let recordID: UUID
  public let memoryClass: MemoryClass
  public let sensitivity: SensitivityLevel
  public let supersedes: UUID?
  public let appendedAt: Date

  public init(
    recordID: UUID,
    memoryClass: MemoryClass,
    sensitivity: SensitivityLevel,
    supersedes: UUID?,
    appendedAt: Date = Date()
  ) {
    self.recordID = recordID
    self.memoryClass = memoryClass
    self.sensitivity = sensitivity
    self.supersedes = supersedes
    self.appendedAt = appendedAt
  }
}

/// Emitted when appending a new record detects a contradiction against an
/// existing active record for the same `(memoryClass, subject, scope)` key.
public struct MemoryConflictDetectedEvent: EventPayload {
  public static let eventType = "memory.conflict.detected"

  public let conflictID: UUID
  public let memoryClass: MemoryClass
  public let existingRecordID: UUID
  public let newRecordID: UUID
  public let detectedAt: Date

  public init(
    conflictID: UUID,
    memoryClass: MemoryClass,
    existingRecordID: UUID,
    newRecordID: UUID,
    detectedAt: Date = Date()
  ) {
    self.conflictID = conflictID
    self.memoryClass = memoryClass
    self.existingRecordID = existingRecordID
    self.newRecordID = newRecordID
    self.detectedAt = detectedAt
  }
}

/// Emitted when a conflict's resolution status is set.
public struct MemoryConflictResolvedEvent: EventPayload {
  public static let eventType = "memory.conflict.resolved"

  public enum Resolution: String, Codable, Sendable, Equatable {
    case supersededExisting
    case keptExisting
    case bothRetained
  }

  public let conflictID: UUID
  public let resolution: Resolution
  public let resolvedAt: Date

  public init(conflictID: UUID, resolution: Resolution, resolvedAt: Date = Date()) {
    self.conflictID = conflictID
    self.resolution = resolution
    self.resolvedAt = resolvedAt
  }
}

/// Emitted when a user-initiated correction appends a superseding record.
public struct MemoryCorrectedEvent: EventPayload {
  public static let eventType = "memory.record.corrected"

  public let previousRecordID: UUID
  public let newRecordID: UUID
  public let reason: String
  public let correctedAt: Date

  public init(
    previousRecordID: UUID, newRecordID: UUID, reason: String, correctedAt: Date = Date()
  ) {
    self.previousRecordID = previousRecordID
    self.newRecordID = newRecordID
    self.reason = reason
    self.correctedAt = correctedAt
  }
}

/// Emitted when a memory record is deleted.
///
/// Deliberately carries no `subject`/`statement` — the whole point of
/// deletion is to remove content, so its own audit trail must not resurrect
/// that content. Only enough metadata to prove deletion occurred and why.
public struct MemoryDeletedEvent: EventPayload {
  public static let eventType = "memory.record.deleted"

  public let recordID: UUID
  public let memoryClass: MemoryClass
  public let reason: String
  public let deletedAt: Date

  public init(recordID: UUID, memoryClass: MemoryClass, reason: String, deletedAt: Date = Date()) {
    self.recordID = recordID
    self.memoryClass = memoryClass
    self.reason = reason
    self.deletedAt = deletedAt
  }
}

/// Emitted after a retention sweep purges expired records.
public struct MemoryRetentionPurgedEvent: EventPayload {
  public static let eventType = "memory.retention.purged"

  public let purgedCount: Int
  public let purgedAt: Date

  public init(purgedCount: Int, purgedAt: Date = Date()) {
    self.purgedCount = purgedCount
    self.purgedAt = purgedAt
  }
}
