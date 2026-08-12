import Foundation

/// A policy-aware request to persist memory. Callers that are crossing a
/// subsystem boundary should use this type instead of treating a plain draft
/// as implicit authorization to retain user data.
public struct MemoryWriteRequest: Sendable, Equatable {
  public let draft: MemoryRecordDraft
  public let source: MemoryWriteSource

  public init(draft: MemoryRecordDraft, source: MemoryWriteSource) {
    self.draft = draft
    self.source = source
  }
}
