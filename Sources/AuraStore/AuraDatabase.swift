import AuraCore
import Foundation
import SQLite3

/// Coordinates database access for the AuraStore target using the system SQLite3 library.
public actor AuraDatabase {
  public let path: String

  nonisolated(unsafe) var databaseHandle: OpaquePointer?

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
    self.databaseHandle = handle
  }

  deinit {
    sqlite3_close_v2(databaseHandle)
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
