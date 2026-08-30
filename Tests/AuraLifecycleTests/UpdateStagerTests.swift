import AuraCore
import AuraLifecycle
import AuraStore
import Foundation
import Testing

struct UpdateStagerTests {
  private func makeStore() async throws -> AuraStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try await AuraStore(path: dir.appendingPathComponent("test.sqlite").path)
  }

  private func stagingRoot() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private func manifest(version: String = "2.0.0") -> UpdateManifest {
    UpdateManifest(
      version: version,
      bundleIdentifier: "com.aura.agent",
      minimumOSVersion: "14.0.0",
      channel: "stable",
      publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      downloadURL: "https://example.com/update.zip",
      packageHash: "abcd",
      packageHashAlgorithm: "SHA-256",
      packageSizeBytes: 4,
      signatureBase64: "sig",
      publicKeyBase64: "key",
      previousVersion: "1.0.0",
      minimumPreviousVersion: nil)
  }

  private func package() -> UpdatePackage {
    UpdatePackage(url: URL(fileURLWithPath: "/tmp/update.zip"), data: Data("data".utf8))
  }

  @Test
  func successfulStageWritesFilesAndRow() async throws {
    let store = try await makeStore()
    let dir = stagingRoot()
    let stager = UpdateStager(stagingRoot: dir, currentVersion: "1.0.0", minimumFreeBytes: 0, store: store)
    let result = try await stager.stage(manifest: manifest(), package: package())
    guard case .staged(let id) = result else {
      Issue.record("expected staged, got \(result)")
      return
    }
    let rows = try await store.database.query(sql: "SELECT * FROM staged_updates WHERE id = ?;", arguments: [.text(id.uuidString)])
    #expect(rows.count == 1)
    #expect(rows.first?["status"]?.textValue == "staged")
  }

  @Test
  func lowDiskBlocksStaging() async throws {
    let dir = stagingRoot()
    let stager = UpdateStager(stagingRoot: dir, currentVersion: "1.0.0", minimumFreeBytes: Int64.max, store: nil)
    let result = try await stager.stage(manifest: manifest(), package: package())
    guard case .blocked(let reason) = result else {
      Issue.record("expected blocked, got \(result)")
      return
    }
    #expect(reason.contains("insufficient free disk"))
  }

  @Test
  func rollbackMarksRolledBackAndRemovesDirectory() async throws {
    let store = try await makeStore()
    let dir = stagingRoot()
    let stager = UpdateStager(stagingRoot: dir, currentVersion: "1.0.0", minimumFreeBytes: 0, store: store)
    let result = try await stager.stage(manifest: manifest(), package: package())
    guard case .staged(let id) = result else {
      Issue.record("expected staged, got \(result)")
      return
    }
    let rollback = try await stager.rollback(stagedUpdateID: id, reason: "test rollback")
    guard case .staged = rollback else {
      Issue.record("expected staged after rollback, got \(rollback)")
      return
    }
    let rows = try await store.database.query(sql: "SELECT status FROM staged_updates WHERE id = ?;", arguments: [.text(id.uuidString)])
    #expect(rows.first?["status"]?.textValue == "rolled_back")
  }

  @Test
  func recoverInterruptedRemovesMissingPackageRows() async throws {
    let store = try await makeStore()
    let dir = stagingRoot()
    let stager = UpdateStager(stagingRoot: dir, currentVersion: "1.0.0", minimumFreeBytes: 0, store: store)
    let result = try await stager.stage(manifest: manifest(), package: package())
    guard case .staged(let id) = result else {
      Issue.record("expected staged, got \(result)")
      return
    }
    let rows = try await store.database.query(sql: "SELECT package_path FROM staged_updates WHERE id = ?;", arguments: [.text(id.uuidString)])
    let path = rows.first?["package_path"]?.textValue ?? ""
    try FileManager.default.removeItem(atPath: path)
    let valid = try await stager.recoverInterruptedStagedUpdates()
    #expect(valid.isEmpty)
    let after = try await store.database.query(sql: "SELECT status FROM staged_updates WHERE id = ?;", arguments: [.text(id.uuidString)])
    #expect(after.first?["status"]?.textValue == "interrupted_missing_package")
  }
}
