import AuraCore
import AuraStore
import Foundation

/// Preflight checklist for migrations across configuration, database, memory,
/// plugin, and model artifacts. Returns a report that callers can present for
/// approval; the rollback controller uses the report to record checkpoints.
public actor MigrationPreflight {
  public static let defaultRequiredFreeBytes: Int64 = 500_000_000

  private let store: AuraStore
  private let now: @Sendable () -> Date

  public init(store: AuraStore, now: @escaping @Sendable () -> Date = Date.init) {
    self.store = store
    self.now = now
  }

  public func run(
    kinds: [MigrationKind] = MigrationKind.allCases,
    currentVersions: [MigrationKind: String] = [:]
  ) async throws(AuraError) -> MigrationPreflightReport {
    var checks: [MigrationCheck] = []
    for kind in kinds {
      let current = currentVersions[kind] ?? "unknown"
      let check = await check(kind: kind, currentVersion: current)
      checks.append(check)
    }

    let passed = checks.allSatisfy { $0.passed }
    let report = MigrationPreflightReport(
      timestamp: now(),
      checks: checks,
      passed: passed,
      canProceed: passed)

    try await audit(report: report)
    return report
  }

  private func check(kind: MigrationKind, currentVersion: String) async -> MigrationCheck {
    switch kind {
    case .configuration:
      return MigrationCheck(
        kind: kind,
        currentVersion: currentVersion,
        targetVersion: "schema-managed",
        passed: true,
        detail: "configuration migration handled by ConfigurationEngine on load")
    case .database:
      let schemaOK = (try? await currentDatabaseSchemaVersion()) != nil
      return MigrationCheck(
        kind: kind,
        currentVersion: currentVersion,
        targetVersion: "latest",
        passed: schemaOK,
        detail: schemaOK ? "database migrations applied" : "database schema version unreadable")
    case .memory:
      return MigrationCheck(
        kind: kind,
        currentVersion: currentVersion,
        targetVersion: "record-managed",
        passed: true,
        detail: "memory records are append-only and version-independent")
    case .plugin:
      let auditOK = (try? await recentPluginAuditCount()) ?? 0 > 0
      return MigrationCheck(
        kind: kind,
        currentVersion: currentVersion,
        targetVersion: "audit-verified",
        passed: auditOK,
        detail: auditOK
          ? "plugin audit table reachable"
          : "no plugin audit history (plugins never installed on this profile)")
    case .model:
      return MigrationCheck(
        kind: kind,
        currentVersion: currentVersion,
        targetVersion: "none",
        passed: true,
        detail: "model migration is a manual local step outside runtime scope")
    }
  }

  private func currentDatabaseSchemaVersion() async throws(AuraError) -> String? {
    let rows = try await store.database.query(
      sql: "SELECT version FROM schema_migrations ORDER BY datetime(applied_at) DESC LIMIT 1;",
      arguments: [])
    return rows.first?["version"]?.textValue
  }

  private func recentPluginAuditCount() async throws(AuraError) -> Int {
    let rows = try await store.database.query(
      sql: "SELECT COUNT(*) AS count FROM plugin_audit_records;",
      arguments: [])
    return rows.first?["count"]?.integerValue ?? 0
  }

  private func audit(report: MigrationPreflightReport) async throws(AuraError) {
    for check in report.checks {
      try await store.database.run(
        sql: """
          INSERT INTO migration_audits (
            id, timestamp, correlation_id, kind, from_version, to_version, result, detail
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
          """,
        arguments: [
          .text(UUID().uuidString),
          .text(formatDate(now())),
          .text(UUID().uuidString),
          .text(check.kind.rawValue),
          .text(check.currentVersion),
          .text(check.targetVersion),
          .text(check.passed ? "passed" : "failed"),
          .text(check.detail),
        ])
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}

public enum MigrationKind: String, Codable, Sendable, Equatable, CaseIterable {
  case configuration
  case database
  case memory
  case plugin
  case model
}

public struct MigrationPreflightReport: Codable, Sendable, Equatable {
  public let timestamp: Date
  public let checks: [MigrationCheck]
  public let passed: Bool
  public let canProceed: Bool
}

public struct MigrationCheck: Codable, Sendable, Equatable {
  public let kind: MigrationKind
  public let currentVersion: String
  public let targetVersion: String
  public let passed: Bool
  public let detail: String
}
