import AuraCore
import AuraStore
import Foundation

/// Records recovery checkpoints used by the rollback controller. A checkpoint
/// is an immutable reference to a safe state that can be restored if a staged
/// update or migration fails.
public actor RecoveryCheckpoint {
  private let store: AuraStore
  private let now: @Sendable () -> Date

  public init(store: AuraStore, now: @escaping @Sendable () -> Date = Date.init) {
    self.store = store
    self.now = now
  }

  @discardableResult
  public func record(
    kind: RecoveryCheckpointKind,
    description: String,
    referenceID: String? = nil,
    correlationID: UUID = UUID(),
    verified: Bool = false
  ) async throws(AuraError) -> UUID {
    let id = UUID()
    try await store.database.run(
      sql: """
        INSERT INTO recovery_checkpoints (
          id, timestamp, correlation_id, kind, description, reference_id, verified
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(id.uuidString),
        .text(formatDate(now())),
        .text(correlationID.uuidString),
        .text(kind.rawValue),
        .text(description),
        referenceID.map(SQLiteValue.text) ?? .null,
        .integer(verified ? 1 : 0),
      ])
    return id
  }

  public func checkpoints(
    kind: RecoveryCheckpointKind? = nil,
    verifiedOnly: Bool = false,
    limit: Int = 100
  ) async throws(AuraError) -> [RecoveryCheckpointRecord] {
    var clauses: [String] = []
    var arguments: [SQLiteValue] = []
    if let kind = kind {
      clauses.append("kind = ?")
      arguments.append(.text(kind.rawValue))
    }
    if verifiedOnly {
      clauses.append("verified = 1")
    }
    let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
    let sql = """
      SELECT * FROM recovery_checkpoints
      \(whereClause)
      ORDER BY datetime(timestamp) DESC
      LIMIT ?;
      """
    arguments.append(.integer(limit))
    let rows = try await store.database.query(sql: sql, arguments: arguments)
    return rows.compactMap { row in
      guard
        let id = UUID(uuidString: row["id"]?.textValue ?? ""),
        let correlationID = UUID(uuidString: row["correlation_id"]?.textValue ?? "")
      else { return nil }
      return RecoveryCheckpointRecord(
        id: id,
        timestamp: parseDate(row["timestamp"]),
        correlationID: correlationID,
        kind: RecoveryCheckpointKind(rawValue: row["kind"]?.textValue ?? "") ?? .manual,
        description: row["description"]?.textValue ?? "",
        referenceID: row["reference_id"]?.textValue,
        verified: row["verified"]?.integerValue == 1)
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
}

public enum RecoveryCheckpointKind: String, Codable, Sendable, Equatable {
  case preUpdate
  case postUpdate
  case preMigration
  case postMigration
  case manual
  case rollbackTarget
}

public struct RecoveryCheckpointRecord: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let timestamp: Date
  public let correlationID: UUID
  public let kind: RecoveryCheckpointKind
  public let description: String
  public let referenceID: String?
  public let verified: Bool

  public var referenceUUID: UUID? {
    referenceID.flatMap { UUID(uuidString: $0) }
  }
}
