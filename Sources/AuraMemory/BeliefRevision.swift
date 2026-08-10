import AuraCore
import AuraStore
import Foundation

/// Computes the active belief per `(memoryClass, subject, scope)` key from
/// the append-only memory table, using authority and confidence to break
/// ties. Produces explicit provenance lineage (evidence, superseded,
/// conflicting) for each active belief.
public actor BeliefRevision {
  private let store: AuraStore
  private let graphQuery: GraphQueryEngine

  public init(store: AuraStore, graphQuery: GraphQueryEngine) {
    self.store = store
    self.graphQuery = graphQuery
  }

  /// Compute active beliefs for the given memory class and/or subject.
  ///
  /// A record that has been superseded or shadowed by user deletion is
  /// never an active belief. When multiple active records share the same
  /// projection key, the winner is chosen by descending authority, then
  /// descending confidence, then most recent creation time. The tie-breaker
  /// intentionally favors stronger evidence over recency when authority
  /// differs, matching the safety-first priority order.
  public func activeBeliefs(
    memoryClass: MemoryClass? = nil,
    subject: String? = nil,
    scope: MemoryScope? = nil
  ) async throws(AuraError) -> [ProvenanceBelief] {
    let active = try await store.memoryRecords(
      matching: MemoryQuery(
        memoryClass: memoryClass, subject: subject, scope: scope, includeSuperseded: false))
    let shadowed = try await store.shadowedRecordIDs()
    let eligible = active.filter { !shadowed.contains($0.id) }

    let grouped = Dictionary(grouping: eligible) { projectionKey(for: $0) }

    var beliefs: [ProvenanceBelief] = []
    beliefs.reserveCapacity(grouped.count)

    for (_, records) in grouped {
      guard let winner = chooseWinner(records) else { continue }
      let nodes = try await graphQuery.nodes(for: winner.id)
      let evidenceRecords = try await evidenceRecordIDs(for: winner, allRecords: active)
      let supersededRecords = try await supersededRecordIDs(for: winner)
      let conflictingRecords = active.filter {
        $0.id != winner.id
          && projectionKey(for: $0) == projectionKey(for: winner)
          && $0.statement != winner.statement
      }.map(\.id)

      beliefs.append(
        ProvenanceBelief(
          subject: winner.subject,
          memoryClass: winner.memoryClass,
          activeRecordID: winner.id,
          statement: winner.statement,
          confidence: winner.confidence,
          authority: nodes.first?.authority ?? .inferred,
          evidenceRecordIDs: evidenceRecords,
          supersededRecordIDs: supersededRecords,
          conflictingRecordIDs: conflictingRecords
        )
      )
    }

    return beliefs.sorted {
      if $0.subject != $1.subject { return $0.subject < $1.subject }
      return $0.activeRecordID.uuidString < $1.activeRecordID.uuidString
    }
  }

  private func chooseWinner(_ records: [MemoryRecord]) -> MemoryRecord? {
    records.max {
      let lhsAuthority = authority(of: $0)
      let rhsAuthority = authority(of: $1)
      if lhsAuthority != rhsAuthority { return lhsAuthority.rawValue < rhsAuthority.rawValue }
      if $0.confidence != $1.confidence { return $0.confidence < $1.confidence }
      return $0.createdAt < $1.createdAt
    }
  }

  private func authority(of record: MemoryRecord) -> ProvenanceAuthority {
    switch record.provenance {
    case .userStated: return .userStated
    case .observed(let source), .systemDerived(let source):
      return authority(from: source)
    case .inferred: return .inferred
    }
  }

  private func authority(from source: ActorID) -> ProvenanceAuthority {
    switch source {
    case .policy: return .derivedPolicy
    case .user: return .userConfirmed
    case .system, .audio, .screen, .automation, .memory,
      .agentCodex, .agentClaude, .agentCopilot, .agentOllama,
      .orchestrator, .task, .context, .computerUse, .security,
      .plugin, .intent, .unknown:
      return .derivedTool
    }
  }

  private func evidenceRecordIDs(for record: MemoryRecord, allRecords: [MemoryRecord])
    async throws(AuraError) -> [UUID]
  {
    let subgraph = try await graphQuery.subgraph(for: record.id)
    let evidenceEdges = subgraph.edges.filter { $0.kind == .evidenceFor }
    let evidenceNodeIDs = evidenceEdges.map { $0.sourceID }
    let evidenceRecords = subgraph.nodes
      .filter { evidenceNodeIDs.contains($0.id) }
      .map(\.recordID)
    var referenceIDs = Set(record.evidenceReferences.compactMap(UUID.init(uuidString:)))
    referenceIDs.formUnion(evidenceRecords)
    return Array(referenceIDs).sorted { $0.uuidString < $1.uuidString }
  }

  /// Follow `supersedes` edges backward from the winning record to find all
  /// records it supersedes. This uses the provenance graph so the lineage is
  /// explicit and not inferred from the `supersedes` column alone.
  private func supersededRecordIDs(for winner: MemoryRecord) async throws(AuraError) -> [UUID] {
    let subgraph = try await graphQuery.subgraph(for: winner.id)
    let supersedeEdges = subgraph.edges.filter { $0.kind == .supersedes }
    let supersederIDs = Set(supersedeEdges.map { $0.sourceID })
    let supersededIDs = Set(supersedeEdges.map { $0.targetID })
    // Only count target nodes whose source node is in this record's graph.
    let nodesForWinner = subgraph.nodes.filter { $0.recordID == winner.id }
    let winnerNodeIDs = Set(nodesForWinner.map { $0.id })
    let locallySuperseded = supersededIDs.filter { supersededID in
      supersederIDs.contains { winnerNodeIDs.contains($0) }
    }
    let recordIDs = subgraph.nodes
      .filter { locallySuperseded.contains($0.id) }
      .map(\.recordID)
    return Array(Set(recordIDs)).sorted { $0.uuidString < $1.uuidString }
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
}
