import AuraConfig
import AuraCore
import AuraLifecycle
import AuraSecurity
import AuraStore
import Foundation
import Testing

/// SP-032 / OPEN-14 — R11 synthetic lifecycle harness.
///
/// This suite drives the **real production** lifecycle controllers end-to-end
/// with synthetic, deterministic inputs — the same pattern the repository
/// established in `SP016DeviceRecoveryTests` (drive the real code path, label
/// the evidence honestly). It exercises crash recovery, sleep/wake, safe mode,
/// migration preflight, support-bundle export, update stage/rollback with
/// recovery checkpoints, and reset/uninstall bookkeeping — all without a
/// user-present session, physical device change, or real signed update.
///
/// What this does **not** cover, and what keeps the residual R11 gate open:
/// no real Mac sleep/wake cycle, no physical device unplug, no real signed
/// update transport, and no destructive removal of the user's actual data
/// directory. Every file operation here targets a throwaway temp directory.
/// The evidence class is `deterministic_harness`, never live/release.
@Suite("SP-032 R11 synthetic lifecycle harness", .serialized)
struct SP032LifecycleHarnessTests {

  // MARK: - Fixtures

  private func makeStore() async throws -> AuraStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try await AuraStore(path: dir.appendingPathComponent("test.sqlite").path)
  }

  private func tempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private func makeConfig() async throws -> ConfigurationEngine {
    try await ConfigurationEngine.load(store: MemoryConfigurationStore(), now: Date.init)
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

  // MARK: - 1. Crash recovery (synthetic crash: no clean shutdown)

  @Test("A synthetic crash (no clean shutdown) is detected as crash recovery")
  func syntheticCrashIsDetectedAsRecovery() async throws {
    let store = try await makeStore()
    // Simulate a previous session that launched but never cleanly shut down.
    try await store.database.run(
      sql: """
        INSERT INTO lifecycle_heartbeats (id, session_id, timestamp, kind, clean_shutdown)
        VALUES (?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(UUID().uuidString),
        .text("crashed-session"),
        .text(ISO8601DateFormatter().string(from: Date())),
        .text("launch"),
        .integer(0),
      ])
    try await store.setValue("crashed-session", forKey: LifecycleObserver.currentSessionKey)

    let observer = LifecycleObserver(store: store, sessionID: "current-session")
    let recovered = try await observer.isInCrashRecovery()
    #expect(recovered == true, "a session with no clean shutdown must be in crash recovery")
  }

  @Test("A clean shutdown prevents crash recovery on the next launch")
  func cleanShutdownPreventsCrashRecovery() async throws {
    let store = try await makeStore()
    try await store.database.run(
      sql: """
        INSERT INTO lifecycle_heartbeats (id, session_id, timestamp, kind, clean_shutdown)
        VALUES (?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(UUID().uuidString),
        .text("clean-session"),
        .text(ISO8601DateFormatter().string(from: Date())),
        .text("cleanShutdown"),
        .integer(1),
      ])
    try await store.setValue("clean-session", forKey: LifecycleObserver.currentSessionKey)

    let observer = LifecycleObserver(store: store, sessionID: "current-session")
    let recovered = try await observer.isInCrashRecovery()
    #expect(recovered == false, "a clean shutdown must not trigger crash recovery")
  }

  // MARK: - 2. Sleep / wake recovery

  @Test("Sleep and wake heartbeats are recorded and persisted")
  func sleepWakeHeartbeatsPersist() async throws {
    let store = try await makeStore()
    let observer = LifecycleObserver(store: store, sessionID: "sleep-wake-session")
    try await observer.recordLaunch()
    try await observer.recordSleep()
    try await observer.recordWake()
    try await observer.recordCleanShutdown()

    let rows = try await store.database.query(
      sql: "SELECT kind FROM lifecycle_heartbeats WHERE session_id = ?;",
      arguments: [.text("sleep-wake-session")])
    let kinds = rows.compactMap { $0["kind"]?.textValue }
    #expect(kinds.contains("launch"))
    #expect(kinds.contains("sleep"))
    #expect(kinds.contains("wake"))
    #expect(kinds.contains("cleanShutdown"))
  }

  // MARK: - 3. Safe mode

  @Test("Safe mode can be requested, persisted, and cleared")
  func safeModeRequestPersistClear() async throws {
    let config = try await makeConfig()
    let controller = SafeModeController(configurationEngine: config)
    #expect(await controller.isSafeModeRequested() == false)
    let requested = try await controller.setSafeModeRequested(true, reason: "synthetic recovery")
    #expect(requested == true)
    #expect(await controller.isSafeModeRequested() == true)
    let cleared = try await controller.setSafeModeRequested(false, reason: "synthetic clear")
    #expect(cleared == false)
    #expect(await controller.isSafeModeRequested() == false)
  }

  @Test("Safe mode records a health status entry")
  func safeModeRecordsHealth() async throws {
    let config = try await makeConfig()
    let health = RuntimeHealthRegistry()
    let controller = SafeModeController(configurationEngine: config, healthRegistry: health)
    _ = try await controller.setSafeModeRequested(true, reason: "recovery")
    let snapshot = await health.snapshot()
    #expect(snapshot.contains { $0.componentID == "safe-mode" })
  }

  // MARK: - 4. Migration preflight

  @Test("Migration preflight passes on a fresh database")
  func migrationPreflightPassesFresh() async throws {
    let store = try await makeStore()
    // The plugin check requires audit history; seed one record so the full
    // preflight passes (mirrors the existing MigrationPreflightTests pattern).
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

  @Test("Migration preflight database check reads the latest schema version")
  func migrationPreflightDatabaseCheck() async throws {
    let store = try await makeStore()
    let preflight = MigrationPreflight(store: store)
    let report = try await preflight.run(kinds: [.database])
    #expect(report.checks.first?.kind == .database)
    #expect(report.checks.first?.passed == true)
  }

  // MARK: - 5. Support bundle export

  @Test("Support bundle export creates summary and health files")
  func supportBundleCreatesFiles() async throws {
    let store = try await makeStore()
    let exporter = SupportBundleExporter(store: store)
    let dir = tempDir()
    let health = [RuntimeHealth(componentID: "x", status: .ready, detail: "ok", observedAt: Date(timeIntervalSince1970: 0))]
    let result = try await exporter.export(health: health, maxTraceRows: 10, maxLedgerRows: 10, destination: dir, correlationID: UUID())
    let files = try FileManager.default.contentsOfDirectory(at: result.path, includingPropertiesForKeys: nil)
    #expect(files.map { $0.lastPathComponent }.contains("summary.json"))
    #expect(files.map { $0.lastPathComponent }.contains("health.json"))
  }

  @Test("Support bundle export redacts secret-like content")
  func supportBundleRedactsSecrets() async throws {
    let store = try await makeStore()
    let exporter = SupportBundleExporter(store: store, secretScanner: SecretScanner())
    let dir = tempDir()
    // REPO_HYGIENE_SECRET_FIXTURE: github_token (intentional secret-shaped fixture for redaction test)
    let health = [RuntimeHealth(componentID: "x", status: .ready, detail: "token=ghp_12345678901234567890123456789012345678")]
    let result = try await exporter.export(health: health, maxTraceRows: 10, maxLedgerRows: 10, destination: dir, correlationID: UUID())
    #expect(result.redacted)
    #expect(result.secretScanHits > 0)
  }

  // MARK: - 6. Update stage + rollback + recovery checkpoint

  @Test("Update stages, then rolls back with a recovery checkpoint")
  func updateStageRollbackCheckpoint() async throws {
    let store = try await makeStore()
    let dir = tempDir()
    let stager = UpdateStager(stagingRoot: dir, currentVersion: "1.0.0", minimumFreeBytes: 0, store: store)
    let checkpoint = RecoveryCheckpoint(store: store)
    let rollback = RollbackController(checkpoint: checkpoint, stager: stager)

    // Prepare a verified rollback target (pre-update baseline).
    _ = try await rollback.prepareRollbackTarget(version: "1.0.0")

    // Stage the update.
    let stageResult = try await stager.stage(manifest: manifest(), package: package())
    guard case .staged(let stagedID) = stageResult else {
      Issue.record("expected staged, got \(stageResult)")
      return
    }

    // Roll back the staged update.
    let checkpointID = try await rollback.rollbackStagedUpdate(
      stagedUpdateID: stagedID, reason: "synthetic rollback")

    // The rollback target must still be the last verified target.
    let lastTarget = try await rollback.lastRollbackTarget()
    #expect(lastTarget != nil)
    #expect(lastTarget?.kind == .rollbackTarget)
    #expect(lastTarget?.verified == true)

    // The post-update checkpoint must exist.
    let post = try await checkpoint.checkpoints(kind: .postUpdate, verifiedOnly: true, limit: 1)
    #expect(post.first?.id == checkpointID)
  }

  // MARK: - 7. Reset / uninstall bookkeeping (throwaway temp dirs only)

  @Test("Reset plan records a recovery checkpoint and enumerates scoped items")
  func resetPlanRecordsCheckpoint() async throws {
    let store = try await makeStore()
    let config = try await makeConfig()
    let controller = ResetController(configurationEngine: config, store: store)
    let plan = try await controller.planReset(
      kind: .settings,
      scopes: [.configuration, .database],
      reason: "synthetic reset",
      actor: .user)
    #expect(plan.kind == .settings)
    #expect(plan.items.count >= 2)

    let checkpoints = try await store.database.query(
      sql: "SELECT * FROM recovery_checkpoints WHERE id = ?;",
      arguments: [.text(plan.planID.uuidString)])
    #expect(checkpoints.count == 1)
  }

  @Test("Uninstall assistant executes a reset plan against throwaway temp files")
  func uninstallExecutesResetOnTempFiles() async throws {
    let store = try await makeStore()
    // Create throwaway files that the plan will remove.
    let base = tempDir()
    let fileA = base.appendingPathComponent("a.txt")
    let fileB = base.appendingPathComponent("b.txt")
    try Data("a".utf8).write(to: fileA)
    try Data("b".utf8).write(to: fileB)

    let plan = ResetPlan(
      planID: UUID(),
      kind: .uninstall,
      scopes: [.configuration],
      items: [
        ResetItem(path: fileA.path, kind: .file),
        ResetItem(path: fileB.path, kind: .file),
      ],
      reason: "synthetic uninstall",
      correlationID: UUID(),
      timestamp: Date())

    let assistant = UninstallAssistant(store: store)
    let result = try await assistant.executeReset(plan: plan, actor: .user)
    #expect(result.removed.count == 2)
    #expect(result.failed.isEmpty)
    #expect(FileManager.default.fileExists(atPath: fileA.path) == false)
    #expect(FileManager.default.fileExists(atPath: fileB.path) == false)
  }
}

/// In-memory configuration store for deterministic tests.
private actor MemoryConfigurationStore: ConfigurationStateStoring {
  var state: ConfigurationGovernanceState?
  func loadState() async throws(AuraError) -> ConfigurationGovernanceState? { state }
  func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) { self.state = state }
}
