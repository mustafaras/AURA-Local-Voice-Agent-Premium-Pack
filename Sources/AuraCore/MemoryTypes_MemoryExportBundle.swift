import Foundation

/// A user-facing export bundle for inspection/export of non-audit memory.
public struct MemoryExportBundle: Sendable, Equatable {
  public let generatedAt: Date
  public let records: [MemoryRecord]
  public let conflicts: [MemoryConflict]

  public init(generatedAt: Date = Date(), records: [MemoryRecord], conflicts: [MemoryConflict]) {
    self.generatedAt = generatedAt
    self.records = records
    self.conflicts = conflicts
  }
}
