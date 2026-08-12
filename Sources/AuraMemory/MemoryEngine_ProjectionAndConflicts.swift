import AuraCore
import AuraStore
import Foundation

extension MemoryEngine {
  // MARK: - Current-state projection

  /// Project the single current record per `(memoryClass, subject, scope)`
  /// key: the most-recently-created active (non-superseded) record. Unlike
  /// the human-authored `ledger/CURRENT_STATE.md`, this is computed on read
  /// from the append-only table, never separately materialized — a real SQL
  /// backend makes that both simpler and impossible to let drift out of
  /// sync.
  ///
  /// When a conflict left two records simultaneously active for the same
  /// key, the more recent one wins the projection — but the conflict record
  /// itself remains queryable via `conflicts(subject:)`, so the
  /// disagreement is never silently lost, only resolved for display
  /// purposes.
  public func currentState(
    memoryClass: MemoryClass? = nil, subject: String? = nil, scope: MemoryScope? = nil
  ) async throws(AuraError) -> [MemoryRecord] {
    let active = try await store.memoryRecords(
      matching: MemoryQuery(
        memoryClass: memoryClass, subject: subject, scope: scope, includeSuperseded: false))

    var winners: [String: MemoryRecord] = [:]
    for record in active {
      let key = projectionKey(for: record)
      if let existing = winners[key], existing.createdAt >= record.createdAt {
        continue
      }
      winners[key] = record
    }
    return winners.values.sorted { $0.createdAt < $1.createdAt }
  }

  /// The record that supersedes `id`, if any — the derived "superseded-by"
  /// relationship. Never stored on the old record itself (see
  /// `MemoryRecord`'s doc comment).
  public func supersedingRecord(of id: UUID) async throws(AuraError) -> MemoryRecord? {
    try await store.memoryRecords(matching: .all).first { $0.supersedes == id }
  }

  // MARK: - Conflicts

  public func conflicts(subject: String? = nil, unresolvedOnly: Bool = false)
    async throws(AuraError) -> [MemoryConflict]
  {
    try await store.memoryConflicts(subject: subject, unresolvedOnly: unresolvedOnly)
  }

  /// Set a conflict's resolution status. Unlike memory records, a
  /// conflict's resolution is mutable operational triage state, not memory
  /// content — see `MemoryConflict`'s doc comment.
  public func resolveConflict(
    id: UUID, resolution: MemoryConflictResolution, actor: ActorID = .user
  ) async throws(AuraError) {
    try await store.setMemoryConflictResolution(id: id, resolution: resolution)
    let kind: MemoryConflictResolvedEvent.Resolution
    switch resolution {
    case .supersededExisting: kind = .supersededExisting
    case .keptExisting: kind = .keptExisting
    case .bothRetained: kind = .bothRetained
    }
    await emit(
      MemoryConflictResolvedEvent(conflictID: id, resolution: kind), actor: actor,
      correlationID: UUID(), causationID: UUID())
  }
}
