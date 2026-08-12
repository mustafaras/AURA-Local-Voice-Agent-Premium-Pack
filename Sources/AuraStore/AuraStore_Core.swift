import AuraCore
import Foundation
import SQLite3

extension AuraStore {
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

  /// Append an immutable plugin security audit record.
  public func appendPluginAudit(_ record: PluginAuditRecord) async throws(AuraError) {
    try await database.run(
      sql: """
        INSERT INTO plugin_audit_records (
            id, timestamp, plugin_id, version, action, actor, outcome, detail, correlation_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(record.id.uuidString),
        .text(formatDate(record.timestamp)),
        .text(record.pluginID),
        .text(record.version),
        .text(record.action),
        .text(record.actor.rawValue),
        .text(record.outcome),
        .text(record.detail),
        .text(record.correlationID.uuidString),
      ])
  }

  /// Read a plugin's durable audit history in chronological order.
  public func pluginAuditRecords(pluginID: String, limit: Int = 500) async throws(AuraError)
    -> [PluginAuditRecord]
  {
    guard !pluginID.isEmpty, limit > 0 else {
      throw AuraError.invalidConfiguration("pluginID must not be empty and limit must be positive")
    }
    let rows = try await database.query(
      sql: """
        SELECT * FROM plugin_audit_records
        WHERE plugin_id = ?
        ORDER BY datetime(timestamp) ASC
        LIMIT ?;
        """,
      arguments: [.text(pluginID), .integer(limit)])
    return rows.compactMap { row in
      guard
        let id = UUID(uuidString: row["id"]?.text ?? ""),
        let correlationID = UUID(uuidString: row["correlation_id"]?.text ?? "")
      else { return nil }
      return PluginAuditRecord(
        id: id,
        timestamp: parseDate(row["timestamp"]),
        pluginID: row["plugin_id"]?.text ?? "",
        version: row["version"]?.text ?? "",
        action: row["action"]?.text ?? "",
        actor: ActorID(rawValue: row["actor"]?.text ?? "system") ?? .system,
        outcome: row["outcome"]?.text ?? "",
        detail: row["detail"]?.text ?? "",
        correlationID: correlationID)
    }
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
}
