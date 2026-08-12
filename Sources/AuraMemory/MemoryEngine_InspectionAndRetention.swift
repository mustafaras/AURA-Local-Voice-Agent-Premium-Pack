import AuraCore
import AuraStore
import Foundation

extension MemoryEngine {
  // MARK: - User inspection and export (non-audit only)

  /// List memory records for user inspection. Audit/security records are
  /// always excluded — matching "the user can inspect ... non-audit
  /// memory."
  public func inspect(
    memoryClass: MemoryClass? = nil, subject: String? = nil, scope: MemoryScope? = nil,
    includeSuperseded: Bool = true
  ) async throws(AuraError) -> [MemoryRecord] {
    guard memoryClass != .auditSecurity else {
      throw AuraError.memoryError("audit/security memory is not user-inspectable")
    }
    let records = try await store.memoryRecords(
      matching: MemoryQuery(
        memoryClass: memoryClass, subject: subject, scope: scope,
        includeSuperseded: includeSuperseded))
    return records.filter { $0.memoryClass != .auditSecurity }
  }

  /// Export all non-audit memory (records and conflicts) for the user.
  public func export() async throws(AuraError) -> MemoryExportBundle {
    let records = try await inspect()
    let allConflicts = try await store.memoryConflicts()
    let auditRecordIDs = Set(
      try await store.memoryRecords(matching: .all)
        .filter { $0.memoryClass == .auditSecurity }
        .map(\.id))
    let conflicts = allConflicts.filter {
      !auditRecordIDs.contains($0.existingRecordID) && !auditRecordIDs.contains($0.newRecordID)
    }
    return MemoryExportBundle(records: records, conflicts: conflicts)
  }

  // MARK: - Correction (non-audit only)

  /// Correct a record by appending a new one that supersedes it — the old
  /// record is never mutated or removed, preserving its provenance exactly
  /// as it was originally recorded.
  @discardableResult
  public func correct(
    recordID: UUID,
    newStatement: String,
    reason: String,
    evidenceReferences: [String] = [],
    actor: ActorID = .user,
    sessionID: UUID = UUID()
  ) async throws(AuraError) -> MemoryRecord {
    guard
      let existing = try await store.memoryRecords(matching: .all).first(where: {
        $0.id == recordID
      })
    else {
      throw AuraError.memoryError("no memory record with id \(recordID)")
    }
    guard existing.memoryClass != .auditSecurity else {
      throw AuraError.memoryError("audit/security records cannot be corrected by users")
    }

    let draft = MemoryRecordDraft(
      memoryClass: existing.memoryClass,
      subject: existing.subject,
      statement: newStatement,
      evidenceReferences: evidenceReferences,
      provenance: .userStated,
      confidence: 1.0,
      sensitivity: existing.sensitivity,
      retention: existing.retention,
      purpose: existing.purpose,
      supersedes: existing.id,
      scope: existing.scope
    )

    let outcome = try await append(draft, actor: actor, sessionID: sessionID)
    let newRecord: MemoryRecord
    switch outcome {
    case .recorded(let record): newRecord = record
    case .recordedWithConflict(let record, _): newRecord = record
    }

    await emit(
      MemoryCorrectedEvent(
        previousRecordID: existing.id, newRecordID: newRecord.id, reason: reason),
      actor: actor, correlationID: UUID(), causationID: UUID())
    return newRecord
  }

  // MARK: - Deletion (non-audit only)

  /// Permanently delete a non-audit memory record. The deletion itself is
  /// audited (`MemoryDeletedEvent`), but that audit event deliberately does
  /// not carry the deleted `subject`/`statement` — deletion must actually
  /// remove the content, not just relocate it into an audit trail.
  @discardableResult
  public func deleteRecord(
    id: UUID, reason: String, actor: ActorID = .user
  ) async throws(AuraError) -> MemoryDeletionReceipt {
    guard let existing = try await store.memoryRecords(matching: .all).first(where: { $0.id == id })
    else {
      throw AuraError.memoryError("no memory record with id \(id)")
    }
    guard existing.memoryClass != .auditSecurity else {
      throw AuraError.memoryError("audit/security records cannot be deleted by users")
    }

    let nodes = try await graphQuery.nodes(for: id)
    let primaryNodeID = nodes.first?.id ?? id
    try await store.appendProvenanceShadow(
      recordID: id, nodeID: primaryNodeID, reason: reason, actor: actor)

    try await store.deleteMemoryRecord(id: id)
    await emit(
      MemoryDeletedEvent(recordID: id, memoryClass: existing.memoryClass, reason: reason),
      actor: actor, correlationID: UUID(), causationID: UUID())
    return MemoryDeletionReceipt(recordID: id, memoryClass: existing.memoryClass, reason: reason)
  }

  /// Return all non-audit records plus their associated provenance subgraph
  /// in a single export bundle.
  public func exportWithProvenance() async throws(AuraError) -> MemoryProvenanceExport {
    let bundle = try await export()
    var entries: [MemoryProvenanceExport.Entry] = []
    entries.reserveCapacity(bundle.records.count)
    for record in bundle.records {
      let subgraph = try await provenance(for: record.id)
      entries.append(
        MemoryProvenanceExport.Entry(record: record, subgraph: subgraph))
    }
    return MemoryProvenanceExport(recordsWithProvenance: entries, conflicts: bundle.conflicts)
  }

  // MARK: - Retention enforcement

  /// Purge records whose retention policy has expired as of `referenceDate`.
  /// `endedSessionIDs` tells the engine which `.sessionScoped` records are
  /// eligible for purge — it has no session-lifecycle awareness of its own.
  /// `.auditRetention` records ARE purged here once their fixed compliance
  /// window elapses — only on-demand `deleteRecord` is blocked for them.
  @discardableResult
  public func enforceRetention(
    referenceDate: Date = Date(), endedSessionIDs: Set<UUID> = []
  ) async throws(AuraError) -> [UUID] {
    let all = try await store.memoryRecords(matching: .all)
    var purged: [UUID] = []

    for record in all {
      let expired: Bool
      switch record.retention {
      case .ephemeral(let seconds):
        expired = referenceDate >= record.createdAt.addingTimeInterval(seconds)
      case .sessionScoped:
        expired = record.scope.sessionID.map(endedSessionIDs.contains) ?? false
      case .indefinite:
        expired = false
      case .auditRetention(let days):
        expired = referenceDate >= record.createdAt.addingTimeInterval(Double(days) * 86_400)
      }
      if expired {
        try await store.deleteMemoryRecord(id: record.id)
        purged.append(record.id)
      }
    }

    if !purged.isEmpty {
      await emit(
        MemoryRetentionPurgedEvent(purgedCount: purged.count), actor: .memory,
        correlationID: UUID(), causationID: UUID())
    }
    return purged
  }

  /// Return the current-state projection expressed as active beliefs with
  /// explicit provenance lineage.
  public func currentBeliefs(
    memoryClass: MemoryClass? = nil, subject: String? = nil, scope: MemoryScope? = nil
  ) async throws(AuraError) -> [ProvenanceBelief] {
    try await activeBeliefs(memoryClass: memoryClass, subject: subject, scope: scope)
  }
}
