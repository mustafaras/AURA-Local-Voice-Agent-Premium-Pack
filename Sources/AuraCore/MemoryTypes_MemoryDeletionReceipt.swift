import Foundation

// MARK: - Deletion and export

/// Proof that a memory record was deleted, without preserving the deleted
/// content itself — "corrections/deletions preserve provenance" without
/// defeating the purpose of deletion.
public struct MemoryDeletionReceipt: Sendable, Equatable {
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
