import AuraCore
import AuraStore
import Foundation

/// Coordinates AURA's append-only memory and its provenance graph: writing
/// records, projecting current state, detecting and recording
/// contradictions, enforcing retention, and giving the user
/// inspection/export/correction/deletion of non-audit memory.
///
/// `MemoryEngine` never mutates or overwrites a `MemoryRecord` once
/// appended — `AuraStore.appendMemoryRecord`/`deleteMemoryRecord` are the
/// only two operations available on the underlying table, matching this
/// project's "never delete or rewrite ledger history" rule for everything
/// except a real, audited, non-audit-class user deletion. All persistence
/// goes through `AuraStore`, which owns the SQL; this actor owns the rules.
public actor MemoryEngine {
  private let store: AuraStore
  private let eventBus: AuraEventBus
  private let provenanceGraph: ProvenanceGraph
  private let graphQuery: GraphQueryEngine
  private let contradictionDetector: ContradictionDetector
  private let beliefRevision: BeliefRevision

  public init(store: AuraStore, eventBus: AuraEventBus = .shared) {
    self.store = store
    self.eventBus = eventBus
    self.provenanceGraph = ProvenanceGraph(store: store, eventBus: eventBus)
    self.graphQuery = GraphQueryEngine(store: store)
    self.contradictionDetector = ContradictionDetector(store: store)
    self.beliefRevision = BeliefRevision(store: store, graphQuery: graphQuery)
  }

  // MARK: - Provenance graph

  /// Append a provenance node and/or edges for a record in a single call.
  /// Returns the created node so callers can continue graph traversal by node ID.
  @discardableResult
  public func annotate(
    recordID: UUID,
    nodeKind: ProvenanceNodeKind,
    label: String,
    authority: ProvenanceAuthority,
    confidence: Double,
    outgoingEdges: [(ProvenanceEdgeKind, UUID)] = [],
    actor: ActorID = .memory,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> ProvenanceNode {
    let node = try await provenanceGraph.appendNode(
      kind: nodeKind, recordID: recordID, label: label, authority: authority,
      confidence: confidence, actor: actor, correlationID: correlationID)
    for (edgeKind, targetID) in outgoingEdges {
      _ = try await provenanceGraph.appendEdge(
        kind: edgeKind, sourceID: node.id, targetID: targetID, actor: actor,
        correlationID: correlationID)
    }
    return node
  }

  /// Query the provenance graph for a memory record.
  public func provenance(
    for recordID: UUID,
    kinds: Set<ProvenanceNodeKind> = Set(ProvenanceNodeKind.allCases),
    edgeKinds: Set<ProvenanceEdgeKind> = Set(ProvenanceEdgeKind.allCases),
    maxDepth: Int = 3
  ) async throws(AuraError) -> ProvenanceSubgraph {
    try await graphQuery.subgraph(
      for: recordID,
      query: ProvenanceGraphQuery(
        rootRecordID: recordID, kinds: kinds, edgeKinds: edgeKinds, maxDepth: maxDepth,
        includeInactive: false))
  }

  /// Query the provenance graph starting from a specific provenance node.
  public func provenance(
    forNodeID nodeID: UUID,
    kinds: Set<ProvenanceNodeKind> = Set(ProvenanceNodeKind.allCases),
    edgeKinds: Set<ProvenanceEdgeKind> = Set(ProvenanceEdgeKind.allCases),
    maxDepth: Int = 3
  ) async throws(AuraError) -> ProvenanceSubgraph {
    try await graphQuery.subgraph(
      rootNodeID: nodeID,
      query: ProvenanceGraphQuery(
        rootRecordID: nil, kinds: kinds, edgeKinds: edgeKinds, maxDepth: maxDepth,
        includeInactive: false))
  }

  /// Return the active belief set computed from the provenance graph.
  public func activeBeliefs(
    memoryClass: MemoryClass? = nil,
    subject: String? = nil,
    scope: MemoryScope? = nil
  ) async throws(AuraError) -> [ProvenanceBelief] {
    try await beliefRevision.activeBeliefs(memoryClass: memoryClass, subject: subject, scope: scope)
  }

  // MARK: - Append

  /// Append a new memory record, enforcing "facts require evidence,
  /// inference is labeled" and detecting contradictions against any other
  /// currently-active record sharing the same `(memoryClass, subject,
  /// scope)` key.
  ///
  /// A conflict is never silently resolved by overwriting — the existing
  /// record is left exactly as it was; a `MemoryConflict` is appended
  /// alongside the new record so nothing is lost. Passing `supersedes`
  /// marks the append as an intentional correction/update instead of a
  /// surprise contradiction, and skips conflict detection.
  @discardableResult
  public func append(
    _ draft: MemoryRecordDraft,
    actor: ActorID = .memory,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> MemoryAppendOutcome {
    try validateEvidence(draft)
    try validateSensitiveRetention(draft)

    let record = MemoryRecord(
      memoryClass: draft.memoryClass,
      subject: draft.subject,
      statement: draft.statement,
      evidenceReferences: draft.evidenceReferences,
      provenance: draft.provenance,
      confidence: draft.confidence,
      sensitivity: draft.sensitivity,
      observedAt: draft.observedAt,
      retention: draft.retention,
      supersedes: draft.supersedes,
      scope: draft.scope
    )

    try await store.appendMemoryRecord(record)
    await emit(
      MemoryRecordAppendedEvent(
        recordID: record.id, memoryClass: record.memoryClass, sensitivity: record.sensitivity,
        supersedes: record.supersedes),
      actor: actor, correlationID: correlationID, causationID: correlationID)

    let node = try await provenanceGraph.appendNode(
      kind: nodeKind(for: record.memoryClass),
      recordID: record.id,
      label: "[\(record.memoryClass)] \(record.subject): \(record.statement)",
      authority: authority(for: record.provenance),
      confidence: record.confidence,
      actor: actor,
      correlationID: correlationID)

    if let supersedesID = draft.supersedes {
      let targetNodes = try await graphQuery.nodes(for: supersedesID)
      guard let targetNode = targetNodes.first else {
        throw AuraError.memoryError(
          "cannot supersede record \(supersedesID): no provenance node found")
      }
      _ = try await provenanceGraph.appendEdge(
        kind: .supersedes, sourceID: node.id, targetID: targetNode.id, actor: actor,
        correlationID: correlationID)
    }

    for evidenceReference in record.evidenceReferences {
      if let evidenceRecordID = UUID(uuidString: evidenceReference) {
        let evidenceNodes = try await graphQuery.nodes(for: evidenceRecordID)
        let evidenceNodeID = evidenceNodes.first?.id ?? evidenceRecordID
        _ = try await provenanceGraph.appendEdge(
          kind: .evidenceFor, sourceID: evidenceNodeID, targetID: node.id, actor: actor,
          correlationID: correlationID)
      }
    }

    // An explicit supersession is a deliberate correction, never a surprise
    // contradiction — skip conflict detection.
    guard draft.supersedes == nil else {
      return .recorded(record)
    }

    let conflicting = try await contradictionDetector.detect(draft: draft, excludingRecordID: record.id)
    guard let conflicting else {
      return .recorded(record)
    }

    let conflict = MemoryConflict(
      memoryClass: draft.memoryClass, subject: draft.subject, existingRecordID: conflicting.id,
      newRecordID: record.id)
    try await store.appendMemoryConflict(conflict)

    let conflictingNodes = try await graphQuery.nodes(for: conflicting.id)
    let conflictingNodeID = conflictingNodes.first?.id ?? conflicting.id
    _ = try await provenanceGraph.appendEdge(
      kind: .conflictsWith, sourceID: node.id, targetID: conflictingNodeID, actor: actor,
      correlationID: correlationID)

    await emit(
      MemoryConflictDetectedEvent(
        conflictID: conflict.id, memoryClass: conflict.memoryClass,
        existingRecordID: conflicting.id, newRecordID: record.id),
      actor: actor, correlationID: correlationID, causationID: correlationID)

    return .recordedWithConflict(record, conflict)
  }

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
    guard let existing = try await store.memoryRecords(matching: .all).first(where: { $0.id == recordID })
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
      MemoryCorrectedEvent(previousRecordID: existing.id, newRecordID: newRecord.id, reason: reason),
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


  // MARK: - Validation

  /// "Facts require evidence. Inference is labeled." — any non-inferred
  /// provenance must cite at least one evidence reference; `.inferred`
  /// itself is the label, so it may have none.
  private func validateEvidence(_ draft: MemoryRecordDraft) throws(AuraError) {
    if case .inferred = draft.provenance { return }
    guard !draft.evidenceReferences.isEmpty else {
      throw AuraError.memoryError(
        "facts require at least one evidence reference (provenance was not .inferred)")
    }
  }

  /// "Sensitive personal facts are not retained without explicit purpose and
  /// consent" — mechanically enforced for the transient memory classes:
  /// `.secret`-sensitivity ephemeral/working/session-summary records must
  /// not use indefinite or audit retention.
  private func validateSensitiveRetention(_ draft: MemoryRecordDraft) throws(AuraError) {
    guard draft.sensitivity == .secret else { return }
    let transientClasses: Set<MemoryClass> = [.ephemeralAudio, .workingConversation, .sessionSummary]
    guard transientClasses.contains(draft.memoryClass) else { return }
    switch draft.retention {
    case .indefinite, .auditRetention:
      throw AuraError.memoryError(
        "secret-sensitivity \(draft.memoryClass) records must use ephemeral or session-scoped retention, not \(draft.retention)"
      )
    case .ephemeral, .sessionScoped:
      break
    }
  }

  private func projectionKey(for record: MemoryRecord) -> String {
    [
      record.memoryClass.rawValue,
      record.subject,
      record.scope.projectID ?? "",
      record.scope.taskID?.uuidString ?? "",
      record.scope.sessionID?.uuidString ?? "",
    ].joined(separator: "\u{1F}")
  }

  private func nodeKind(for memoryClass: MemoryClass) -> ProvenanceNodeKind {
    switch memoryClass {
    case .userPreference: return .preference
    case .taskState: return .task
    case .proceduralKnowledge: return .decision
    case .sessionSummary, .workingConversation: return .utterance
    case .ephemeralAudio: return .file
    case .projectFact: return .fact
    case .auditSecurity: return .fact
    }
  }

  private func authority(for provenance: MemoryProvenance) -> ProvenanceAuthority {
    switch provenance {
    case .userStated: return .userStated
    case .observed(let source), .systemDerived(let source):
      switch source {
      case .policy: return .derivedPolicy
      case .user: return .userConfirmed
      case .system, .audio, .screen, .automation, .memory,
           .agentCodex, .agentClaude, .agentCopilot, .agentOllama,
           .orchestrator, .task, .context, .computerUse, .security,
           .plugin, .intent, .unknown:
        return .derivedTool
      }
    case .inferred: return .inferred
    }
  }

  private func emit<Payload: EventPayload>(
    _ payload: Payload,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}

// MARK: - New export bundle with provenance

/// A user export bundle that carries provenance subgraphs alongside each
/// memory record. This is produced by `MemoryEngine.exportWithProvenance()`.
public struct MemoryProvenanceExport: Sendable, Equatable, Codable {
  public struct Entry: Sendable, Equatable, Codable {
    public let record: MemoryRecord
    public let subgraph: ProvenanceSubgraph

    public init(record: MemoryRecord, subgraph: ProvenanceSubgraph) {
      self.record = record
      self.subgraph = subgraph
    }
  }

  public let recordsWithProvenance: [Entry]
  public let conflicts: [MemoryConflict]

  public init(recordsWithProvenance: [Entry], conflicts: [MemoryConflict]) {
    self.recordsWithProvenance = recordsWithProvenance
    self.conflicts = conflicts
  }
}
