import AuraCore
import AuraStore
import Foundation

extension MemoryEngine {
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
    let source: MemoryWriteSource
    switch draft.provenance {
    case .userStated:
      source = .explicitUser
    case .observed(let sourceActor), .systemDerived(let sourceActor):
      source = .verifiedToolEvidence(actor: sourceActor)
    case .inferred:
      source = .inferred
    }
    return try await append(
      MemoryWriteRequest(draft: draft, source: source), actor: actor, sessionID: sessionID,
      correlationID: correlationID)
  }

  /// Append a record after evaluating its explicit retention/write policy.
  /// Untrusted content, model output, and raw content have no implicit path
  /// into durable memory. This overload is the boundary used by product
  /// callers that know why a record is being retained.
  @discardableResult
  public func append(
    _ request: MemoryWriteRequest,
    actor: ActorID = .memory,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> MemoryAppendOutcome {
    let draft = request.draft
    try validateWritePolicy(request)
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
      purpose: draft.purpose,
      supersedes: draft.supersedes,
      scope: draft.scope
    )

    try await store.appendMemoryRecord(record)
    await emit(
      MemoryRecordAppendedEvent(
        recordID: record.id, memoryClass: record.memoryClass, sensitivity: record.sensitivity,
        supersedes: record.supersedes),
      actor: actor, correlationID: correlationID, causationID: correlationID)
    let node = try await appendProvenance(
      for: record, draft: draft, actor: actor, correlationID: correlationID)
    guard draft.supersedes == nil else { return .recorded(record) }
    return try await appendConflictIfNeeded(
      record: record, draft: draft, node: node, actor: actor, correlationID: correlationID)
  }

  private func appendProvenance(
    for record: MemoryRecord,
    draft: MemoryRecordDraft,
    actor: ActorID,
    correlationID: UUID
  ) async throws(AuraError) -> ProvenanceNode {
    let node = try await provenanceGraph.appendNode(
      kind: nodeKind(for: record.memoryClass), recordID: record.id,
      label: "[\(record.memoryClass)] \(record.subject): \(record.statement)",
      authority: authority(for: record.provenance), confidence: record.confidence,
      actor: actor, correlationID: correlationID)
    if let supersedesID = draft.supersedes {
      let targetNodes = try await graphQuery.nodes(for: supersedesID)
      guard let targetNode = targetNodes.first else {
        throw AuraError.memoryError(
          "cannot supersede record \(supersedesID): no provenance node found")
      }
      _ = try await provenanceGraph.appendEdge(
        kind: .supersedes, sourceID: node.id, targetID: targetNode.id,
        actor: actor, correlationID: correlationID)
    }
    for evidenceReference in record.evidenceReferences {
      guard let evidenceRecordID = UUID(uuidString: evidenceReference) else { continue }
      let evidenceNodes = try await graphQuery.nodes(for: evidenceRecordID)
      let evidenceNodeID = evidenceNodes.first?.id ?? evidenceRecordID
      _ = try await provenanceGraph.appendEdge(
        kind: .evidenceFor, sourceID: evidenceNodeID, targetID: node.id,
        actor: actor, correlationID: correlationID)
    }
    return node
  }

  private func appendConflictIfNeeded(
    record: MemoryRecord,
    draft: MemoryRecordDraft,
    node: ProvenanceNode,
    actor: ActorID,
    correlationID: UUID
  ) async throws(AuraError) -> MemoryAppendOutcome {
    guard
      let conflicting = try await contradictionDetector.detect(
        draft: draft, excludingRecordID: record.id)
    else {
      return .recorded(record)
    }
    let conflict = MemoryConflict(
      memoryClass: draft.memoryClass, subject: draft.subject,
      existingRecordID: conflicting.id, newRecordID: record.id)
    try await store.appendMemoryConflict(conflict)
    let conflictingNodes = try await graphQuery.nodes(for: conflicting.id)
    let conflictingNodeID = conflictingNodes.first?.id ?? conflicting.id
    _ = try await provenanceGraph.appendEdge(
      kind: .conflictsWith, sourceID: node.id, targetID: conflictingNodeID,
      actor: actor, correlationID: correlationID)
    await emit(
      MemoryConflictDetectedEvent(
        conflictID: conflict.id, memoryClass: conflict.memoryClass,
        existingRecordID: conflicting.id, newRecordID: record.id),
      actor: actor, correlationID: correlationID, causationID: correlationID)
    return .recordedWithConflict(record, conflict)
  }
}
