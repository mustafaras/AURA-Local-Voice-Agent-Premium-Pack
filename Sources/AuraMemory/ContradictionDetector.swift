import AuraCore
import AuraStore
import Foundation

/// Detects contradictions between a candidate memory record and existing
/// active records. A contradiction is detected when two active records share
/// the same `(memoryClass, subject, scope)` key but have different
/// `statement`s. Supersession records are excluded from contradiction checks
/// by design: an explicit correction is intentional belief revision, not a
/// surprise conflict.
public actor ContradictionDetector {
  private let store: AuraStore

  public init(store: AuraStore) {
    self.store = store
  }

  /// Search for a contradiction caused by appending `draft`. Returns the
  /// first active existing record whose statement differs, or `nil` if no
  /// contradiction exists.
  public func detect(
    draft: MemoryRecordDraft,
    excludingRecordID excludedID: UUID? = nil
  ) async throws(AuraError) -> MemoryRecord? {
    // Intentional corrections never raise contradictions.
    guard draft.supersedes == nil else { return nil }

    let candidates = try await store.memoryRecords(
      matching: MemoryQuery(
        memoryClass: draft.memoryClass, subject: draft.subject, includeSuperseded: false))
    let sameScope = candidates.filter { $0.scope == draft.scope }
    return sameScope.first { record in
      record.id != excludedID && record.statement != draft.statement
    }
  }
}
