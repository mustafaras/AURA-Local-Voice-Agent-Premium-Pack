import AuraCore
import AuraLifecycle
import AuraStore
import Foundation
import Testing

struct LifecycleObserverTests {
  @Test
  func launchHeartbeatPersistsSession() async throws {
    let store = try await makeStore()
    let observer = LifecycleObserver(store: store, sessionID: "test-session")
    try await observer.recordLaunch()
    let rows = try await store.database.query(
      sql: "SELECT kind FROM lifecycle_heartbeats WHERE session_id = ?;",
      arguments: [.text("test-session")])
    #expect(rows.contains { $0["kind"]?.textValue == "launch" })
  }

  @Test
  func crashRecoveryDetectedWhenNoCleanShutdown() async throws {
    let store = try await makeStore()
    // Pre-populate a previous session with only a launch heartbeat.
    try await store.database.run(
      sql: """
        INSERT INTO lifecycle_heartbeats (id, session_id, timestamp, kind, clean_shutdown)
        VALUES (?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(UUID().uuidString),
        .text("previous-session"),
        .text(ISO8601DateFormatter().string(from: Date())),
        .text("launch"),
        .integer(0),
      ])
    try await store.setValue("previous-session", forKey: LifecycleObserver.currentSessionKey)

    let observer = LifecycleObserver(store: store, sessionID: "current-session")
    let recovered = try await observer.isInCrashRecovery()
    #expect(recovered == true)
  }

  @Test
  func cleanShutdownHeartbeatPreventsCrashRecovery() async throws {
    let store = try await makeStore()
    try await store.database.run(
      sql: """
        INSERT INTO lifecycle_heartbeats (id, session_id, timestamp, kind, clean_shutdown)
        VALUES (?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(UUID().uuidString),
        .text("previous-session"),
        .text(ISO8601DateFormatter().string(from: Date())),
        .text("cleanShutdown"),
        .integer(1),
      ])
    try await store.setValue("previous-session", forKey: LifecycleObserver.currentSessionKey)

    let observer = LifecycleObserver(store: store, sessionID: "current-session")
    let recovered = try await observer.isInCrashRecovery()
    #expect(recovered == false)
  }

  private func makeDatabase() async throws -> AuraDatabase {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    return try AuraDatabase(path: url.path)
  }

  private func makeStore() async throws -> AuraStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return try await AuraStore(path: dir.appendingPathComponent("test.sqlite").path)
  }
}
