import AuraConfig
import AuraCore
import AuraLifecycle
import AuraStore
import Foundation
import Testing

private actor MemoryConfigurationStore: ConfigurationStateStoring {
  var state: ConfigurationGovernanceState?
  func loadState() async throws(AuraError) -> ConfigurationGovernanceState? { state }
  func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) { self.state = state }
  func setBoolean(_ value: Bool, forKey key: String) async throws(AuraError) {
    let engine = try await ConfigurationEngine.load(store: self)
    _ = try await engine.apply(
      ConfigurationPatch(layer: .userSettings, values: [key: .boolean(value)], source: "test"),
      actor: .user)
  }
}

struct UpdateEngineTests {
  private func makeStore() async throws -> AuraStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try await AuraStore(path: dir.appendingPathComponent("test.sqlite").path)
  }

  private func manifest(version: String = "2.0.0") -> UpdateManifest {
    UpdateManifest(
      version: version,
      bundleIdentifier: "com.aura.agent",
      minimumOSVersion: "14.0.0",
      channel: "stable",
      publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      downloadURL: "https://example.com/update.zip",
      packageHash: "",
      packageHashAlgorithm: "SHA-256",
      packageSizeBytes: 0,
      signatureBase64: "sig",
      publicKeyBase64: "key",
      previousVersion: "1.0.0",
      minimumPreviousVersion: nil)
  }

  @Test
  func checkReturnsNoUpdateWhenDisabled() async throws {
    let validator = UpdatePackageValidator(
      currentVersion: "1.0.0",
      bundleIdentifier: "com.aura.agent",
      updateChannel: "stable",
      clock: { Date(timeIntervalSince1970: 1_700_000_000) },
      signatureVerifier: .alwaysAccept)
    let engine = UpdateEngine(validator: validator)
    let result = await engine.checkForUpdate()
    #expect(result == .noUpdateAvailable)
  }

  @Test
  func manifestSourceCanOfferUpdate() async throws {
    let manifest = manifest()
    let source = FixedManifestSource(manifest: manifest)
    let validator = UpdatePackageValidator(
      currentVersion: "1.0.0",
      bundleIdentifier: "com.aura.agent",
      updateChannel: "stable",
      clock: { Date(timeIntervalSince1970: 1_700_000_000) },
      signatureVerifier: .alwaysAccept)
    let config = MemoryConfigurationStore()
    let configurationEngine = try await ConfigurationEngine.load(store: config)
    try await configurationEngine.apply(
      ConfigurationPatch(layer: .userSettings, values: ["lifecycle.automaticUpdateChecksEnabled": .boolean(true)], source: "test"),
      actor: .user)
    let engine = UpdateEngine(
      validator: validator,
      configurationEngine: configurationEngine,
      manifestSource: source)
    let result = await engine.checkForUpdate()
    #expect(result == .updateAvailable(manifest))
  }

  @Test
  func stagingRequiresApproval() async throws {
    let validator = UpdatePackageValidator(
      currentVersion: "1.0.0",
      bundleIdentifier: "com.aura.agent",
      updateChannel: "stable",
      clock: { Date(timeIntervalSince1970: 1_700_000_000) },
      signatureVerifier: .alwaysAccept)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let stager = UpdateStager(stagingRoot: dir, currentVersion: "1.0.0", minimumFreeBytes: 0)
    let engine = UpdateEngine(validator: validator, stager: stager)
    let result = await engine.stageUpdate(manifest: manifest(), approved: false)
    guard case .blocked(let reason) = result else {
      Issue.record("expected blocked, got \(result)")
      return
    }
    #expect(reason.contains("requires explicit user approval"))
  }

  @Test
  func stagedUpdateEmitsEventAndStoresRow() async throws {
    let store = try await makeStore()
    let data = Data("update".utf8)
    let hash = UpdateHashAlgorithm.sha256.hash(of: data)
    let package = UpdatePackage(url: URL(fileURLWithPath: "/tmp/update.zip"), data: data)
    let manifest = UpdateManifest(
      version: "2.0.0",
      bundleIdentifier: "com.aura.agent",
      minimumOSVersion: "14.0.0",
      channel: "stable",
      publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      downloadURL: "https://example.com/update.zip",
      packageHash: hash,
      packageHashAlgorithm: "SHA-256",
      packageSizeBytes: data.count,
      signatureBase64: "sig",
      publicKeyBase64: "key",
      previousVersion: "1.0.0",
      minimumPreviousVersion: nil)
    let source = FixedManifestSource(manifest: manifest, package: package)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let validator = UpdatePackageValidator(
      currentVersion: "1.0.0",
      bundleIdentifier: "com.aura.agent",
      updateChannel: "stable",
      clock: { Date(timeIntervalSince1970: 1_700_000_000) },
      signatureVerifier: .alwaysAccept)
    let stager = UpdateStager(stagingRoot: dir, currentVersion: "1.0.0", minimumFreeBytes: 0, store: store)
    let engine = UpdateEngine(validator: validator, stager: stager, manifestSource: source)
    let result = await engine.stageUpdate(manifest: manifest, approved: true)
    guard case .staged(let id) = result else {
      Issue.record("expected staged, got \(result)")
      return
    }
    let rows = try await store.database.query(sql: "SELECT * FROM staged_updates WHERE id = ?;", arguments: [.text(id.uuidString)])
    #expect(rows.count == 1)
  }

  @Test
  func rollbackStagedUpdateMarksRolledBack() async throws {
    let store = try await makeStore()
    let data = Data("update".utf8)
    let hash = UpdateHashAlgorithm.sha256.hash(of: data)
    let package = UpdatePackage(url: URL(fileURLWithPath: "/tmp/update.zip"), data: data)
    let manifest = UpdateManifest(
      version: "2.0.0",
      bundleIdentifier: "com.aura.agent",
      minimumOSVersion: "14.0.0",
      channel: "stable",
      publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      downloadURL: "https://example.com/update.zip",
      packageHash: hash,
      packageHashAlgorithm: "SHA-256",
      packageSizeBytes: data.count,
      signatureBase64: "sig",
      publicKeyBase64: "key",
      previousVersion: "1.0.0",
      minimumPreviousVersion: nil)
    let source = FixedManifestSource(manifest: manifest, package: package)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let validator = UpdatePackageValidator(
      currentVersion: "1.0.0",
      bundleIdentifier: "com.aura.agent",
      updateChannel: "stable",
      clock: { Date(timeIntervalSince1970: 1_700_000_000) },
      signatureVerifier: .alwaysAccept)
    let stager = UpdateStager(stagingRoot: dir, currentVersion: "1.0.0", minimumFreeBytes: 0, store: store)
    let engine = UpdateEngine(validator: validator, stager: stager, manifestSource: source)
    let stageResult = await engine.stageUpdate(manifest: manifest, approved: true)
    guard case .staged(let id) = stageResult else {
      Issue.record("expected staged, got \(stageResult)")
      return
    }
    let rollback = await engine.rollbackStagedUpdate(stagedUpdateID: id, reason: "test")
    #expect(rollback == .staged(id))
    let rows = try await store.database.query(sql: "SELECT status FROM staged_updates WHERE id = ?;", arguments: [.text(id.uuidString)])
    #expect(rows.first?["status"]?.textValue == "rolled_back")
  }
}

private struct FixedManifestSource: UpdateManifestSource {
  let manifest: UpdateManifest?
  let package: UpdatePackage?

  init(manifest: UpdateManifest? = nil, package: UpdatePackage? = nil) {
    self.manifest = manifest
    self.package = package
  }

  func latestManifest(forChannel channel: String) async -> UpdateManifestSourceResult {
    if let manifest { return .manifest(manifest) }
    return .noUpdateAvailable
  }

  func downloadPackage(manifest: UpdateManifest) async -> UpdatePackageSourceResult {
    if let package { return .package(package) }
    return .noUpdateAvailable
  }
}
