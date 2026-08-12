import Foundation

// MARK: - Memory record

/// An immutable, append-only memory record.
///
/// There is deliberately no stored `supersededBy` field, even though the
/// memory record schema is described in terms of "supersedes/superseded-by":
/// storing a reverse pointer would require mutating an older record after
/// the fact, which breaks true append-only immutability. `supersedes` is the
/// only stored (forward) pointer; "superseded-by" is always a derived,
/// query-time relationship (`MemoryEngine.supersedingRecord(of:)`).
public struct MemoryRecord: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let memoryClass: MemoryClass
  public let subject: String
  public let statement: String
  public let evidenceReferences: [String]
  public let provenance: MemoryProvenance
  public let confidence: Double
  public let sensitivity: SensitivityLevel
  public let createdAt: Date
  public let observedAt: Date
  public let retention: MemoryRetentionPolicy
  /// Why this record is being retained. This is metadata, not authority: the
  /// provenance and evidence fields remain the source of truth for trust.
  public let purpose: String
  public let supersedes: UUID?
  public let scope: MemoryScope

  public init(
    id: UUID = UUID(),
    memoryClass: MemoryClass,
    subject: String,
    statement: String,
    evidenceReferences: [String] = [],
    provenance: MemoryProvenance,
    confidence: Double,
    sensitivity: SensitivityLevel,
    createdAt: Date = Date(),
    observedAt: Date? = nil,
    retention: MemoryRetentionPolicy,
    purpose: String = "unspecified",
    supersedes: UUID? = nil,
    scope: MemoryScope = .global
  ) {
    self.id = id
    self.memoryClass = memoryClass
    self.subject = subject
    self.statement = statement
    self.evidenceReferences = evidenceReferences
    self.provenance = provenance
    self.confidence = min(max(confidence, 0), 1)
    self.sensitivity = sensitivity
    self.createdAt = createdAt
    self.observedAt = observedAt ?? createdAt
    self.retention = retention
    self.purpose = purpose
    self.supersedes = supersedes
    self.scope = scope
  }
}
