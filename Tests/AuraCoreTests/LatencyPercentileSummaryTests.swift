import Foundation
import Testing

@testable import AuraCore

/// R12 SLO readout (`ptt_ack`, `stt_partial`), added 2026-08-30.
///
/// `SystemHealthSnapshot` reported only a median and a worst case, which cannot
/// satisfy an SLO contract asking for p50/p95/p99. These pin the percentile
/// summary that replaced it, and — more importantly — the two honesty
/// properties: a kind with no samples must be *absent* rather than zero, and a
/// mock-derived summary must say so.
struct LatencyPercentileSummaryTests {
  private func sampler() -> PerformanceSampler { PerformanceSampler() }

  private func record(
    _ s: PerformanceSampler,
    _ kind: LatencyMeasuredEvent.Kind,
    _ seconds: [Double],
    mock: Bool = false,
    budget: Double = 10
  ) async {
    for value in seconds {
      await s.record(
        kind: kind, latencySeconds: value, budgetSeconds: budget,
        isMockEngine: mock, measuredAt: Date())
    }
  }

  @Test("a kind with no samples is omitted, never reported as zero")
  func absentKindsAreOmitted() async {
    let s = sampler()
    await record(s, .pushToTalkAck, [0.1])
    let summaries = await s.percentileSummaries()
    // The whole point: a zero p50 for an unmeasured kind would read as
    // "measured, and instant", which is how a not_measured SLO turns into a
    // fabricated one.
    #expect(summaries.count == 1)
    #expect(summaries.first?.kind == .pushToTalkAck)
    #expect(!summaries.contains { $0.kind == .sttFirstPartial })
  }

  @Test("percentiles are computed in milliseconds and ordered")
  func percentilesAreOrdered() async {
    let s = sampler()
    await record(s, .sttFirstPartial, (1...100).map { Double($0) / 1000.0 })
    guard let summary = await s.percentileSummaries().first else {
      Issue.record("no summary"); return
    }
    #expect(summary.sampleCount == 100)
    // 1...100 ms: p50 lands mid-range, p99 near the top, max exactly 100.
    #expect(summary.p50Milliseconds > 45 && summary.p50Milliseconds < 56)
    #expect(summary.p95Milliseconds > summary.p50Milliseconds)
    #expect(summary.p99Milliseconds >= summary.p95Milliseconds)
    #expect(abs(summary.maxMilliseconds - 100) < 0.001)
  }

  @Test("a mock-derived summary is labelled, and one real sample clears it")
  func mockDerivationIsHonest() async {
    let mockOnly = sampler()
    await record(mockOnly, .pushToTalkAck, [0.2, 0.3], mock: true)
    #expect(await mockOnly.percentileSummaries().first?.isMockDerived == true)

    let mixed = sampler()
    await record(mixed, .pushToTalkAck, [0.2], mock: true)
    await record(mixed, .pushToTalkAck, [0.3], mock: false)
    // `deterministic_harness` may never be presented as a live measurement, so
    // this flag must be false only when a genuinely non-mock sample exists.
    #expect(await mixed.percentileSummaries().first?.isMockDerived == false)
  }

  @Test("budget breaches are counted per kind")
  func budgetBreachesAreCounted() async {
    let s = sampler()
    await record(s, .pushToTalkAck, [0.1, 0.2, 5.0], budget: 0.5)
    #expect(await s.percentileSummaries().first?.budgetBreaches == 1)
  }

  @Test("ptt_ack and stt_partial are distinct kinds from wakeToAck")
  func sloKindsAreDistinct() {
    // wakeToAck fires when a response plan arrives — after NLU, policy and the
    // model round trip. Reporting it as ptt_ack would overstate the
    // acknowledgement by whole seconds. They must never be conflated.
    #expect(LatencyMeasuredEvent.Kind.pushToTalkAck != .wakeToAck)
    #expect(LatencyMeasuredEvent.Kind.sttFirstPartial != .wakeToAck)
    #expect(LatencyMeasuredEvent.Kind.allCases.contains(.pushToTalkAck))
    #expect(LatencyMeasuredEvent.Kind.allCases.contains(.sttFirstPartial))
  }

  @Test("summaries separate kinds rather than pooling them")
  func kindsAreSeparated() async {
    let s = sampler()
    await record(s, .pushToTalkAck, [0.010, 0.012])
    await record(s, .sttFirstPartial, [0.500, 0.600])
    let summaries = await s.percentileSummaries()
    #expect(summaries.count == 2)
    let ptt = summaries.first { $0.kind == .pushToTalkAck }
    let stt = summaries.first { $0.kind == .sttFirstPartial }
    #expect((ptt?.maxMilliseconds ?? 0) < 20)
    #expect((stt?.p50Milliseconds ?? 0) > 400)
  }
}
