import Foundation

/// An append-only record of a detected contradiction between two memory
/// records sharing the same `(memoryClass, subject, scope)` key.
///
/// Unlike `MemoryRecord`, `resolution` is mutable in place — it represents
/// current triage status of an operational conflict, not a memory statement
/// whose history must itself be preserved verbatim.
public struct MemoryConflict: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let memoryClass: MemoryClass
  public let subject: String
  public let existingRecordID: UUID
  public let newRecordID: UUID
  public let detectedAt: Date
  public var resolution: MemoryConflictResolution?

  public init(
    id: UUID = UUID(),
    memoryClass: MemoryClass,
    subject: String,
    existingRecordID: UUID,
    newRecordID: UUID,
    detectedAt: Date = Date(),
    resolution: MemoryConflictResolution? = nil
  ) {
    self.id = id
    self.memoryClass = memoryClass
    self.subject = subject
    self.existingRecordID = existingRecordID
    self.newRecordID = newRecordID
    self.detectedAt = detectedAt
    self.resolution = resolution
  }
}
