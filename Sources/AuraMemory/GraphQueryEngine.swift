import AuraCore
import AuraStore
import Foundation

/// Read-only traversal of the provenance graph stored in `AuraStore`.
///
/// The graph is stored as a normalized edge list; this engine materializes
/// adjacency on read and performs deterministic breadth-first expansion.
public actor GraphQueryEngine {
  private let store: AuraStore

  public init(store: AuraStore) {
    self.store = store
  }

  /// Return the subgraph reachable from a record's node, expanding only
  /// the requested node kinds and edge kinds up to `maxDepth`.
  public func subgraph(
    for recordID: UUID,
    query: ProvenanceGraphQuery = ProvenanceGraphQuery()
  ) async throws(AuraError) -> ProvenanceSubgraph {
    let rootNodes = try await store.provenanceNodes(recordIDs: [recordID])
    guard let root = rootNodes.first else {
      return ProvenanceSubgraph(nodes: [], edges: [], rootNodeID: nil)
    }
    return try await subgraph(rootNodeID: root.id, query: query)
  }

  /// Return the subgraph reachable from an arbitrary node ID.
  public func subgraph(
    rootNodeID: UUID,
    query: ProvenanceGraphQuery = ProvenanceGraphQuery()
  ) async throws(AuraError) -> ProvenanceSubgraph {
    let allNodes = try await store.provenanceNodes()
    let allEdges = try await store.provenanceEdges()
    let nodeByID = Dictionary(uniqueKeysWithValues: allNodes.map { ($0.id, $0) })
    let edgeBySource = Dictionary(grouping: allEdges) { $0.sourceID }
    let edgeByTarget = Dictionary(grouping: allEdges) { $0.targetID }

    var visitedNodeIDs = Set<UUID>()
    var collectedEdgeIDs = Set<UUID>()
    var frontier: [(UUID, Int)] = [(rootNodeID, 0)]
    var collectedEdges: [ProvenanceEdge] = []

    while let (currentID, depth) = frontier.first {
      frontier.removeFirst()
      guard depth <= query.maxDepth else { continue }
      guard visitedNodeIDs.insert(currentID).inserted else { continue }
      guard let node = nodeByID[currentID] else { continue }
      guard query.kinds.contains(node.kind) else { continue }

      let outgoing = edgeBySource[currentID] ?? []
      let incoming = edgeByTarget[currentID] ?? []
      for edge in outgoing + incoming {
        guard query.edgeKinds.contains(edge.kind) else { continue }
        if collectedEdgeIDs.insert(edge.id).inserted {
          collectedEdges.append(edge)
        }
        let nextID = edge.sourceID == currentID ? edge.targetID : edge.sourceID
        frontier.append((nextID, depth + 1))
      }
    }

    let collectedNodes = visitedNodeIDs.compactMap { nodeByID[$0] }
    let orderedNodes = collectedNodes.sorted {
      if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
      return $0.id.uuidString < $1.id.uuidString
    }
    let orderedEdges = collectedEdges.sorted {
      if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
      return $0.id.uuidString < $1.id.uuidString
    }
    return ProvenanceSubgraph(
      nodes: orderedNodes, edges: orderedEdges, rootNodeID: rootNodeID)
  }

  /// Return every node linked to a memory record.
  public func nodes(for recordID: UUID) async throws(AuraError) -> [ProvenanceNode] {
    try await store.provenanceNodes(recordIDs: [recordID])
  }

  /// Return every edge touching a set of nodes.
  public func edges(for nodeIDs: [UUID]) async throws(AuraError) -> [ProvenanceEdge] {
    try await store.provenanceEdges(sourceIDs: nodeIDs, targetIDs: nodeIDs)
  }
}
