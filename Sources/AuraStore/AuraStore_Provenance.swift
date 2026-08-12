import AuraCore
import Foundation
import SQLite3

extension AuraStore {
  // MARK: - Provenance nodes

  /// Append a provenance node to the graph.
  public func appendProvenanceNode(_ node: ProvenanceNode) async throws(AuraError) {
    try await database.run(
      sql: """
        INSERT INTO provenance_nodes (
            id, kind, record_id, label, created_at, authority, confidence
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(node.id.uuidString),
        .text(node.kind.rawValue),
        .text(node.recordID.uuidString),
        .text(node.label),
        .text(formatDate(node.createdAt)),
        .integer(node.authority.rawValue),
        .real(node.confidence),
      ]
    )
  }

  /// Load all provenance nodes, optionally filtered by record IDs or kinds.
  public func provenanceNodes(
    recordIDs: [UUID]? = nil, kinds: [ProvenanceNodeKind]? = nil
  ) async throws(AuraError) -> [ProvenanceNode] {
    var clauses: [String] = []
    var arguments: [SQLiteValue] = []
    if let recordIDs {
      let placeholders = Array(repeating: "?", count: recordIDs.count).joined(separator: ",")
      clauses.append("record_id IN (\(placeholders))")
      arguments.append(contentsOf: recordIDs.map { .text($0.uuidString) })
    }
    if let kinds {
      let placeholders = Array(repeating: "?", count: kinds.count).joined(separator: ",")
      clauses.append("kind IN (\(placeholders))")
      arguments.append(contentsOf: kinds.map { .text($0.rawValue) })
    }
    let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
    let sql =
      "SELECT * FROM provenance_nodes \(whereClause) ORDER BY datetime(created_at) ASC, id ASC;"
    let rows = try await database.query(sql: sql, arguments: arguments)
    var nodes: [ProvenanceNode] = []
    for row in rows {
      guard let kind = ProvenanceNodeKind(rawValue: row["kind"]?.text ?? "") else {
        throw AuraError.memoryError("unknown provenance node kind")
      }
      guard let authority = ProvenanceAuthority(rawValue: row["authority"]?.integerValue ?? 0)
      else {
        throw AuraError.memoryError("unknown provenance authority")
      }
      nodes.append(
        ProvenanceNode(
          id: UUID(uuidString: row["id"]?.text ?? "") ?? UUID(),
          kind: kind,
          recordID: UUID(uuidString: row["record_id"]?.text ?? "") ?? UUID(),
          label: row["label"]?.text ?? "",
          createdAt: parseDate(row["created_at"]),
          authority: authority,
          confidence: row["confidence"]?.realValue ?? 0
        ))
    }
    return nodes
  }

  // MARK: - Provenance edges

  /// Append a directed edge between provenance nodes.
  public func appendProvenanceEdge(_ edge: ProvenanceEdge) async throws(AuraError) {
    try await database.run(
      sql: """
        INSERT INTO provenance_edges (
            id, kind, source_id, target_id, created_at, correlation_id
        ) VALUES (?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(edge.id.uuidString),
        .text(edge.kind.rawValue),
        .text(edge.sourceID.uuidString),
        .text(edge.targetID.uuidString),
        .text(formatDate(edge.createdAt)),
        .text(edge.correlationID.uuidString),
      ]
    )
  }

  /// Load provenance edges filtered by source/target node IDs and/or edge kinds.
  public func provenanceEdges(
    sourceIDs: [UUID]? = nil, targetIDs: [UUID]? = nil, kinds: [ProvenanceEdgeKind]? = nil
  ) async throws(AuraError) -> [ProvenanceEdge] {
    var clauses: [String] = []
    var arguments: [SQLiteValue] = []
    if let sourceIDs {
      let placeholders = Array(repeating: "?", count: sourceIDs.count).joined(separator: ",")
      clauses.append("source_id IN (\(placeholders))")
      arguments.append(contentsOf: sourceIDs.map { .text($0.uuidString) })
    }
    if let targetIDs {
      let placeholders = Array(repeating: "?", count: targetIDs.count).joined(separator: ",")
      clauses.append("target_id IN (\(placeholders))")
      arguments.append(contentsOf: targetIDs.map { .text($0.uuidString) })
    }
    if let kinds {
      let placeholders = Array(repeating: "?", count: kinds.count).joined(separator: ",")
      clauses.append("kind IN (\(placeholders))")
      arguments.append(contentsOf: kinds.map { .text($0.rawValue) })
    }
    let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
    let sql =
      "SELECT * FROM provenance_edges \(whereClause) ORDER BY datetime(created_at) ASC, id ASC;"
    let rows = try await database.query(sql: sql, arguments: arguments)
    var edges: [ProvenanceEdge] = []
    for row in rows {
      guard let kind = ProvenanceEdgeKind(rawValue: row["kind"]?.text ?? "") else {
        throw AuraError.memoryError("unknown provenance edge kind")
      }
      edges.append(
        ProvenanceEdge(
          id: UUID(uuidString: row["id"]?.text ?? "") ?? UUID(),
          kind: kind,
          sourceID: UUID(uuidString: row["source_id"]?.text ?? "") ?? UUID(),
          targetID: UUID(uuidString: row["target_id"]?.text ?? "") ?? UUID(),
          createdAt: parseDate(row["created_at"]),
          correlationID: UUID(uuidString: row["correlation_id"]?.text ?? "") ?? UUID()
        ))
    }
    return edges
  }

  // MARK: - Provenance shadow records

  /// Record that a provenance node was shadowed by user deletion.
  /// The shadow record is itself append-only and references the original
  /// record and node without removing them.
  public func appendProvenanceShadow(
    id: UUID = UUID(),
    recordID: UUID,
    nodeID: UUID,
    shadowedAt: Date = Date(),
    reason: String,
    actor: ActorID
  ) async throws(AuraError) {
    try await database.run(
      sql: """
        INSERT INTO provenance_shadows (
            id, record_id, node_id, shadowed_at, reason, actor
        ) VALUES (?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(id.uuidString),
        .text(recordID.uuidString),
        .text(nodeID.uuidString),
        .text(formatDate(shadowedAt)),
        .text(reason),
        .text(actor.rawValue),
      ]
    )
  }

  /// Return the set of record IDs that have been shadowed by user deletion.
  public func shadowedRecordIDs() async throws(AuraError) -> Set<UUID> {
    let rows = try await database.query(
      sql: "SELECT DISTINCT record_id FROM provenance_shadows;",
      arguments: []
    )
    var ids = Set<UUID>()
    ids.reserveCapacity(rows.count)
    for row in rows {
      if let text = row["record_id"]?.text, let uuid = UUID(uuidString: text) {
        ids.insert(uuid)
      }
    }
    return ids
  }

  func encodeJSON(_ strings: [String]) -> String {
    guard let data = try? JSONEncoder().encode(strings),
      let json = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return json
  }

  func decodeJSON(_ json: String) -> [String] {
    guard let data = json.data(using: .utf8),
      let strings = try? JSONDecoder().decode([String].self, from: data)
    else {
      return []
    }
    return strings
  }
}
