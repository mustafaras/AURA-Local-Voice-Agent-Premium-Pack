import AuraCore
import Foundation
import SQLite3

/// Persistent SQLite-backed append-only store for events and ledger entries.
public actor AuraStore: LedgerBackend {
  public let database: AuraDatabase
  private let jsonEncoder: JSONEncoder
  private let jsonDecoder: JSONDecoder

  public init(path: String) async throws(AuraError) {
    let db = try AuraDatabase(path: path)
    self.database = db
    self.jsonEncoder = JSONEncoder()
    self.jsonEncoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder.outputFormatting = .sortedKeys
    self.jsonDecoder = JSONDecoder()
    self.jsonDecoder.dateDecodingStrategy = .iso8601
    try await db.migrate()
  }

  /// Persist a type-erased event envelope.
  public func persistEvent<P: EventPayload>(
    _ envelope: EventEnvelope<P>
  ) async throws(AuraError) {
    try envelope.validateSchema()
    let payloadData: Data
    do {
      payloadData = try jsonEncoder.encode(envelope.payload)
    } catch {
      throw AuraError.serializationError("Failed to encode payload: \(error.localizedDescription)")
    }
    guard let payloadJSON = String(data: payloadData, encoding: .utf8) else {
      throw AuraError.serializationError("Payload is not valid UTF-8")
    }

    try await database.run(
      sql: """
        INSERT INTO events (
            id, schema_version, timestamp, correlation_id, causation_id,
            actor, sensitivity, event_type, payload_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(envelope.id.uuidString),
        .text(envelope.schemaVersion),
        .text(formatDate(envelope.timestamp)),
        .text(envelope.correlationID.uuidString),
        .text(envelope.causationID.uuidString),
        .text(envelope.actor.rawValue),
        .text(envelope.sensitivity.rawValue),
        .text(P.eventType),
        .text(payloadJSON),
      ]
    )
  }

  /// Store an arbitrary string value under a key, replacing any existing value.
  public func setValue(_ value: String, forKey key: String) async throws(AuraError) {
    guard !key.isEmpty else {
      throw AuraError.invalidConfiguration("key must not be empty")
    }
    try await database.run(
      sql: """
        INSERT INTO key_value_store (key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;
        """,
      arguments: [
        .text(key),
        .text(value),
        .text(formatDate(Date())),
      ]
    )
  }

  /// Read the string value stored under a key, if any.
  public func value(forKey key: String) async throws(AuraError) -> String? {
    guard !key.isEmpty else {
      throw AuraError.invalidConfiguration("key must not be empty")
    }
    let rows = try await database.query(
      sql: "SELECT value FROM key_value_store WHERE key = ?;",
      arguments: [.text(key)]
    )
    guard let first = rows.first, let value = first["value"]?.text else {
      return nil
    }
    return value
  }

  /// Remove the value stored under a key.
  public func removeValue(forKey key: String) async throws(AuraError) {
    guard !key.isEmpty else {
      throw AuraError.invalidConfiguration("key must not be empty")
    }
    try await database.run(
      sql: "DELETE FROM key_value_store WHERE key = ?;",
      arguments: [.text(key)]
    )
  }

  /// Append a ledger entry to the persistent store.
  public func append(_ entry: ProjectLedgerEntry) async throws(AuraError) {
    try await database.run(
      sql: """
        INSERT INTO ledger_entries (
            id, timestamp, task_id, title, actor, objective, starting_state,
            evidence_inspected, assumptions, decisions, files_changed,
            commands_executed, tests_and_results, security_privacy_impact,
            unresolved_risks, rollback, current_state, next_safe_action,
            integrity_hash
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(entry.id.uuidString),
        .text(formatDate(entry.timestamp)),
        .text(entry.taskID),
        .text(entry.title),
        .text(entry.actor),
        .text(entry.objective),
        .text(entry.startingState),
        .text(encodeJSON(entry.evidenceInspected)),
        .text(encodeJSON(entry.assumptions)),
        .text(encodeJSON(entry.decisions)),
        .text(encodeJSON(entry.filesChanged)),
        .text(encodeJSON(entry.commandsExecuted)),
        .text(encodeJSON(entry.testsAndResults)),
        .text(entry.securityPrivacyImpact),
        .text(encodeJSON(entry.unresolvedRisks)),
        .text(entry.rollback),
        .text(entry.currentState),
        .text(entry.nextSafeAction),
        entry.integrityHash.map(SQLiteValue.text) ?? .null,
      ]
    )
  }

  /// Read ledger entries, optionally since a date, limited to `limit` rows.
  public func entries(since: Date? = nil, limit: Int = 100) async throws(AuraError)
    -> [ProjectLedgerEntry]
  {
    guard limit > 0 else {
      throw AuraError.invalidConfiguration("limit must be positive")
    }

    let sql: String
    let arguments: [SQLiteValue]
    if let since {
      sql = """
        SELECT * FROM ledger_entries
        WHERE datetime(timestamp) >= datetime(?)
        ORDER BY datetime(timestamp) ASC
        LIMIT ?;
        """
      arguments = [.text(formatDate(since)), .integer(limit)]
    } else {
      sql = """
        SELECT * FROM ledger_entries
        ORDER BY datetime(timestamp) ASC
        LIMIT ?;
        """
      arguments = [.integer(limit)]
    }

    let rows = try await database.query(sql: sql, arguments: arguments)
    return rows.map { row in
      ProjectLedgerEntry(
        id: UUID(uuidString: (row["id"]?.text) ?? "") ?? UUID(),
        timestamp: parseDate(row["timestamp"]),
        taskID: row["task_id"]?.text ?? "",
        title: row["title"]?.text ?? "",
        actor: row["actor"]?.text ?? "",
        objective: row["objective"]?.text ?? "",
        startingState: row["starting_state"]?.text ?? "",
        evidenceInspected: decodeJSON(row["evidence_inspected"]?.text ?? "[]"),
        assumptions: decodeJSON(row["assumptions"]?.text ?? "[]"),
        decisions: decodeJSON(row["decisions"]?.text ?? "[]"),
        filesChanged: decodeJSON(row["files_changed"]?.text ?? "[]"),
        commandsExecuted: decodeJSON(row["commands_executed"]?.text ?? "[]"),
        testsAndResults: decodeJSON(row["tests_and_results"]?.text ?? "[]"),
        securityPrivacyImpact: row["security_privacy_impact"]?.text ?? "",
        unresolvedRisks: decodeJSON(row["unresolved_risks"]?.text ?? "[]"),
        rollback: row["rollback"]?.text ?? "",
        currentState: row["current_state"]?.text ?? "",
        nextSafeAction: row["next_safe_action"]?.text ?? "",
        integrityHash: row["integrity_hash"]?.text
      )
    }
  }

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
            retention_json, supersedes, project_id, task_id, session_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
  public func memoryRecords(matching query: MemoryQuery) async throws(AuraError) -> [MemoryRecord]
  {
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
    if let scope = query.scope {
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
    if !query.includeSuperseded {
      clauses.append("id NOT IN (SELECT supersedes FROM memory_records WHERE supersedes IS NOT NULL)")
    }

    let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
    let sql = "SELECT * FROM memory_records \(whereClause) ORDER BY datetime(created_at) ASC;"

    let rows = try await database.query(sql: sql, arguments: arguments)
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
          memoryClass: memoryClass,
          subject: row["subject"]?.text ?? "",
          statement: row["statement"]?.text ?? "",
          evidenceReferences: decodeJSON(row["evidence_references"]?.text ?? "[]"),
          provenance: provenance,
          confidence: row["confidence"].flatMap(\.realValue) ?? 0,
          sensitivity: sensitivity,
          createdAt: parseDate(row["created_at"]),
          observedAt: parseDate(row["observed_at"]),
          retention: retention,
          supersedes: row["supersedes"]?.text.flatMap(UUID.init(uuidString:)),
          scope: MemoryScope(
            projectID: row["project_id"]?.text,
            taskID: row["task_id"]?.text.flatMap(UUID.init(uuidString:)),
            sessionID: row["session_id"]?.text.flatMap(UUID.init(uuidString:))
          )
        ))
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
        throw AuraError.memoryError("unknown memory_class in conflict row \(row["id"]?.text ?? "?")")
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

  private func encodeCodable<T: Encodable>(_ value: T, label: String) throws(AuraError) -> String {
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

  private func decodeCodable<T: Decodable>(_ json: String, label: String) throws(AuraError) -> T {
    guard let data = json.data(using: .utf8) else {
      throw AuraError.serializationError("\(label) is not valid UTF-8")
    }
    do {
      return try jsonDecoder.decode(T.self, from: data)
    } catch {
      throw AuraError.serializationError("Failed to decode \(label): \(error.localizedDescription)")
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private func parseDate(_ value: SQLiteValue?) -> Date {
    guard case .text(let string) = value else { return Date() }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string) ?? Date()
  }

  private func encodeJSON(_ strings: [String]) -> String {
    guard let data = try? JSONEncoder().encode(strings),
      let json = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return json
  }

  private func decodeJSON(_ json: String) -> [String] {
    guard let data = json.data(using: .utf8),
      let strings = try? JSONDecoder().decode([String].self, from: data)
    else {
      return []
    }
    return strings
  }
}

extension SQLiteValue {
  fileprivate var text: String? {
    if case .text(let value) = self { return value }
    return nil
  }
}
