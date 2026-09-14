import AuraCore
import Foundation
import Testing

@testable import AURA

/// UI-3 G3-3/G3-4 pins the honest telemetry contract: summaries remain the
/// source of truth, history is bounded and in-memory, and the deck exposes
/// its budget and provenance channels.
struct UI3TelemetryDeckTests {
  private func summary(
    kind: LatencyMeasuredEvent.Kind = .wakeToAck,
    p50: Double = 120,
    p95: Double = 480,
    p99: Double = 620,
    mock: Bool = false,
    breaches: Int = 1
  ) -> LatencyPercentileSummary {
    LatencyPercentileSummary(
      kind: kind,
      sampleCount: 4,
      p50Milliseconds: p50,
      p95Milliseconds: p95,
      p99Milliseconds: p99,
      maxMilliseconds: 700,
      isMockDerived: mock,
      budgetBreaches: breaches)
  }

  @Test("summary refreshes append a bounded pull-cadence history")
  func historyIsBoundedAndKeepsPercentiles() {
    var history: [LatencyMeasuredEvent.Kind: [AuraLatencyHistoryPoint]] = [:]
    for index in 0...60 {
      history = AuraMenuView.appendingLatencyHistory(
        existing: history,
        summaries: [summary(p95: Double(index))],
        measuredAt: Date(timeIntervalSince1970: Double(index)))
    }
    let points = history[.wakeToAck] ?? []
    #expect(points.count == 60)
    #expect(points.first?.p95Milliseconds == 1)
    #expect(points.last?.p95Milliseconds == 60)
    #expect(points.first?.measuredAt == Date(timeIntervalSince1970: 1))
  }

  @Test("gauge budgets match the declared latency event contracts")
  func gaugeBudgetMappingIsPinned() {
    #expect(AuraLatencyGauge.budgetForKind(.wakeToAck) == 500)
    #expect(AuraLatencyGauge.budgetForKind(.pushToTalkAck) == 500)
    #expect(AuraLatencyGauge.budgetForKind(.simpleCommandCompletion) == 1_500)
    #expect(AuraLatencyGauge.budgetForKind(.sttFirstPartial) == 1_000)
  }

  @Test("sparkline geometry is finite and normalized to its budget scale")
  func sparklineGeometryIsStable() {
    let maximum = AuraSparkline.scaleMaximum(values: [100, 500, 900], budget: 500)
    let points = AuraSparkline.points(values: [100, 500, 900], width: 300, height: 40, maximum: maximum)
    #expect(points.count == 3)
    #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    #expect(points.first?.x == 0)
    #expect(points.last?.x == 300)
    #expect(AuraSparkline.y(value: 0, height: 40, maximum: maximum) == 40)
  }

  @Test("status row and telemetry deck construct with mock provenance")
  @MainActor
  func newRecoveryComponentsConstruct() {
    let model = AuraAppModel(startRuntime: false)
    let menu = AuraMenuView(model: model)
    _ = menu.recoveryTab
    _ = AuraStatusRow(
      symbol: "checkmark.circle",
      title: "Runtime",
      detail: "Ready",
      state: "ready",
      tint: AuraDesign.Palette.biolume).body
    _ = AuraTelemetryDeck(
      summaries: [summary(mock: true)],
      history: [:],
      liveProvenance: "Observed latency",
      mockProvenance: "mock-derived",
      sampleLabel: "samples",
      emptyLabel: "No samples").body
  }
}
