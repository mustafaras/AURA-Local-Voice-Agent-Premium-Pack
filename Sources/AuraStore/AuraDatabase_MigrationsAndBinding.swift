import AuraCore
import Foundation
import SQLite3

extension AuraDatabase {
  private static let migrationSchema: [String] = [
    """
    CREATE TABLE IF NOT EXISTS events (
      id TEXT PRIMARY KEY, schema_version TEXT NOT NULL, timestamp DATETIME NOT NULL,
      correlation_id TEXT NOT NULL, causation_id TEXT NOT NULL, actor TEXT NOT NULL,
      sensitivity TEXT NOT NULL, event_type TEXT NOT NULL, payload_json TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS ledger_entries (
      id TEXT PRIMARY KEY, timestamp DATETIME NOT NULL, task_id TEXT NOT NULL,
      title TEXT NOT NULL, actor TEXT NOT NULL, objective TEXT NOT NULL,
      starting_state TEXT NOT NULL, evidence_inspected TEXT NOT NULL DEFAULT '[]',
      assumptions TEXT NOT NULL DEFAULT '[]', decisions TEXT NOT NULL DEFAULT '[]',
      files_changed TEXT NOT NULL DEFAULT '[]', commands_executed TEXT NOT NULL DEFAULT '[]',
      tests_and_results TEXT NOT NULL DEFAULT '[]',
      security_privacy_impact TEXT NOT NULL DEFAULT '',
      unresolved_risks TEXT NOT NULL DEFAULT '[]', rollback TEXT NOT NULL DEFAULT '',
      current_state TEXT NOT NULL DEFAULT '', next_safe_action TEXT NOT NULL DEFAULT '',
      integrity_hash TEXT
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS key_value_store (
      key TEXT PRIMARY KEY, value TEXT NOT NULL,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS memory_records (
      id TEXT PRIMARY KEY, memory_class TEXT NOT NULL, subject TEXT NOT NULL,
      statement TEXT NOT NULL, evidence_references TEXT NOT NULL DEFAULT '[]',
      provenance_json TEXT NOT NULL, confidence REAL NOT NULL, sensitivity TEXT NOT NULL,
      created_at DATETIME NOT NULL, observed_at DATETIME NOT NULL, retention_json TEXT NOT NULL,
      purpose TEXT NOT NULL DEFAULT 'unspecified', supersedes TEXT, project_id TEXT,
      task_id TEXT, session_id TEXT
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS memory_conflicts (
      id TEXT PRIMARY KEY, memory_class TEXT NOT NULL, subject TEXT NOT NULL,
      existing_record_id TEXT NOT NULL, new_record_id TEXT NOT NULL,
      detected_at DATETIME NOT NULL, resolution_json TEXT
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS provenance_nodes (
      id TEXT PRIMARY KEY, kind TEXT NOT NULL, record_id TEXT NOT NULL, label TEXT NOT NULL,
      created_at DATETIME NOT NULL, authority INTEGER NOT NULL, confidence REAL NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS provenance_edges (
      id TEXT PRIMARY KEY, kind TEXT NOT NULL, source_id TEXT NOT NULL, target_id TEXT NOT NULL,
      created_at DATETIME NOT NULL, correlation_id TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_provenance_nodes_record_id ON provenance_nodes(record_id);",
    "CREATE INDEX IF NOT EXISTS idx_provenance_edges_source ON provenance_edges(source_id);",
    "CREATE INDEX IF NOT EXISTS idx_provenance_edges_target ON provenance_edges(target_id);",
    """
    CREATE TABLE IF NOT EXISTS provenance_shadows (
      id TEXT PRIMARY KEY, record_id TEXT NOT NULL, node_id TEXT NOT NULL,
      shadowed_at DATETIME NOT NULL, reason TEXT NOT NULL, actor TEXT NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS plugin_audit_records (
      id TEXT PRIMARY KEY, timestamp DATETIME NOT NULL, plugin_id TEXT NOT NULL,
      version TEXT NOT NULL, action TEXT NOT NULL, actor TEXT NOT NULL,
      outcome TEXT NOT NULL, detail TEXT NOT NULL DEFAULT '', correlation_id TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_plugin_audit_plugin_timestamp "
      + "ON plugin_audit_records(plugin_id, timestamp);",
    """
    CREATE TABLE IF NOT EXISTS redacted_trace_records (
      id TEXT PRIMARY KEY, timestamp DATETIME NOT NULL,
      correlation_id TEXT NOT NULL, causation_id TEXT NOT NULL,
      phase TEXT NOT NULL, event_type TEXT NOT NULL,
      request_id TEXT, action_identifier TEXT, outcome TEXT NOT NULL
    );
    """,
    "CREATE INDEX IF NOT EXISTS idx_redacted_trace_correlation "
      + "ON redacted_trace_records(correlation_id, timestamp);",
  ]

  public func migrate() throws(AuraError) {
    for statement in Self.migrationSchema {
      try execute(sql: statement)
    }
    for version in [
      "v1_0_0_initial", "v1_1_0_key_value_store", "v1_2_0_memory_records",
      "v1_3_0_provenance_graph", "v1_4_0_plugin_audit",
    ] {
      try recordMigration(version: version)
    }
    if try !columnExists(table: "memory_records", column: "purpose") {
      try execute(
        sql: "ALTER TABLE memory_records ADD COLUMN purpose TEXT NOT NULL DEFAULT 'unspecified';")
    }
    try recordMigration(version: "v1_5_0_memory_purpose")
    try recordMigration(version: "v1_6_0_redacted_trace_records")
    try enableForeignKeys()
  }

  func columnExists(table: String, column: String) throws(AuraError) -> Bool {
    let rows = try query(sql: "PRAGMA table_info(\(table));", arguments: [])
    return rows.contains { $0["name"]?.textValue == column }
  }

  func recordMigration(version: String) throws(AuraError) {
    try run(
      sql:
        "INSERT OR IGNORE INTO schema_migrations (version, applied_at) "
        + "VALUES (?, datetime('now'));",
      arguments: [.text(version)]
    )
  }

  func enableForeignKeys() throws(AuraError) {
    try execute(sql: "PRAGMA foreign_keys = ON;")
  }

  func prepare(sql: String) throws(AuraError) -> OpaquePointer? {
    var statement: OpaquePointer?
    let result = sqlite3_prepare_v2(databaseHandle, sql, -1, &statement, nil)
    guard result == SQLITE_OK else {
      throw AuraError.storeError("Failed to prepare SQL: \(sqliteErrorMessage)")
    }
    return statement
  }

  func bind(statement: OpaquePointer, arguments: [SQLiteValue]) throws(AuraError) {
    let parameterCount = sqlite3_bind_parameter_count(statement)
    guard parameterCount == arguments.count else {
      throw AuraError.storeError("Expected \(parameterCount) parameters, got \(arguments.count)")
    }
    for (index, value) in arguments.enumerated() {
      let position = Int32(index + 1)
      let result: Int32
      switch value {
      case .null:
        result = sqlite3_bind_null(statement, position)
      case .integer(let int):
        result = sqlite3_bind_int64(statement, position, sqlite3_int64(int))
      case .real(let double):
        result = sqlite3_bind_double(statement, position, double)
      case .text(let string):
        result = sqlite3_bind_text(
          statement, position, string, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
      case .blob(let data):
        result = data.withUnsafeBytes { rawBuffer in
          sqlite3_bind_blob(
            statement, position, rawBuffer.baseAddress, Int32(data.count),
            unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
      }
      guard result == SQLITE_OK else {
        throw AuraError.storeError("Failed to bind parameter \(position): \(sqliteErrorMessage)")
      }
    }
  }

  func readRow(statement: OpaquePointer) throws(AuraError) -> [String: SQLiteValue] {
    let columnCount = sqlite3_column_count(statement)
    var row: [String: SQLiteValue] = [:]
    for index in 0..<columnCount {
      let name = String(cString: sqlite3_column_name(statement, index))
      switch sqlite3_column_type(statement, index) {
      case SQLITE_NULL:
        row[name] = .null
      case SQLITE_INTEGER:
        row[name] = .integer(Int(sqlite3_column_int64(statement, index)))
      case SQLITE_FLOAT:
        row[name] = .real(sqlite3_column_double(statement, index))
      case SQLITE_TEXT:
        let text = String(cString: sqlite3_column_text(statement, index))
        row[name] = .text(text)
      case SQLITE_BLOB:
        guard let bytes = sqlite3_column_blob(statement, index) else {
          row[name] = .blob(Data())
          continue
        }
        let count = Int(sqlite3_column_bytes(statement, index))
        let data = Data(bytes: bytes, count: count)
        row[name] = .blob(data)
      default:
        throw AuraError.storeError("Unknown column type at \(name)")
      }
    }
    return row
  }

  var sqliteErrorMessage: String {
    String(cString: sqlite3_errmsg(databaseHandle))
  }
}
