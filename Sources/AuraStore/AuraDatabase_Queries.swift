import AuraCore
import Foundation
import SQLite3

extension AuraDatabase {
  /// Execute a non-query SQL statement.
  public func execute(sql: String) throws(AuraError) {
    var errorMessage: UnsafeMutablePointer<CChar>?
    let result = sqlite3_exec(databaseHandle, sql, nil, nil, &errorMessage)
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
}
