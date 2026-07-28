import AuraCore
import Foundation
import SQLite3

/// Coordinates database access for the AuraStore target using the system SQLite3 library.
public actor AuraDatabase {
  public let path: String

  private nonisolated(unsafe) var db: OpaquePointer?

  public init(path: String) throws(AuraError) {
    self.path = path
    var handle: OpaquePointer?
    let flags = SQLITE_OPEN_URI | SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
    let result = sqlite3_open_v2(path, &handle, flags, nil)
    guard result == SQLITE_OK, handle != nil else {
      let message = String(cString: sqlite3_errmsg(handle))
      sqlite3_close_v2(handle)
      throw AuraError.storeError("Unable to open database at \(path): \(message)")
    }
    self.db = handle
  }

  deinit {
    sqlite3_close_v2(db)
  }

  /// Execute a non-query SQL statement.
  public func execute(sql: String) throws(AuraError) {
    var errorMessage: UnsafeMutablePointer<CChar>?
    let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
    defer { sqlite3_free(errorMessage) }
    guard result == SQLITE_OK else {
      let message = errorMessage.map { String(cString: $0) } ?? "code \(result)"
      throw AuraError.storeError("SQL execution failed: \(message)")
    }
  }

  /// Run a parameterized INSERT/UPDATE/DELETE statement.
  public func run(sql: String, arguments: [SQLiteValue]) throws(AuraError) {
    guard let statement = try prepare(sql: sql) else {
      throw AuraError.storeError("Failed to prepare statement: \(sql)")
    }
    defer { sqlite3_finalize(statement) }
    try bind(statement: statement, arguments: arguments)
    let result = sqlite3_step(statement)
    guard result == SQLITE_DONE else {
      throw AuraError.storeError("Statement step failed: \(sqliteErrorMessage)")
    }
  }

  /// Run a parameterized SELECT statement, returning rows as dictionaries.
  public func query(sql: String, arguments: [SQLiteValue]) throws(AuraError) -> [[String:
    SQLiteValue]]
  {
    guard let statement = try prepare(sql: sql) else {
      throw AuraError.storeError("Failed to prepare statement: \(sql)")
    }
    defer { sqlite3_finalize(statement) }
    try bind(statement: statement, arguments: arguments)

    var rows: [[String: SQLiteValue]] = []
    while true {
      let result = sqlite3_step(statement)
      if result == SQLITE_ROW {
        rows.append(try readRow(statement: statement))
      } else if result == SQLITE_DONE {
        break
      } else {
        throw AuraError.storeError("Query step failed: \(sqliteErrorMessage)")
      }
    }
    return rows
  }

  /// Run all migrations, applying only those that have not yet been applied.
  public func migrate() throws(AuraError) {
    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS events (
            id TEXT PRIMARY KEY,
            schema_version TEXT NOT NULL,
            timestamp DATETIME NOT NULL,
            correlation_id TEXT NOT NULL,
            causation_id TEXT NOT NULL,
            actor TEXT NOT NULL,
            sensitivity TEXT NOT NULL,
            event_type TEXT NOT NULL,
            payload_json TEXT NOT NULL
        );
        """)

    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS ledger_entries (
            id TEXT PRIMARY KEY,
            timestamp DATETIME NOT NULL,
            task_id TEXT NOT NULL,
            title TEXT NOT NULL,
            actor TEXT NOT NULL,
            objective TEXT NOT NULL,
            starting_state TEXT NOT NULL,
            evidence_inspected TEXT NOT NULL DEFAULT '[]',
            assumptions TEXT NOT NULL DEFAULT '[]',
            decisions TEXT NOT NULL DEFAULT '[]',
            files_changed TEXT NOT NULL DEFAULT '[]',
            commands_executed TEXT NOT NULL DEFAULT '[]',
            tests_and_results TEXT NOT NULL DEFAULT '[]',
            security_privacy_impact TEXT NOT NULL DEFAULT '',
            unresolved_risks TEXT NOT NULL DEFAULT '[]',
            rollback TEXT NOT NULL DEFAULT '',
            current_state TEXT NOT NULL DEFAULT '',
            next_safe_action TEXT NOT NULL DEFAULT '',
            integrity_hash TEXT
        );
        """)

    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version TEXT PRIMARY KEY,
            applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        """)

    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS key_value_store (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        """)

    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS memory_records (
            id TEXT PRIMARY KEY,
            memory_class TEXT NOT NULL,
            subject TEXT NOT NULL,
            statement TEXT NOT NULL,
            evidence_references TEXT NOT NULL DEFAULT '[]',
            provenance_json TEXT NOT NULL,
            confidence REAL NOT NULL,
            sensitivity TEXT NOT NULL,
            created_at DATETIME NOT NULL,
            observed_at DATETIME NOT NULL,
            retention_json TEXT NOT NULL,
            supersedes TEXT,
            project_id TEXT,
            task_id TEXT,
            session_id TEXT
        );
        """)

    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS memory_conflicts (
            id TEXT PRIMARY KEY,
            memory_class TEXT NOT NULL,
            subject TEXT NOT NULL,
            existing_record_id TEXT NOT NULL,
            new_record_id TEXT NOT NULL,
            detected_at DATETIME NOT NULL,
            resolution_json TEXT
        );
        """)

    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS provenance_nodes (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            record_id TEXT NOT NULL,
            label TEXT NOT NULL,
            created_at DATETIME NOT NULL,
            authority INTEGER NOT NULL,
            confidence REAL NOT NULL
        );
        """)

    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS provenance_edges (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            source_id TEXT NOT NULL,
            target_id TEXT NOT NULL,
            created_at DATETIME NOT NULL,
            correlation_id TEXT NOT NULL
        );
        """)

    try execute(
      sql: """
        CREATE INDEX IF NOT EXISTS idx_provenance_nodes_record_id
        ON provenance_nodes(record_id);
        """)

    try execute(
      sql: """
        CREATE INDEX IF NOT EXISTS idx_provenance_edges_source
        ON provenance_edges(source_id);
        """)

    try execute(
      sql: """
        CREATE INDEX IF NOT EXISTS idx_provenance_edges_target
        ON provenance_edges(target_id);
        """)

    try execute(
      sql: """
        CREATE TABLE IF NOT EXISTS provenance_shadows (
            id TEXT PRIMARY KEY,
            record_id TEXT NOT NULL,
            node_id TEXT NOT NULL,
            shadowed_at DATETIME NOT NULL,
            reason TEXT NOT NULL,
            actor TEXT NOT NULL
        );
        """)

    try recordMigration(version: "v1_0_0_initial")
    try recordMigration(version: "v1_1_0_key_value_store")
    try recordMigration(version: "v1_2_0_memory_records")
    try recordMigration(version: "v1_3_0_provenance_graph")
    try enableForeignKeys()
  }

  private func recordMigration(version: String) throws(AuraError) {
    try run(
      sql:
        "INSERT OR IGNORE INTO schema_migrations (version, applied_at) VALUES (?, datetime('now'));",
      arguments: [.text(version)]
    )
  }

  private func enableForeignKeys() throws(AuraError) {
    try execute(sql: "PRAGMA foreign_keys = ON;")
  }

  private func prepare(sql: String) throws(AuraError) -> OpaquePointer? {
    var statement: OpaquePointer?
    let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
    guard result == SQLITE_OK else {
      throw AuraError.storeError("Failed to prepare SQL: \(sqliteErrorMessage)")
    }
    return statement
  }

  private func bind(statement: OpaquePointer, arguments: [SQLiteValue]) throws(AuraError) {
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

  private func readRow(statement: OpaquePointer) throws(AuraError) -> [String: SQLiteValue] {
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

  private var sqliteErrorMessage: String {
    String(cString: sqlite3_errmsg(db))
  }
}

/// A simple type-erased SQLite value representation.
public enum SQLiteValue: Sendable, Equatable {
  case null
  case integer(Int)
  case real(Double)
  case text(String)
  case blob(Data)

  public var integerValue: Int? {
    if case .integer(let value) = self { return value }
    return nil
  }

  public var realValue: Double? {
    if case .real(let value) = self { return value }
    return nil
  }

  public var textValue: String? {
    if case .text(let value) = self { return value }
    return nil
  }
}
