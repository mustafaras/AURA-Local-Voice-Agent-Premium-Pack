import AuraCore
import AuraStore
import Foundation

/// Records launch/crash/sleep/wake heartbeats in the store and publishes typed
/// lifecycle events. Does not perform system sleep/wake calls itself — those
/// are observed through notifications or simulated in tests.
public actor LifecycleObserver {
  public static let currentSessionKey = "lifecycle.currentSessionID"

  private let store: AuraStore
  private let eventBus: AuraEventBus?
  private let logger: AuraLogger?
  private let now: @Sendable () -> Date
  private let sessionID: String

  public init(
    store: AuraStore,
    eventBus: AuraEventBus? = nil,
    logger: AuraLogger? = nil,
    now: @escaping @Sendable () -> Date = Date.init,
    sessionID: String = UUID().uuidString
  ) {
    self.store = store
    self.eventBus = eventBus
    self.logger = logger
    self.now = now
    self.sessionID = sessionID
  }

  public func currentSessionID() async throws(AuraError) -> String {
    if let stored = try await store.value(forKey: Self.currentSessionKey) {
      return stored
    }
    try await store.setValue(sessionID, forKey: Self.currentSessionKey)
    return sessionID
  }

  /// Record a launch heartbeat. If the previous session did not record a
  /// clean-shutdown heartbeat, emit a crash-recovery event.
  public func recordLaunch() async throws(AuraError) {
    let previousSessionID = try await store.value(forKey: Self.currentSessionKey)
    try await store.setValue(sessionID, forKey: Self.currentSessionKey)
    try await appendHeartbeat(kind: .launch)
    await emit(LifecycleHeartbeatEvent(sessionID: sessionID, kind: .launch), .internalLevel)

    if let previous = previousSessionID, previous != sessionID {
      let lastWasClean = try await lastHeartbeatWasClean(sessionID: previous)
      if !lastWasClean {
        await emit(LifecycleHeartbeatEvent(sessionID: previous, kind: .crashRecovery), .sensitive)
        await logger?.warning(
          "Crash recovery detected for previous session \(previous)", actor: .lifecycle)
      }
    }
  }

  public func recordSleep() async throws(AuraError) {
    try await appendHeartbeat(kind: .sleep)
    await emit(LifecycleHeartbeatEvent(sessionID: sessionID, kind: .sleep), .internalLevel)
  }

  public func recordWake() async throws(AuraError) {
    try await appendHeartbeat(kind: .wake)
    await emit(LifecycleHeartbeatEvent(sessionID: sessionID, kind: .wake), .internalLevel)
  }

  public func recordCleanShutdown() async throws(AuraError) {
    try await appendHeartbeat(kind: .cleanShutdown, cleanShutdown: true)
    await emit(
      LifecycleHeartbeatEvent(sessionID: sessionID, kind: .cleanShutdown), .internalLevel)
  }

  /// Whether a crash-recovery path is currently active (last session did not
  /// cleanly shut down).
  public func isInCrashRecovery() async throws(AuraError) -> Bool {
    guard let previous = try await store.value(forKey: Self.currentSessionKey),
      previous != sessionID
    else { return false }
    return try await !lastHeartbeatWasClean(sessionID: previous)
  }

  private func appendHeartbeat(kind: LifecycleHeartbeatKind, cleanShutdown: Bool = false)
    async throws(AuraError)
  {
    try await store.database.run(
      sql: """
        INSERT INTO lifecycle_heartbeats (id, session_id, timestamp, kind, clean_shutdown)
        VALUES (?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(UUID().uuidString),
        .text(sessionID),
        .text(formatDate(now())),
        .text(kind.rawValue),
        .integer(cleanShutdown ? 1 : 0),
      ])
  }

  private func lastHeartbeatWasClean(sessionID: String) async throws(AuraError) -> Bool {
    let rows = try await store.database.query(
      sql: """
        SELECT clean_shutdown FROM lifecycle_heartbeats
        WHERE session_id = ? ORDER BY datetime(timestamp) DESC LIMIT 1;
        """,
      arguments: [.text(sessionID)])
    return rows.first?["clean_shutdown"]?.integerValue == 1
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private func emit<P: EventPayload>(_ payload: P, _ sensitivity: SensitivityLevel) async {
    guard let eventBus = eventBus else { return }
    await eventBus.emit(
      EventEnvelope(
        correlationID: UUID(),
        causationID: UUID(),
        actor: .lifecycle,
        sensitivity: sensitivity,
        payload: payload))
  }
}
