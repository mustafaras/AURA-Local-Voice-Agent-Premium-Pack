import AuraCore
import Foundation
import SQLite3

/// Persistent SQLite-backed append-only store for events and ledger entries.
public actor AuraStore: LedgerBackend {
  public let database: AuraDatabase
  let jsonEncoder: JSONEncoder
  let jsonDecoder: JSONDecoder

  public init(path: String) async throws(AuraError) {
    let database = try AuraDatabase(path: path)
    self.database = database
    self.jsonEncoder = JSONEncoder()
    self.jsonEncoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder.outputFormatting = .sortedKeys
    self.jsonDecoder = JSONDecoder()
    self.jsonDecoder.dateDecodingStrategy = .iso8601
    try await database.migrate()
  }

}

extension SQLiteValue {
  var text: String? {
    if case .text(let value) = self { return value }
    return nil
  }
}
