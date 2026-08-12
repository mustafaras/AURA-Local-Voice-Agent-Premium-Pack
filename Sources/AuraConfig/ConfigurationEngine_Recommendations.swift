import AuraCore
import Foundation

extension ConfigurationEngine {
  // MARK: - Local recommendations

  public func recordMetric(
    _ kind: TuningMetricKind,
    value: Double
  ) async throws(AuraError) {
    guard value.isFinite, value >= 0 else {
      throw AuraError.invalidConfiguration("tuning metric must be finite and non-negative")
    }
    guard effectiveValue(for: "privacy.localRecommendationsEnabled") == .boolean(true) else {
      throw AuraError.permissionDenied("local tuning recommendations require explicit opt-in")
    }
    var candidate = state
    var aggregate = candidate.telemetry[kind] ?? MetricAggregate()
    aggregate.record(value)
    candidate.telemetry[kind] = aggregate
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          action: "metric.aggregate",
          actor: .system,
          accepted: true,
          layer: nil,
          keys: [kind.rawValue],
          detail: "aggregate counter updated; no raw content retained")))
    try await persist(candidate)
  }

  public func generateRecommendations() async throws(AuraError) -> [TuningRecommendation] {
    guard effectiveValue(for: "privacy.localRecommendationsEnabled") == .boolean(true) else {
      throw AuraError.permissionDenied("local tuning recommendations require explicit opt-in")
    }
    var generated: [TuningRecommendation] = []
    let timestamp = now()

    for candidate in [
      latencyRecommendation(timestamp: timestamp),
      correctionRecommendation(timestamp: timestamp),
      energyRecommendation(timestamp: timestamp),
    ].compactMap({ $0 }) {
      generated.append(candidate)
    }

    guard !generated.isEmpty else { return [] }
    var candidate = state
    candidate.recommendations.append(contentsOf: generated)
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          action: "recommendation.generate",
          actor: .system,
          accepted: true,
          layer: nil,
          keys: generated.map(\.key),
          detail: "explainable local recommendations generated")))
    try await persist(candidate)
    return generated
  }

  private func latencyRecommendation(timestamp: Date) -> TuningRecommendation? {
    guard let metric = state.telemetry[.latencySeconds], metric.sampleCount >= 3,
      let current = integerValue(for: "audio.vad.silenceEndFrames"),
      metric.average > numberValue(for: "performance.wakeAcknowledgementBudgetSeconds")
    else { return nil }
    return recommendation(
      key: "audio.vad.silenceEndFrames", value: .integer(max(3, current - 2)),
      explanation: "Average local latency \(format(metric.average))s exceeds the configured "
        + "\(format(numberValue(for: "performance.wakeAcknowledgementBudgetSeconds")))s "
        + "budget across \(metric.sampleCount) samples; reduce the silence window by 2 frames.",
      timestamp: timestamp)
  }

  private func correctionRecommendation(timestamp: Date) -> TuningRecommendation? {
    guard let metric = state.telemetry[.userCorrection], metric.sampleCount >= 3,
      metric.average > 0.15,
      let current = integerValue(for: "stt.stabilizationDelayFrames")
    else { return nil }
    return recommendation(
      key: "stt.stabilizationDelayFrames", value: .integer(min(20, current + 1)),
      explanation: "The aggregate correction rate is \(format(metric.average * 100))% across "
        + "\(metric.sampleCount) samples; add one stabilization frame.", timestamp: timestamp)
  }

  private func energyRecommendation(timestamp: Date) -> TuningRecommendation? {
    guard let metric = state.telemetry[.energyWatts], metric.sampleCount >= 3,
      metric.average > numberValue(for: "performance.energyBudgetWatts"),
      let current = integerValue(for: "models.maxConcurrentLocalModels"), current > 1
    else { return nil }
    return recommendation(
      key: "models.maxConcurrentLocalModels", value: .integer(current - 1),
      explanation: "Average local energy \(format(metric.average))W exceeds the "
        + "\(format(numberValue(for: "performance.energyBudgetWatts")))W budget across "
        + "\(metric.sampleCount) samples; reduce concurrent model residency by one.",
      timestamp: timestamp)
  }

  public func recommendations() -> [TuningRecommendation] {
    state.recommendations
  }

  public func acceptRecommendation(
    id: UUID,
    actor: ActorID = .user
  ) async throws(AuraError) -> ConfigurationChangeResult {
    guard let index = state.recommendations.firstIndex(where: { $0.id == id }),
      state.recommendations[index].status == .pending
    else {
      throw AuraError.invalidConfiguration("pending recommendation not found")
    }
    let recommendation = state.recommendations[index]
    let result = try await apply(
      ConfigurationPatch(
        layer: .userSettings,
        values: [recommendation.key: recommendation.proposedValue],
        source: "accepted local recommendation \(id.uuidString)"),
      actor: actor)
    if result.accepted {
      var candidate = state
      guard let currentIndex = candidate.recommendations.firstIndex(where: { $0.id == id }) else {
        return result
      }
      candidate.recommendations[currentIndex].status = .accepted
      candidate.audit.append(
        audit(
          ConfigurationAuditInput(
            action: "recommendation.accept",
            actor: actor,
            accepted: true,
            layer: .userSettings,
            keys: [recommendation.key],
            detail: "explicit user acceptance")))
      try await persist(candidate)
    }
    return result
  }

  public func rejectRecommendation(id: UUID, actor: ActorID = .user) async throws(AuraError) {
    guard let index = state.recommendations.firstIndex(where: { $0.id == id }),
      state.recommendations[index].status == .pending
    else {
      throw AuraError.invalidConfiguration("pending recommendation not found")
    }
    var candidate = state
    candidate.recommendations[index].status = .rejected
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          action: "recommendation.reject",
          actor: actor,
          accepted: true,
          layer: nil,
          keys: [candidate.recommendations[index].key],
          detail: "explicit user rejection")))
    try await persist(candidate)
  }
}
