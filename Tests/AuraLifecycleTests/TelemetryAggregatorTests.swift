import AuraConfig
import AuraCore
import AuraLifecycle
import AuraStore
import Foundation
import Testing

private actor MemoryConfigurationStore: ConfigurationStateStoring {
  var state: ConfigurationGovernanceState?
  func loadState() async throws(AuraError) -> ConfigurationGovernanceState? { state }
  func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) {
    self.state = state
  }
}

private func makeConfig() async throws -> ConfigurationEngine {
  try await ConfigurationEngine.load(store: MemoryConfigurationStore(), now: Date.init)
}

private func makeStore() async throws -> AuraStore {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return try await AuraStore(path: dir.appendingPathComponent("test.sqlite").path)
}

struct TelemetryAggregatorTests {
  private func aggregateCounts(
    _ store: AuraStore, field: String, bucket: String, day: String
  ) async throws -> Int {
    let rows = try await store.database.query(
      sql: "SELECT count FROM telemetry_aggregates WHERE day = ? AND field = ? AND bucket = ?;",
      arguments: [.text(day), .text(field), .text(bucket)])
    return rows.first?["count"]?.integerValue ?? 0
  }

  @Test
  func optInDefaultsToOff() async throws {
    let config = try await makeConfig()
    let aggregator = TelemetryAggregator(configurationEngine: config)
    #expect(await aggregator.isOptInEnabled() == false)
  }

  @Test
  func doesNotRecordWhenOptInOff() async throws {
    let config = try await makeConfig()
    let store = try await makeStore()
    let aggregator = TelemetryAggregator(configurationEngine: config, store: store)
    await aggregator.bumpSessionOutcome(.completed)
    let rows = try await store.database.query(
      sql: "SELECT COUNT(*) AS c FROM telemetry_aggregates;", arguments: [])
    #expect(rows.first?["c"]?.integerValue == 0)
  }

  @Test
  func optInToggleIsReversible() async throws {
    let config = try await makeConfig()
    let aggregator = TelemetryAggregator(configurationEngine: config)
    let enabled = try await aggregator.setOptInEnabled(true)
    #expect(enabled == true)
    #expect(await aggregator.isOptInEnabled() == true)
    let disabled = try await aggregator.setOptInEnabled(false)
    #expect(disabled == false)
    #expect(await aggregator.isOptInEnabled() == false)
  }

  @Test
  func recordsSessionOutcomeCountWhenOptedIn() async throws {
    let config = try await makeConfig()
    let store = try await makeStore()
    let aggregator = TelemetryAggregator(
      configurationEngine: config, store: store, now: { Date(timeIntervalSince1970: 0) })
    _ = try await aggregator.setOptInEnabled(true)

    await aggregator.bumpSessionOutcome(.completed)
    await aggregator.bumpSessionOutcome(.completed)
    await aggregator.bumpSessionOutcome(.blocked)

    let day = "1970-01-01"
    let completed = try await aggregateCounts(
      store, field: "session_outcome", bucket: "completed", day: day)
    let blocked = try await aggregateCounts(
      store, field: "session_outcome", bucket: "blocked", day: day)
    #expect(completed == 2)
    #expect(blocked == 1)
  }

  @Test
  func recordsConfirmationAndRecoveryOutcomes() async throws {
    let config = try await makeConfig()
    let store = try await makeStore()
    let aggregator = TelemetryAggregator(configurationEngine: config, store: store, now: { Date(timeIntervalSince1970: 0) })
    _ = try await aggregator.setOptInEnabled(true)

    await aggregator.bumpConfirmationOutcome(.denied)
    await aggregator.bumpRecoveryOutcome(.safeModeEntered)

    #expect(
      try await aggregateCounts(
        store, field: "confirmation_outcome", bucket: "denied", day: "1970-01-01") == 1)
    #expect(
      try await aggregateCounts(
        store, field: "recovery_outcome", bucket: "safe_mode_entered", day: "1970-01-01") == 1)
  }

  @Test
  func latencyIsBucketedNotRaw() async throws {
    let config = try await makeConfig()
    let store = try await makeStore()
    let aggregator = TelemetryAggregator(configurationEngine: config, store: store, now: { Date(timeIntervalSince1970: 0) })
    _ = try await aggregator.setOptInEnabled(true)

    await aggregator.recordLatencyMilliseconds(80)   // p00_lt100ms
    await aggregator.recordLatencyMilliseconds(900)  // p75_lt1000ms
    await aggregator.recordLatencyMilliseconds(2500) // p99_ge1000ms

    #expect(
      try await aggregateCounts(
        store, field: "latency.sample", bucket: "p00_lt100ms", day: "1970-01-01") == 1)
    #expect(
      try await aggregateCounts(
        store, field: "latency.sample", bucket: "p75_lt1000ms", day: "1970-01-01") == 1)
    #expect(
      try await aggregateCounts(
        store, field: "latency.sample", bucket: "p99_ge1000ms", day: "1970-01-01") == 1)
  }

  @Test
  func disableAndPurgeClearsAllAggregates() async throws {
    let config = try await makeConfig()
    let store = try await makeStore()
    let aggregator = TelemetryAggregator(configurationEngine: config, store: store, now: { Date(timeIntervalSince1970: 0) })
    _ = try await aggregator.setOptInEnabled(true)
    await aggregator.bumpSessionOutcome(.completed)
    #expect(
      try await aggregateCounts(
        store, field: "session_outcome", bucket: "completed", day: "1970-01-01") == 1)

    try await aggregator.disableAndPurge()
    #expect(await aggregator.isOptInEnabled() == false)
    let rows = try await store.database.query(
      sql: "SELECT COUNT(*) AS c FROM telemetry_aggregates;", arguments: [])
    #expect(rows.first?["c"]?.integerValue == 0)
  }

  @Test
  func retentionPurgeRemovesOldDays() async throws {
    let config = try await makeConfig()
    let store = try await makeStore()
    let aggregator = TelemetryAggregator(configurationEngine: config, store: store, now: { Date(timeIntervalSince1970: 0) })
    _ = try await aggregator.setOptInEnabled(true)
    await aggregator.bumpSessionOutcome(.completed)

    // Simulate a 2-day-old row directly, then purge keeping only 1 day.
    try await store.database.run(
      sql: "INSERT INTO telemetry_aggregates (day, field, bucket, count) VALUES (?, ?, ?, 1);",
      arguments: [
        .text("1969-12-30"), .text("session_outcome"), .text("completed"),
      ])
    try await aggregator.purgeRetainedRows(keepWithinDays: 1)

    let oldRows = try await store.database.query(
      sql: "SELECT COUNT(*) AS c FROM telemetry_aggregates WHERE day = '1969-12-30';",
      arguments: [])
    #expect(oldRows.first?["c"]?.integerValue == 0)
  }

  @Test
  func configSchemaDefaultsToConsentOff() async throws {
    let config = try await makeConfig()
    #expect(await config.effectiveValue(for: TelemetryAggregator.optInKey) == .boolean(false))
  }
}
