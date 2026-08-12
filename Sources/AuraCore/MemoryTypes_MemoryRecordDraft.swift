import Foundation

/// A request to append a new memory record, before an ID/timestamp is
/// assigned by `MemoryEngine`.
public struct MemoryRecordDraft: Sendable, Equatable {
  public let memoryClass: MemoryClass
  public let subject: String
  public let statement: String
  public let evidenceReferences: [String]
  public let provenance: MemoryProvenance
  public let confidence: Double
  public let sensitivity: SensitivityLevel
  public let observedAt: Date?
  public let retention: MemoryRetentionPolicy
  public let purpose: String
  public let supersedes: UUID?
  public let scope: MemoryScope

  public init(
    memoryClass: MemoryClass,
    subject: String,
    statement: String,
    evidenceReferences: [String] = [],
    provenance: MemoryProvenance,
    confidence: Double = 1.0,
    sensitivity: SensitivityLevel,
    observedAt: Date? = nil,
    retention: MemoryRetentionPolicy,
    purpose: String = "unspecified",
    supersedes: UUID? = nil,
    scope: MemoryScope = .global
  ) {
    self.memoryClass = memoryClass
    self.subject = subject
    self.statement = statement
    self.evidenceReferences = evidenceReferences
    self.provenance = provenance
    self.confidence = confidence
    self.sensitivity = sensitivity
    self.observedAt = observedAt
    self.retention = retention
    self.purpose = purpose
    self.supersedes = supersedes
    self.scope = scope
  }
}
