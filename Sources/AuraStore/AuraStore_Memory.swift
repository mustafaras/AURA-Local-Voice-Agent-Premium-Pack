import AuraCore
import Foundation
import SQLite3

extension AuraStore {
  // MARK: - Memory records

  /// Append a new, immutable memory record. Never overwrites or mutates an
  /// existing row — corrections/supersessions are new rows referencing the
  /// old one via `supersedes`.
  public func appendMemoryRecord(_ record: MemoryRecord) async throws(AuraError) {
    try await database.run(
      sql: """
        INSERT INTO memory_records (
            id, memory_class, subject, statement, evidence_references,
            provenance_json, confidence, sensitivity, created_at, observed_at,
            retention_json, purpose, supersedes, project_id, task_id, session_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(record.id.uuidString),
        .text(record.memoryClass.rawValue),
        .text(record.subject),
        .text(record.statement),
        .text(encodeJSON(record.evidenceReferences)),
        .text(try encodeCodable(record.provenance, label: "provenance")),
        .real(record.confidence),
        .text(record.sensitivity.rawValue),
        .text(formatDate(record.createdAt)),
        .text(formatDate(record.observedAt)),
        .text(try encodeCodable(record.retention, label: "retention")),
        .text(record.purpose),
        record.supersedes.map { SQLiteValue.text($0.uuidString) } ?? .null,
        record.scope.projectID.map(SQLiteValue.text) ?? .null,
        record.scope.taskID.map { SQLiteValue.text($0.uuidString) } ?? .null,
        record.scope.sessionID.map { SQLiteValue.text($0.uuidString) } ?? .null,
      ]
    )
  }

  /// Permanently remove a memory record by ID (real deletion, not a
  /// tombstone) — callers are responsible for recording an audit event
  /// separately, since this row itself carries the content being removed.
  public func deleteMemoryRecord(id: UUID) async throws(AuraError) {
    try await database.run(
      sql: "DELETE FROM memory_records WHERE id = ?;",
      arguments: [.text(id.uuidString)]
    )
  }

  /// Query memory records, optionally filtered by class/subject/scope and
  /// whether to include records that some other record `supersedes`.
  public func memoryRecords(matching query: MemoryQuery) async throws(AuraError) -> [MemoryRecord] {
    let (sql, arguments) = memoryQuerySQL(query)
    let rows = try await database.query(sql: sql, arguments: arguments)
    return try decodeMemoryRows(rows)
  }

  private func memoryQuerySQL(_ query: MemoryQuery) -> (String, [SQLiteValue]) {
    var clauses: [String] = []
    var arguments: [SQLiteValue] = []
    if let memoryClass = query.memoryClass {
      clauses.append("memory_class = ?")
      arguments.append(.text(memoryClass.rawValue))
    }
    if let subject = query.subject {
      clauses.append("subject = ?")
      arguments.append(.text(subject))
    }
    appendScopeClauses(query.scope, clauses: &clauses, arguments: &arguments)
    if !query.includeSuperseded {
      clauses.append(
        "id NOT IN (SELECT supersedes FROM memory_records WHERE supersedes IS NOT NULL)")
    }
    let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
    return (
      "SELECT * FROM memory_records \(whereClause) ORDER BY datetime(created_at) ASC;",
      arguments
    )
  }

  private func appendScopeClauses(
    _ scope: MemoryScope?, clauses: inout [String], arguments: inout [SQLiteValue]
  ) {
    guard let scope else { return }
    if let projectID = scope.projectID {
      clauses.append("project_id = ?")
      arguments.append(.text(projectID))
    }
    if let taskID = scope.taskID {
      clauses.append("task_id = ?")
      arguments.append(.text(taskID.uuidString))
    }
    if let sessionID = scope.sessionID {
      clauses.append("session_id = ?")
      arguments.append(.text(sessionID.uuidString))
    }
  }

  private func decodeMemoryRows(
    _ rows: [[String: SQLiteValue]]
  ) throws(AuraError) -> [MemoryRecord] {
    var records: [MemoryRecord] = []
    records.reserveCapacity(rows.count)
    for row in rows {
      guard let memoryClass = MemoryClass(rawValue: row["memory_class"]?.text ?? "") else {
        throw AuraError.memoryError("unknown memory_class in row \(row["id"]?.text ?? "?")")
      }
      guard let sensitivity = SensitivityLevel(rawValue: row["sensitivity"]?.text ?? "") else {
        throw AuraError.memoryError("unknown sensitivity in row \(row["id"]?.text ?? "?")")
      }
      let provenance: MemoryProvenance = try decodeCodable(
        row["provenance_json"]?.text ?? "", label: "provenance")
      let retention: MemoryRetentionPolicy = try decodeCodable(
        row["retention_json"]?.text ?? "", label: "retention")
      records.append(
        MemoryRecord(
          id: UUID(uuidString: row["id"]?.text ?? "") ?? UUID(),
          memoryClass: memoryClass, subject: row["subject"]?.text ?? "",
          statement: row["statement"]?.text ?? "",
          evidenceReferences: decodeJSON(row["evidence_references"]?.text ?? "[]"),
          provenance: provenance, confidence: row["confidence"].flatMap(\.realValue) ?? 0,
          sensitivity: sensitivity, createdAt: parseDate(row["created_at"]),
          observedAt: parseDate(row["observed_at"]), retention: retention,
          purpose: row["purpose"]?.text ?? "unspecified",
          supersedes: row["supersedes"]?.text.flatMap(UUID.init(uuidString:)),
          scope: MemoryScope(
            projectID: row["project_id"]?.text,
            taskID: row["task_id"]?.text.flatMap(UUID.init(uuidString:)),
            sessionID: row["session_id"]?.text.flatMap(UUID.init(uuidString:)))))
    }
    return records
  }

  // MARK: - Memory conflicts

  /// Append a newly detected conflict record.
  public func appendMemoryConflict(_ conflict: MemoryConflict) async throws(AuraError) {
    let resolutionValue: SQLiteValue
    if let resolution = conflict.resolution {
      resolutionValue = .text(try encodeCodable(resolution, label: "resolution"))
    } else {
      resolutionValue = .null
    }
    try await database.run(
      sql: """
        INSERT INTO memory_conflicts (
            id, memory_class, subject, existing_record_id, new_record_id,
            detected_at, resolution_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(conflict.id.uuidString),
        .text(conflict.memoryClass.rawValue),
        .text(conflict.subject),
        .text(conflict.existingRecordID.uuidString),
        .text(conflict.newRecordID.uuidString),
        .text(formatDate(conflict.detectedAt)),
        resolutionValue,
      ]
    )
  }

  /// Update a conflict's resolution status in place. Unlike memory records
  /// and unlike the conflict's own detection fields, resolution status is
  /// mutable operational bookkeeping, not memory content requiring
  /// append-only history.
  public func setMemoryConflictResolution(
    id: UUID, resolution: MemoryConflictResolution
  ) async throws(AuraError) {
    try await database.run(
      sql: "UPDATE memory_conflicts SET resolution_json = ? WHERE id = ?;",
      arguments: [.text(try encodeCodable(resolution, label: "resolution")), .text(id.uuidString)]
    )
  }

  /// Query conflicts, optionally filtered by subject and/or resolution status.
  public func memoryConflicts(
    subject: String? = nil, unresolvedOnly: Bool = false
  ) async throws(AuraError) -> [MemoryConflict] {
    var clauses: [String] = []
    var arguments: [SQLiteValue] = []
    if let subject {
      clauses.append("subject = ?")
      arguments.append(.text(subject))
    }
    if unresolvedOnly {
      clauses.append("resolution_json IS NULL")
    }
    let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
    let sql = "SELECT * FROM memory_conflicts \(whereClause) ORDER BY datetime(detected_at) ASC;"

    let rows = try await database.query(sql: sql, arguments: arguments)
    var conflicts: [MemoryConflict] = []
    conflicts.reserveCapacity(rows.count)
    for row in rows {
      guard let memoryClass = MemoryClass(rawValue: row["memory_class"]?.text ?? "") else {
        throw AuraError.memoryError(
          "unknown memory_class in conflict row \(row["id"]?.text ?? "?")")
      }
      var resolution: MemoryConflictResolution?
      if let resolutionJSON = row["resolution_json"]?.text {
        resolution = try decodeCodable(resolutionJSON, label: "resolution")
      }
      conflicts.append(
        MemoryConflict(
          id: UUID(uuidString: row["id"]?.text ?? "") ?? UUID(),
          memoryClass: memoryClass,
          subject: row["subject"]?.text ?? "",
          existingRecordID: UUID(uuidString: row["existing_record_id"]?.text ?? "") ?? UUID(),
          newRecordID: UUID(uuidString: row["new_record_id"]?.text ?? "") ?? UUID(),
          detectedAt: parseDate(row["detected_at"]),
          resolution: resolution
        ))
    }
    return conflicts
  }

  func encodeCodable<T: Encodable>(_ value: T, label: String) throws(AuraError) -> String {
    do {
      let data = try jsonEncoder.encode(value)
      guard let json = String(data: data, encoding: .utf8) else {
        throw AuraError.serializationError("\(label) is not valid UTF-8")
      }
      return json
    } catch let error as AuraError {
      throw error
    } catch {
      throw AuraError.serializationError("Failed to encode \(label): \(error.localizedDescription)")
    }
  }

  func decodeCodable<T: Decodable>(_ json: String, label: String) throws(AuraError) -> T {
    guard let data = json.data(using: .utf8) else {
      throw AuraError.serializationError("\(label) is not valid UTF-8")
    }
    do {
      return try jsonDecoder.decode(T.self, from: data)
    } catch {
      throw AuraError.serializationError("Failed to decode \(label): \(error.localizedDescription)")
    }
  }

  func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  func parseDate(_ value: SQLiteValue?) -> Date {
    guard case .text(let string) = value else { return Date() }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string) ?? Date()
  }
}
