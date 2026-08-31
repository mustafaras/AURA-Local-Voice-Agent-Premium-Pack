import Foundation

// MARK: - Performance / latency health aggregator

/// A measured latency sample classified by `LatencyMeasuredEvent.Kind`.
public struct LatencySample: Sendable, Equatable {
  public let kind: LatencyMeasuredEvent.Kind
  public let latencySeconds: Double
  public let budgetSeconds: Double
  public let isMockEngine: Bool
  public let measuredAt: Date

  public init(
    kind: LatencyMeasuredEvent.Kind,
    latencySeconds: Double,
    budgetSeconds: Double,
    isMockEngine: Bool,
    measuredAt: Date
  ) {
    self.kind = kind
    self.latencySeconds = latencySeconds
    self.budgetSeconds = budgetSeconds
    self.isMockEngine = isMockEngine
    self.measuredAt = measuredAt
  }
}

/// A point-in-time health snapshot with percentile latency values.
public struct SystemHealthSnapshot: Sendable, Equatable, Codable {
  /// Number of latency samples recorded since startup.
  public let sampleCount: Int

  /// Median wake-to-acknowledgement latency in seconds. Zero when no
  /// `wakeToAck` samples exist.
  public let medianWakeToAckSeconds: Double

  /// Worst (maximum) wake-to-acknowledgement latency in seconds.
  public let worstWakeToAckSeconds: Double

  /// Median deterministic simple-command completion latency in seconds.
  public let medianSimpleCommandSeconds: Double

  /// Worst deterministic simple-command completion latency in seconds.
  public let worstSimpleCommandSeconds: Double

  /// True if any wake-word false accepts have been reported.
  public let wakeWordFalseAccepts: UInt64

  /// True if Ollama health has ever been reported unhealthy.
  public let ollamaUnhealthy: Bool

  /// True if the snapshot was computed from mock engines only.
  public let isMockEngineDerived: Bool

  /// Timestamp when the snapshot was taken.
  public let timestamp: Date

  public init(
    sampleCount: Int,
    medianWakeToAckSeconds: Double,
    worstWakeToAckSeconds: Double,
    medianSimpleCommandSeconds: Double,
    worstSimpleCommandSeconds: Double,
    wakeWordFalseAccepts: UInt64,
    ollamaUnhealthy: Bool,
    isMockEngineDerived: Bool,
    timestamp: Date = Date()
  ) {
    self.sampleCount = sampleCount
    self.medianWakeToAckSeconds = medianWakeToAckSeconds
    self.worstWakeToAckSeconds = worstWakeToAckSeconds
    self.medianSimpleCommandSeconds = medianSimpleCommandSeconds
    self.worstSimpleCommandSeconds = worstSimpleCommandSeconds
    self.wakeWordFalseAccepts = wakeWordFalseAccepts
    self.ollamaUnhealthy = ollamaUnhealthy
    self.isMockEngineDerived = isMockEngineDerived
    self.timestamp = timestamp
  }
}

/// Subscribes to latency, wake-word, STT, and Ollama health events and
/// produces a `SystemHealthSnapshot` on demand.
///
/// All state is isolated to the actor. Tests can inject a custom clock.
/// Percentile summary for one latency kind, in milliseconds.
///
/// `SystemHealthSnapshot` reports only a median and a worst case, which is not
/// enough for the R12 SLO contract: that asks for p50/p95/p99. This carries the
/// percentiles plus the honesty fields a measurement record needs — how many
/// samples backed them, and whether any came from a mock engine.
public struct LatencyPercentileSummary: Sendable, Equatable, Codable {
  public let kind: LatencyMeasuredEvent.Kind
  public let sampleCount: Int
  public let p50Milliseconds: Double
  public let p95Milliseconds: Double
  public let p99Milliseconds: Double
  public let maxMilliseconds: Double
  /// True when **every** sample behind these percentiles came from a mock
  /// engine. A record must never present such a summary as a live measurement.
  public let isMockDerived: Bool
  /// Samples that exceeded their declared budget.
  public let budgetBreaches: Int

  public init(
    kind: LatencyMeasuredEvent.Kind,
    sampleCount: Int,
    p50Milliseconds: Double,
    p95Milliseconds: Double,
    p99Milliseconds: Double,
    maxMilliseconds: Double,
    isMockDerived: Bool,
    budgetBreaches: Int
  ) {
    self.kind = kind
    self.sampleCount = sampleCount
    self.p50Milliseconds = p50Milliseconds
    self.p95Milliseconds = p95Milliseconds
    self.p99Milliseconds = p99Milliseconds
    self.maxMilliseconds = maxMilliseconds
    self.isMockDerived = isMockDerived
    self.budgetBreaches = budgetBreaches
  }
}

public actor PerformanceSampler {
  public static let defaultWakeToAckBudgetSeconds: Double = 0.5
  public static let defaultSimpleCommandBudgetSeconds: Double = 1.5

  private var samples: [LatencySample] = []
  private var wakeWordFalseAccepts: UInt64 = 0
  private var ollamaUnhealthy: Bool = false
  private var logger: AuraLogger?

  /// Set during `start(on:)`. Used to label the snapshot as mock-derived
  /// only when every recorded sample came from a mock engine.
  private var allSamplesMock: Bool = true

  public init(logger: AuraLogger? = nil) {
    self.logger = logger
  }

  /// Subscribe to all relevant event types on the provided bus.
  public func start(on eventBus: AuraEventBus) async {
    await eventBus.subscribe(LatencyMeasuredEvent.self) { [weak self] envelope in
      guard let self else { return }
      let event = envelope.payload
      await self.record(
        kind: event.kind,
        latencySeconds: event.latencySeconds,
        budgetSeconds: event.budgetSeconds,
        isMockEngine: event.isMockEngine,
        measuredAt: event.measuredAt)
    }

    await eventBus.subscribe(WakeWordMetricsEvent.self) { [weak self] envelope in
      guard let self else { return }
      await self.record(wakeFalseAccepts: envelope.payload.falseAccepts)
    }

    await eventBus.subscribe(OllamaHealthCheckEvent.self) { [weak self] envelope in
      guard let self else { return }
      await self.record(ollamaHealthy: envelope.payload.healthy)
    }

    await logger?.info("PerformanceSampler started", actor: .system)
  }

  /// Record a latency measurement.
  public func record(
    kind: LatencyMeasuredEvent.Kind,
    latencySeconds: Double,
    budgetSeconds: Double,
    isMockEngine: Bool,
    measuredAt: Date
  ) {
    let sample = LatencySample(
      kind: kind,
      latencySeconds: latencySeconds,
      budgetSeconds: budgetSeconds,
      isMockEngine: isMockEngine,
      measuredAt: measuredAt)
    samples.append(sample)
    if !isMockEngine {
      allSamplesMock = false
    }
    if latencySeconds > budgetSeconds {
      Task {
        await logger?.warning(
          "Latency budget exceeded: \(kind.rawValue) = \(String(format: "%.3f", latencySeconds))s "
            + "budget = \(String(format: "%.3f", budgetSeconds))s",
          actor: .system)
      }
    }
  }

  /// Record wake-word false-accept count (additive; counters are cumulative).
  public func record(wakeFalseAccepts: UInt64) {
    wakeWordFalseAccepts = max(wakeWordFalseAccepts, wakeFalseAccepts)
  }

  /// Record Ollama health.
  public func record(ollamaHealthy: Bool) {
    if !ollamaHealthy {
      ollamaUnhealthy = true
    }
  }

  /// Produce a current percentile snapshot.
  public func snapshot() -> SystemHealthSnapshot {
    let wakeToAck = samples.filter { $0.kind == .wakeToAck }.map { $0.latencySeconds }
    let simpleCommand = samples.filter { $0.kind == .simpleCommandCompletion }
      .map { $0.latencySeconds }

    return SystemHealthSnapshot(
      sampleCount: samples.count,
      medianWakeToAckSeconds: percentile(wakeToAck, fraction: 0.5),
      worstWakeToAckSeconds: wakeToAck.max() ?? 0,
      medianSimpleCommandSeconds: percentile(simpleCommand, fraction: 0.5),
      worstSimpleCommandSeconds: simpleCommand.max() ?? 0,
      wakeWordFalseAccepts: wakeWordFalseAccepts,
      ollamaUnhealthy: ollamaUnhealthy,
      isMockEngineDerived: allSamplesMock,
      timestamp: Date())
  }

  /// Percentile summaries per latency kind, for the kinds that have samples.
  ///
  /// Kinds with no samples are omitted rather than reported as zero: a zero
  /// would read as "measured, and fast", which is the opposite of the truth.
  public func percentileSummaries() -> [LatencyPercentileSummary] {
    LatencyMeasuredEvent.Kind.allCases.compactMap { kind in
      let forKind = samples.filter { $0.kind == kind }
      guard !forKind.isEmpty else { return nil }
      let seconds = forKind.map(\.latencySeconds)
      return LatencyPercentileSummary(
        kind: kind,
        sampleCount: forKind.count,
        p50Milliseconds: percentile(seconds, fraction: 0.50) * 1000,
        p95Milliseconds: percentile(seconds, fraction: 0.95) * 1000,
        p99Milliseconds: percentile(seconds, fraction: 0.99) * 1000,
        maxMilliseconds: (seconds.max() ?? 0) * 1000,
        isMockDerived: forKind.allSatisfy(\.isMockEngine),
        budgetBreaches: forKind.count { $0.latencySeconds > $0.budgetSeconds })
    }
  }

  /// True if every recorded sample is within its declared budget.
  public func allBudgetsMet() -> Bool {
    samples.allSatisfy { $0.latencySeconds <= $0.budgetSeconds }
  }

  private func percentile(_ values: [Double], fraction: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = Double(sorted.count - 1) * max(0, min(1, fraction))
    let lower = Int(floor(index))
    let upper = Int(ceil(index))
    guard lower < sorted.count, upper < sorted.count else {
      return sorted.last ?? 0
    }
    let weight = index - Double(lower)
    return sorted[lower] * (1 - weight) + sorted[upper] * weight
  }
}
