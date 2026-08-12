import Foundation

/// The origin of a requested memory write. This is deliberately narrower than
/// `MemoryProvenance`: provenance describes what was recorded, while this
/// value describes whether the caller is allowed to persist it at all.
public enum MemoryWriteSource: Codable, Sendable, Equatable {
  case explicitUser
  case verifiedToolEvidence(actor: ActorID)
  case activeDurableTask
  case approvedSummary
  case classifierDerived
  case inferred
  case modelOutput
  case untrustedExternalContent
  case rawContent
}
