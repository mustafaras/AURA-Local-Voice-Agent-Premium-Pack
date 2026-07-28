import Foundation

// MARK: - Provenance node types

/// The kind of entity represented by a provenance graph node.
///
/// A node is a concrete, append-only record of something that contributed to
/// memory, an action, or a decision. Every node has a stable `id` and is
/// linked to other nodes by `ProvenanceEdge`s. Nodes are stored in
/// `AuraStore` and are queryable through `AuraMemory`.
public enum ProvenanceNodeKind: String, Codable, Sendable, Equatable, CaseIterable {
  case fact
  case decision
  case task
  case utterance
  case file
  case preference
}

/// A single vertex in the provenance graph.
///
/// Nodes are intentionally flat and reference other nodes only through
/// explicit edges. A node never stores its adjacency list; that is
/// materialized on read by `GraphQueryEngine`.
public struct ProvenanceNode: Sendable, Equatable, Identifiable, Codable {
  public let id: UUID
  public let kind: ProvenanceNodeKind
  public let recordID: UUID
  public let label: String
  public let createdAt: Date
  public let authority: ProvenanceAuthority
  public let confidence: Double

  public init(
    id: UUID = UUID(),
    kind: ProvenanceNodeKind,
    recordID: UUID,
    label: String,
    createdAt: Date = Date(),
    authority: ProvenanceAuthority,
    confidence: Double
  ) {
    self.id = id
    self.kind = kind
    self.recordID = recordID
    self.label = label
    self.createdAt = createdAt
    self.authority = authority
    self.confidence = confidence
  }
}

// MARK: - Provenance edge types

/// The semantic of a directed edge between two provenance nodes.
public enum ProvenanceEdgeKind: String, Codable, Sendable, Equatable, CaseIterable {
  /// `source` provides evidence for `target`.
  case evidenceFor
  /// `target` was derived from `source`.
  case derivedFrom
  /// `source` supersedes `target` (newer version, correction, or explicit update).
  case supersedes
  /// `source` conflicts with `target` (same key, different statement/authority).
  case conflictsWith
  /// `source` confirms `target` (additional corroboration, not derivation).
  case confirms
  /// `source` denies `target` (explicit contradiction, e.g. user says "no").
  case denies
}

/// A directed edge between two provenance nodes.
///
/// Edges are append-only. When a relationship is revised, a new edge is
/// appended; old edges remain to preserve history.
public struct ProvenanceEdge: Sendable, Equatable, Identifiable, Codable {
  public let id: UUID
  public let kind: ProvenanceEdgeKind
  public let sourceID: UUID
  public let targetID: UUID
  public let createdAt: Date
  public let correlationID: UUID

  public init(
    id: UUID = UUID(),
    kind: ProvenanceEdgeKind,
    sourceID: UUID,
    targetID: UUID,
    createdAt: Date = Date(),
    correlationID: UUID = UUID()
  ) {
    self.id = id
    self.kind = kind
    self.sourceID = sourceID
    self.targetID = targetID
    self.createdAt = createdAt
    self.correlationID = correlationID
  }
}

// MARK: - Authority and query primitives

/// Source authority ranking for belief revision.
///
/// Higher raw values beat lower raw values when confidence is otherwise
/// comparable. The ordering is intentionally explicit in code to avoid
/// accidental drift.
public enum ProvenanceAuthority: Int, Codable, Sendable, Equatable, CaseIterable {
  case userConfirmed = 4
  case userStated = 3
  case derivedPolicy = 2
  case derivedTool = 1
  case inferred = 0
}

/// A small bundle describing an active belief for a memory subject.
///
/// Produced by `BeliefRevision.activeBeliefs(...)`. It contains the current
/// winning record plus the lineage of records that led to that belief.
public struct ProvenanceBelief: Sendable, Equatable, Codable {
  public let subject: String
  public let memoryClass: MemoryClass
  public let activeRecordID: UUID
  public let statement: String
  public let confidence: Double
  public let authority: ProvenanceAuthority
  public let evidenceRecordIDs: [UUID]
  public let supersededRecordIDs: [UUID]
  public let conflictingRecordIDs: [UUID]

  public init(
    subject: String,
    memoryClass: MemoryClass,
    activeRecordID: UUID,
    statement: String,
    confidence: Double,
    authority: ProvenanceAuthority,
    evidenceRecordIDs: [UUID],
    supersededRecordIDs: [UUID],
    conflictingRecordIDs: [UUID]
  ) {
    self.subject = subject
    self.memoryClass = memoryClass
    self.activeRecordID = activeRecordID
    self.statement = statement
    self.confidence = confidence
    self.authority = authority
    self.evidenceRecordIDs = evidenceRecordIDs
    self.supersededRecordIDs = supersededRecordIDs
    self.conflictingRecordIDs = conflictingRecordIDs
  }
}

/// Query parameters for provenance graph traversal.
///
/// Deterministic ordering is guaranteed by `createdAt` then `id`.
public struct ProvenanceGraphQuery: Sendable, Equatable {
  public let rootRecordID: UUID?
  public let kinds: Set<ProvenanceNodeKind>
  public let edgeKinds: Set<ProvenanceEdgeKind>
  public let maxDepth: Int
  public let includeInactive: Bool

  public init(
    rootRecordID: UUID? = nil,
    kinds: Set<ProvenanceNodeKind> = Set(ProvenanceNodeKind.allCases),
    edgeKinds: Set<ProvenanceEdgeKind> = Set(ProvenanceEdgeKind.allCases),
    maxDepth: Int = 3,
    includeInactive: Bool = false
  ) {
    self.rootRecordID = rootRecordID
    self.kinds = kinds
    self.edgeKinds = edgeKinds
    self.maxDepth = maxDepth
    self.includeInactive = includeInactive
  }
}

/// Result of a provenance graph traversal.
public struct ProvenanceSubgraph: Sendable, Equatable, Codable {
  public let nodes: [ProvenanceNode]
  public let edges: [ProvenanceEdge]
  public let rootNodeID: UUID?

  public init(nodes: [ProvenanceNode], edges: [ProvenanceEdge], rootNodeID: UUID? = nil) {
    self.nodes = nodes
    self.edges = edges
    self.rootNodeID = rootNodeID
  }
}

// MARK: - Graph mutation events

/// Emitted when a provenance node is created.
public struct ProvenanceNodeCreatedEvent: EventPayload {
  public static let eventType = "provenance.node.created"

  public let nodeID: UUID
  public let kind: ProvenanceNodeKind
  public let recordID: UUID
  public let createdAt: Date

  public init(nodeID: UUID, kind: ProvenanceNodeKind, recordID: UUID, createdAt: Date = Date()) {
    self.nodeID = nodeID
    self.kind = kind
    self.recordID = recordID
    self.createdAt = createdAt
  }
}

/// Emitted when a provenance edge is created.
public struct ProvenanceEdgeCreatedEvent: EventPayload {
  public static let eventType = "provenance.edge.created"

  public let edgeID: UUID
  public let kind: ProvenanceEdgeKind
  public let sourceID: UUID
  public let targetID: UUID
  public let createdAt: Date

  public init(
    edgeID: UUID, kind: ProvenanceEdgeKind, sourceID: UUID, targetID: UUID,
    createdAt: Date = Date()
  ) {
    self.edgeID = edgeID
    self.kind = kind
    self.sourceID = sourceID
    self.targetID = targetID
    self.createdAt = createdAt
  }
}

/// Emitted when `BeliefRevision` deprecates a prior active belief in favor
/// of a newer record.
public struct BeliefDeprecatedEvent: EventPayload {
  public static let eventType = "memory.belief.deprecated"

  public let previousRecordID: UUID
  public let newRecordID: UUID
  public let reason: String
  public let deprecatedAt: Date

  public init(
    previousRecordID: UUID, newRecordID: UUID, reason: String, deprecatedAt: Date = Date()
  ) {
    self.previousRecordID = previousRecordID
    self.newRecordID = newRecordID
    self.reason = reason
    self.deprecatedAt = deprecatedAt
  }
}
