import AuraCore
import AuraStore
import Foundation

/// Writes provenance graph nodes and edges to `AuraStore` and publishes
/// creation events. All writes are append-only; the graph is immutable on
/// the time axis, just like the memory table it annotates.
public actor ProvenanceGraph {
  private let store: AuraStore
  private let eventBus: AuraEventBus

  public init(store: AuraStore, eventBus: AuraEventBus = .shared) {
    self.store = store
    self.eventBus = eventBus
  }

  /// Append a node for a memory record.
  @discardableResult
  public func appendNode(
    kind: ProvenanceNodeKind,
    recordID: UUID,
    label: String,
    authority: ProvenanceAuthority,
    confidence: Double,
    actor: ActorID = .memory,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> ProvenanceNode {
    let node = ProvenanceNode(
      kind: kind, recordID: recordID, label: label, authority: authority, confidence: confidence)
    try await store.appendProvenanceNode(node)
    await emit(
      ProvenanceNodeCreatedEvent(
        nodeID: node.id, kind: node.kind, recordID: node.recordID, createdAt: node.createdAt),
      actor: actor, correlationID: correlationID)
    return node
  }

  /// Append a directed edge between nodes.
  @discardableResult
  public func appendEdge(
    kind: ProvenanceEdgeKind,
    sourceID: UUID,
    targetID: UUID,
    actor: ActorID = .memory,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> ProvenanceEdge {
    let edge = ProvenanceEdge(kind: kind, sourceID: sourceID, targetID: targetID)
    try await store.appendProvenanceEdge(edge)
    await emit(
      ProvenanceEdgeCreatedEvent(
        edgeID: edge.id, kind: edge.kind, sourceID: edge.sourceID, targetID: edge.targetID,
        createdAt: edge.createdAt),
      actor: actor, correlationID: correlationID)
    return edge
  }

  private func emit<Payload: EventPayload>(
    _ payload: Payload,
    actor: ActorID,
    correlationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: correlationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}
