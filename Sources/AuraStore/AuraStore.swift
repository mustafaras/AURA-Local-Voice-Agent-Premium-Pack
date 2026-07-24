import Foundation
import SQLite3
import AuraCore

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
                .text(payloadJSON)
            ]
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
                entry.integrityHash.map(SQLiteValue.text) ?? .null
            ]
        )
    }

    /// Read ledger entries, optionally since a date, limited to `limit` rows.
    public func entries(since: Date? = nil, limit: Int = 100) async throws(AuraError) -> [ProjectLedgerEntry] {
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
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func decodeJSON(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
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
