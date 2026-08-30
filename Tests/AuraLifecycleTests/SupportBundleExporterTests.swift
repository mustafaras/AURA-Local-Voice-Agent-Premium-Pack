import AuraConfig
import AuraCore
import AuraLifecycle
import AuraSecurity
import AuraStore
import Foundation
import Testing

struct SupportBundleExporterTests {
  private func makeStore() async throws -> AuraStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try await AuraStore(path: dir.appendingPathComponent("test.sqlite").path)
  }

  private func destination() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  }

  @Test
  func exportCreatesSummaryAndHealthFiles() async throws {
    let store = try await makeStore()
    let exporter = SupportBundleExporter(store: store)
    let dir = destination()
    let health = [RuntimeHealth(componentID: "x", status: .ready, detail: "ok", observedAt: Date(timeIntervalSince1970: 0))]
    let result = try await exporter.export(health: health, maxTraceRows: 10, maxLedgerRows: 10, destination: dir, correlationID: UUID())
    let files = try FileManager.default.contentsOfDirectory(at: result.path, includingPropertiesForKeys: nil)
    #expect(files.map { $0.lastPathComponent }.contains("summary.json"))
    #expect(files.map { $0.lastPathComponent }.contains("health.json"))
  }

  @Test
  func exportRedactsSecretLikeContent() async throws {
    let store = try await makeStore()
    let scanner = SecretScanner()
    let exporter = SupportBundleExporter(store: store, secretScanner: scanner)
    let dir = destination()
    let health = [RuntimeHealth(componentID: "x", status: .ready, detail: "token=ghp_12345678901234567890123456789012345678")]
    let result = try await exporter.export(
      health: health,
      maxTraceRows: 10,
      maxLedgerRows: 10,
      destination: dir,
      correlationID: UUID())
    #expect(result.redacted)
    #expect(result.secretScanHits > 0)
  }

  @Test
  func exportRecordsSupportBundleRow() async throws {
    let store = try await makeStore()
    let exporter = SupportBundleExporter(store: store)
    let dir = destination()
    let result = try await exporter.export(maxTraceRows: 10, maxLedgerRows: 10, destination: dir, correlationID: UUID())
    let rows = try await store.database.query(sql: "SELECT * FROM support_bundles WHERE id = ?;", arguments: [.text(result.bundleID.uuidString)])
    #expect(rows.count == 1)
  }
}
