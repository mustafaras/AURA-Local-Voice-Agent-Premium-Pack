import AuraConfig
import AuraCore
import AuraSecurity
import AuraStore
import Foundation

/// Exports a privacy-preserving support bundle: health snapshot, configuration
/// inspection, redacted trace records, ledger entries, and migration audit.
/// Raw payloads, memory statements, screenshots, and secrets are excluded.
/// Content is scanned for secrets before being written; if any are found the
/// bundle is flagged but not aborted.
public actor SupportBundleExporter {
  public static let defaultMaxTraceRows = 500
  public static let defaultMaxLedgerRows = 200
  private let defaultMaxTraceRowsValue: Int
  private let defaultMaxLedgerRowsValue: Int

  private let store: AuraStore
  private let secretScanner: SecretScanner
  private let now: @Sendable () -> Date

  public init(
    store: AuraStore,
    secretScanner: SecretScanner = SecretScanner(),
    maxTraceRows: Int = 500,
    maxLedgerRows: Int = 200,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.store = store
    self.secretScanner = secretScanner
    self.defaultMaxTraceRowsValue = maxTraceRows
    self.defaultMaxLedgerRowsValue = maxLedgerRows
    self.now = now
  }

  public func export(
    health: [RuntimeHealth] = [],
    configuration: ConfigurationInspection? = nil,
    maxTraceRows: Int = 0,
    maxLedgerRows: Int = 0,
    destination: URL? = nil,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> SupportBundleResult {
    let traceRows = maxTraceRows > 0 ? maxTraceRows : defaultMaxTraceRowsValue
    let ledgerRows = maxLedgerRows > 0 ? maxLedgerRows : defaultMaxLedgerRowsValue
    let bundleID = UUID()
    let outputDirectory = destination ?? defaultOutputDirectory().appendingPathComponent(
      bundleID.uuidString, isDirectory: true)

    do {
      try FileManager.default.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
    } catch {
      throw AuraError.lifecycleError("failed to create support bundle directory: \(error.localizedDescription)")
    }

    var secretHits = 0
    var writtenFiles: [String] = []

    secretHits += try writeJSON(
      health, to: outputDirectory.appendingPathComponent("health.json"), writtenFiles: &writtenFiles)
    secretHits += try writeJSON(
      configuration,
      to: outputDirectory.appendingPathComponent("configuration.json"),
      writtenFiles: &writtenFiles)

    let traceRowRecords = try await store.database.query(
      sql: "SELECT * FROM redacted_trace_records ORDER BY datetime(timestamp) DESC LIMIT ?;",
      arguments: [.integer(traceRows)])
    let traceRecords = traceRowRecords.map { row in
      RedactedTraceRecordRow(
        timestamp: parseDate(row["timestamp"]),
        phase: row["phase"]?.textValue ?? "",
        eventType: row["event_type"]?.textValue ?? "",
        requestID: row["request_id"]?.textValue,
        actionIdentifier: row["action_identifier"]?.textValue,
        outcome: row["outcome"]?.textValue ?? "")
    }
    secretHits += try writeJSON(
      traceRecords, to: outputDirectory.appendingPathComponent("redacted_trace.json"),
      writtenFiles: &writtenFiles)

    let entries = try await store.entries(since: nil, limit: maxLedgerRows)
    let sanitizedEntries = entries.map { entry in
      SanitizedLedgerEntry(
        timestamp: entry.timestamp,
        taskID: entry.taskID,
        title: entry.title,
        actor: entry.actor,
        objective: entry.objective,
        startingState: entry.startingState,
        currentState: entry.currentState,
        nextSafeAction: entry.nextSafeAction)
    }
    secretHits += try writeJSON(
      sanitizedEntries,
      to: outputDirectory.appendingPathComponent("ledger.json"),
      writtenFiles: &writtenFiles)

    let migrationRows = try await store.database.query(
      sql: "SELECT * FROM migration_audits ORDER BY datetime(timestamp) DESC LIMIT ?;",
      arguments: [.integer(ledgerRows)])
    let migrationAudits = migrationRows.map { row in
      MigrationAuditRow(
        timestamp: parseDate(row["timestamp"]),
        kind: row["kind"]?.textValue ?? "",
        fromVersion: row["from_version"]?.textValue ?? "",
        toVersion: row["to_version"]?.textValue ?? "",
        result: row["result"]?.textValue ?? "",
        detail: row["detail"]?.textValue ?? "")
    }
    secretHits += try writeJSON(
      migrationAudits,
      to: outputDirectory.appendingPathComponent("migration_audits.json"),
      writtenFiles: &writtenFiles)

    let summary = SupportBundleSummary(
      bundleID: bundleID,
      createdAt: now(),
      correlationID: correlationID,
      redacted: true,
      secretScanHits: secretHits,
      files: writtenFiles)
    secretHits += try writeJSON(
      summary, to: outputDirectory.appendingPathComponent("summary.json"), writtenFiles: &writtenFiles)

    try await store.database.run(
      sql: """
        INSERT INTO support_bundles (id, timestamp, correlation_id, path, redacted, secret_scan_hits, detail)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(bundleID.uuidString),
        .text(formatDate(now())),
        .text(correlationID.uuidString),
        .text(outputDirectory.path),
        .integer(1),
        .integer(secretHits),
        .text("exported \(writtenFiles.count) files"),
      ])

    return SupportBundleResult(
      bundleID: bundleID,
      path: outputDirectory,
      secretScanHits: secretHits,
      redacted: true)
  }

  private func defaultOutputDirectory() -> URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent("AURA", isDirectory: true)
      .appendingPathComponent("SupportBundles", isDirectory: true)
      ?? FileManager.default.temporaryDirectory.appendingPathComponent("aura-support-bundles")
  }

  private func writeJSON<T: Encodable>(
    _ value: T,
    to url: URL,
    writtenFiles: inout [String]
  ) throws(AuraError) -> Int {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(value) else {
      throw AuraError.serializationError("failed to encode support bundle component")
    }
    guard let json = String(data: data, encoding: .utf8) else {
      throw AuraError.serializationError("support bundle component is not UTF-8")
    }
    let matches = secretScanner.scan(json)
    let hits = matches.count
    let sanitized = hits > 0 ? redactSecretMatches(in: json, matches: matches) : json
    do {
      try sanitized.data(using: .utf8)?.write(to: url, options: .atomic)
      writtenFiles.append(url.lastPathComponent)
      return hits
    } catch {
      throw AuraError.lifecycleError("failed to write support bundle file: \(error.localizedDescription)")
    }
  }

  private func redactSecretMatches(in text: String, matches: [SecretMatch]) -> String {
    var result = text
    for match in matches.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
      let start = result.index(result.startIndex, offsetBy: match.range.lowerBound)
      let end = result.index(result.startIndex, offsetBy: match.range.upperBound)
      result.replaceSubrange(start..<end, with: String(repeating: "█", count: match.range.count))
    }
    return result
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

public struct SupportBundleResult: Codable, Sendable, Equatable {
  public let bundleID: UUID
  public let path: URL
  public let secretScanHits: Int
  public let redacted: Bool
}

public struct SupportBundleSummary: Codable, Sendable, Equatable {
  public let bundleID: UUID
  public let createdAt: Date
  public let correlationID: UUID
  public let redacted: Bool
  public let secretScanHits: Int
  public let files: [String]
}

private struct RedactedTraceRecordRow: Codable, Sendable, Equatable {
  let timestamp: Date
  let phase: String
  let eventType: String
  let requestID: String?
  let actionIdentifier: String?
  let outcome: String
}

private struct SanitizedLedgerEntry: Codable, Sendable, Equatable {
  let timestamp: Date
  let taskID: String
  let title: String
  let actor: String
  let objective: String
  let startingState: String
  let currentState: String
  let nextSafeAction: String
}

private struct MigrationAuditRow: Codable, Sendable, Equatable {
  let timestamp: Date
  let kind: String
  let fromVersion: String
  let toVersion: String
  let result: String
  let detail: String
}
