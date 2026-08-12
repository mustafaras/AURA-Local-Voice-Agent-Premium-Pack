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
  let store: AuraStore
  let eventBus: AuraEventBus
  let provenanceGraph: ProvenanceGraph
  let graphQuery: GraphQueryEngine
  let contradictionDetector: ContradictionDetector
  let beliefRevision: BeliefRevision

  public init(store: AuraStore, eventBus: AuraEventBus = .shared) {
    self.store = store
    self.eventBus = eventBus
    self.provenanceGraph = ProvenanceGraph(store: store, eventBus: eventBus)
    self.graphQuery = GraphQueryEngine(store: store)
    self.contradictionDetector = ContradictionDetector(store: store)
    self.beliefRevision = BeliefRevision(store: store, graphQuery: graphQuery)
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
