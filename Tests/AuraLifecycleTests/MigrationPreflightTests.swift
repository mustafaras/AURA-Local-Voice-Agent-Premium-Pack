import AuraCore
import AuraLifecycle
import AuraStore
import Foundation
import Testing

struct MigrationPreflightTests {
  private func makeStore() async throws -> AuraStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try await AuraStore(path: dir.appendingPathComponent("test.sqlite").path)
  }

  @Test
  func allMigrationsPassWithFreshDatabase() async throws {
    let store = try await makeStore()
    try await store.database.run(
      sql: """
        INSERT INTO plugin_audit_records (
          id, timestamp, plugin_id, version, action, actor, outcome, detail, correlation_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(UUID().uuidString),
        .text("1970-01-01T00:00:00Z"),
        .text("plugin.example"),
        .text("1.0.0"),
        .text("load"),
        .text("test"),
        .text("allowed"),
        .text(""),
        .text(UUID().uuidString),
      ])
    let preflight = MigrationPreflight(store: store)
    let report = try await preflight.run()
    #expect(report.passed)
    #expect(report.canProceed)
    #expect(report.checks.count == MigrationKind.allCases.count)
  }

  @Test
  func databaseCheckReadsLatestMigrationVersion() async throws {
    let store = try await makeStore()
    let preflight = MigrationPreflight(store: store)
    let report = try await preflight.run(kinds: [.database])
    guard let check = report.checks.first else {
      Issue.record("missing database check")
      return
    }
    #expect(check.kind == .database)
    #expect(check.passed)
  }

  @Test
  func pluginCheckFailsWithoutAuditHistory() async throws {
    let store = try await makeStore()
    let preflight = MigrationPreflight(store: store)
    let report = try await preflight.run(kinds: [.plugin])
    guard let check = report.checks.first else {
      Issue.record("missing plugin check")
      return
    }
    #expect(check.kind == .plugin)
    #expect(!check.passed)
    #expect(check.detail.contains("no plugin audit history"))
  }

  @Test
  func pluginCheckPassesAfterAuditRecord() async throws {
    let store = try await makeStore()
    try await store.database.run(
      sql: """
        INSERT INTO plugin_audit_records (
          id, timestamp, plugin_id, version, action, actor, outcome, detail, correlation_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(UUID().uuidString),
        .text("1970-01-01T00:00:00Z"),
        .text("plugin.example"),
        .text("1.0.0"),
        .text("load"),
        .text("test"),
        .text("allowed"),
        .text(""),
        .text(UUID().uuidString),
      ])
    let preflight = MigrationPreflight(store: store)
    let report = try await preflight.run(kinds: [.plugin])
    #expect(report.checks.first?.passed == true)
  }
}
