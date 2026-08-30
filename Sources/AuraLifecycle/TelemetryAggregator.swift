import AuraConfig
import AuraCore
import AuraStore
import Foundation

/// Content-free aggregate telemetry (SP-029, OPEN-13, R12).
///
/// This engine implements only explicit opt-in **content-free aggregates**:
/// per-day, per-field counters bucketed by outcome/class/perf band. It never
/// collects raw audio, screenshots, prompts, model outputs, secrets, tokens,
/// mail/document contents, or personal memory contents, and it has **no
/// transport** — nothing leaves the machine. When opt-in is off (the default),
/// every recording path is a no-op.
///
/// The engine is fail-closed by construction: consent defaults to `off`; the
/// opt-in key is user-scoped and reversible; aggregate rows are retained for
/// at most `telemetry.aggregateRetentionDays`; and disabling telemetry (or the
/// kill switch) purges the local staging counters via the same retention path.
public actor TelemetryAggregator {
  public static let optInKey = "telemetry.aggregateOptInEnabled"
  public static let retentionKey = "telemetry.aggregateRetentionDays"
  public static let latencyFieldPrefix = "latency."

  private enum Bump {
    case sessionOutcome(TelemetrySessionOutcomeBucket)
    case confirmationOutcome(TelemetryConfirmationOutcomeBucket)
    case recoveryOutcome(TelemetryRecoveryOutcomeBucket)
    case resourcePressure(TelemetryResourcePressureClass)
    case latency(field: String, milliseconds: Double)
  }

  private let configurationEngine: ConfigurationEngine?
  private let store: AuraStore?
  private let eventBus: AuraEventBus?
  private let healthRegistry: RuntimeHealthRegistry?
  private let now: @Sendable () -> Date

  public init(
    configurationEngine: ConfigurationEngine? = nil,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil,
    healthRegistry: RuntimeHealthRegistry? = nil,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.configurationEngine = configurationEngine
    self.store = store
    self.eventBus = eventBus
    self.healthRegistry = healthRegistry
    self.now = now
  }

  /// True only when explicit opt-in aggregate telemetry is enabled in a
  /// user-scoped configuration layer. Defaults to false (consent off).
  public func isOptInEnabled() async -> Bool {
    guard let engine = configurationEngine else { return false }
    guard case .boolean(let value) = await engine.effectiveValue(for: Self.optInKey)
    else { return false }
    return value
  }

  /// Max retention (days) for aggregate rows. Defaults to 90; bounded 1...365
  /// at the configuration schema layer.
  public func retentionDays() async -> Int {
    guard let engine = configurationEngine else { return 90 }
    guard case .integer(let value) = await engine.effectiveValue(for: Self.retentionKey)
    else { return 90 }
    return max(1, value)
  }

  // MARK: - Opt-in control

  /// Set or clear opt-in consent. Defaults off; the caller (typically a
  /// user-scoped Privacy panel action) must pass `true` explicitly to enable.
  @discardableResult
  public func setOptInEnabled(
    _ enabled: Bool, actor: ActorID = .user
  ) async throws(AuraError) -> Bool {
    guard let engine = configurationEngine else {
      throw AuraError.lifecycleError("configuration engine not available")
    }
    let result = try await engine.apply(
      ConfigurationPatch(
        layer: actor == .user ? .userSettings : .sessionOverrides,
        values: [Self.optInKey: .boolean(enabled)],
        source: "TelemetryAggregator"),
      actor: actor)
    guard result.accepted else {
      throw AuraError.lifecycleError(
        "telemetry opt-in preference rejected: \(result.warnings.joined(separator: "; "))")
    }
    let nowState = enabled
    await healthRegistry?.record(
      componentID: "telemetry.aggregator",
      status: nowState ? .ready : .disabledByConfiguration,
      detail: enabled ? "opt-in aggregate telemetry enabled" : "opt-in aggregate telemetry disabled")
    return nowState
  }

  /// Disables telemetry and immediately purges retained aggregate rows at or
  /// beyond the current retention window — this is the "telemetry-off" path.
  /// A full purge (all rows) is used when consent is fully withdrawn.
  public func disableAndPurge(actor: ActorID = .user) async throws(AuraError) {
    _ = try await setOptInEnabled(false, actor: actor)
    try await purgeRetainedRows(keepWithinDays: 0)
  }

  // MARK: - Recording (content-free buckets only)

  public func bumpSessionOutcome(
    _ outcome: TelemetrySessionOutcomeBucket, correlationID: UUID = UUID(), actor: ActorID = .lifecycle
  ) async {
    await bump(.sessionOutcome(outcome), actor: actor, correlationID: correlationID)
  }

  public func bumpConfirmationOutcome(
    _ outcome: TelemetryConfirmationOutcomeBucket, correlationID: UUID = UUID(), actor: ActorID = .lifecycle
  ) async {
    await bump(.confirmationOutcome(outcome), actor: actor, correlationID: correlationID)
  }

  public func bumpRecoveryOutcome(
    _ outcome: TelemetryRecoveryOutcomeBucket, correlationID: UUID = UUID(), actor: ActorID = .lifecycle
  ) async {
    await bump(.recoveryOutcome(outcome), actor: actor, correlationID: correlationID)
  }

  public func bumpResourcePressure(
    _ classification: TelemetryResourcePressureClass, correlationID: UUID = UUID(), actor: ActorID = .lifecycle
  ) async {
    await bump(.resourcePressure(classification), actor: actor, correlationID: correlationID)
  }

  public func recordLatencyMilliseconds(
    _ milliseconds: Double, correlationID: UUID = UUID(), actor: ActorID = .lifecycle
  ) async {
    await bump(.latency(field: Self.latencyFieldPrefix + "sample", milliseconds: milliseconds), actor: actor, correlationID: correlationID)
  }

  // MARK: - Retention

  /// Delete aggregate rows outside the retention window. A `keepWithinDays`
  /// of 0 deletes everything (used on telemetry-off / consent withdrawal).
  public func purgeRetainedRows(keepWithinDays: Int) async throws(AuraError) {
    guard let store = store else { return }
    let cutoff = keepWithinDays <= 0 ? "" : Self.dayString(now().addingTimeInterval(TimeInterval(-keepWithinDays * 86_400)))
    let sql =
      keepWithinDays <= 0
      ? "DELETE FROM telemetry_aggregates;"
      : "DELETE FROM telemetry_aggregates WHERE day < ?;"
    try await store.database.run(
      sql: sql,
      arguments: keepWithinDays <= 0 ? [] : [.text(cutoff)])
  }

  // MARK: - Private

  private func bump(_ bump: Bump, actor: ActorID, correlationID: UUID) async {
    // Fail-closed: never record unless opt-in aggregate telemetry is enabled.
    guard await isOptInEnabled() else { return }
    // Fail-closed: without a store there is nowhere to record; this is a no-op.
    guard store != nil else { return }

    switch bump {
    case .sessionOutcome(let outcome):
      await incrementField("session_outcome", bucket: outcome.rawValue)
    case .confirmationOutcome(let outcome):
      await incrementField("confirmation_outcome", bucket: outcome.rawValue)
    case .recoveryOutcome(let outcome):
      await incrementField("recovery_outcome", bucket: outcome.rawValue)
    case .resourcePressure(let classification):
      await incrementField("resource_pressure_class", bucket: classification.rawValue)
    case .latency(let field, let milliseconds):
      let bucket = latencyBucket(milliseconds: milliseconds)
      await incrementField(field, bucket: bucket)
    }

    let event = TelemetryAggregateEvent(
      field: fieldName(for: bump), bucket: bucketName(for: bump), count: 1, day: Self.dayString(now()))
    await eventBus?.emit(
      EventEnvelope(
        correlationID: correlationID,
        causationID: UUID(),
        actor: actor,
        sensitivity: .internalLevel,
        payload: event))
  }

  private func incrementField(_ field: String, bucket: String) async {
    guard let store = store else { return }
    let day = Self.dayString(now())
    do {
      try await store.database.run(
        sql: """
          INSERT INTO telemetry_aggregates (day, field, bucket, count)
          VALUES (?, ?, ?, 1)
          ON CONFLICT(day, field, bucket)
          DO UPDATE SET count = count + 1;
          """,
        arguments: [.text(day), .text(field), .text(bucket)])
    } catch {
      // Non-fatal diagnostics-only; telemetry recording must never surface an
      // error to the user or break the host loop.
      await healthRegistry?.record(
        componentID: "telemetry.aggregator",
        status: .degraded,
        detail: "aggregate increment failed (non-fatal): \(error)")
    }
  }

  private func latencyBucket(milliseconds: Double) -> String {
    // Coarse, stable percentile bands. No exact timestamp or value is stored.
    switch milliseconds {
    case ..<100: return "p00_lt100ms"
    case ..<250: return "p25_lt250ms"
    case ..<500: return "p50_lt500ms"
    case ..<1000: return "p75_lt1000ms"
    default: return "p99_ge1000ms"
    }
  }

  private func fieldName(for bump: Bump) -> String {
    switch bump {
    case .sessionOutcome: "session_outcome"
    case .confirmationOutcome: "confirmation_outcome"
    case .recoveryOutcome: "recovery_outcome"
    case .resourcePressure: "resource_pressure_class"
    case .latency(let field, _): field
    }
  }

  private func bucketName(for bump: Bump) -> String {
    switch bump {
    case .sessionOutcome(let o): o.rawValue
    case .confirmationOutcome(let o): o.rawValue
    case .recoveryOutcome(let o): o.rawValue
    case .resourcePressure(let c): c.rawValue
    case .latency(_, let ms): latencyBucket(milliseconds: ms)
    }
  }

  private static func dayString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}
