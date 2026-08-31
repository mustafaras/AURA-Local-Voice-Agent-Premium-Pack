import AuraCore
import Foundation
import Testing

@testable import AURA

/// R12 `ptt_ack` sample hygiene, added 2026-08-31.
///
/// The instrumentation added on 2026-08-30 started its clock at the button
/// press and recorded on every path that reached the listening
/// acknowledgement. Its comment claimed a permission prompt was excluded, but
/// only *denial* returned early — a user who **granted** access fell through
/// and had the modal dialog's human reaction time, plus one-time speech-engine
/// startup, recorded as machine latency. With `ptt_ack` holding zero samples,
/// that would have been the first sample ever taken.
///
/// These pin the exclusion so it cannot regress back into control flow.
@Suite("R12 ptt_ack sample eligibility")
struct PushToTalkAckSampleTests {
  private let second: UInt64 = 1_000_000_000

  private func sample(elapsedNanoseconds: UInt64, prompted: Bool) -> Double? {
    // A fixed, non-zero base: `DispatchTime` is an uptime clock, so a real
    // press never starts at 0 and the arithmetic must not assume it does.
    let base: UInt64 = 42 * second
    return AuraAppModel.pushToTalkAckSample(
      pressedAt: DispatchTime(uptimeNanoseconds: base),
      acknowledgedAt: DispatchTime(uptimeNanoseconds: base + elapsedNanoseconds),
      promptedForPermissions: prompted)
  }

  @Test("a turn that raised the permission prompt is not a sample")
  func promptedTurnIsExcluded() {
    // 8 s is a plausible human reaction to a modal TCC dialog. Recording it
    // would put the p99 of an early sample set orders of magnitude above the
    // 0.5 s reporting reference.
    #expect(sample(elapsedNanoseconds: 8 * second, prompted: true) == nil)
  }

  @Test("an ordinary turn is a sample, reported in seconds")
  func ordinaryTurnIsMeasured() throws {
    let elapsed = try #require(sample(elapsedNanoseconds: second / 4, prompted: false))
    #expect(abs(elapsed - 0.25) < 0.000_001)
  }

  @Test("exclusion depends on the prompt, not on how fast the turn was")
  func fastPromptedTurnIsStillExcluded() {
    // Guards the tempting "just filter out the slow samples" fix: a prompt
    // answered instantly is still not a machine-latency sample, because the
    // window also contains one-time speech-engine startup.
    #expect(sample(elapsedNanoseconds: second / 100, prompted: true) == nil)
    #expect(sample(elapsedNanoseconds: 30 * second, prompted: false) != nil)
  }

  @Test("ptt_ack is a distinct kind and is never conflated with wakeToAck")
  func kindIsNotConflatedWithWake() {
    // `wakeToAck` fires when a response plan arrives — after NLU, policy
    // evaluation and a model round trip — so it overstates the acknowledgement
    // by whole seconds and must never be substituted for this metric.
    #expect(LatencyMeasuredEvent.Kind.pushToTalkAck != .wakeToAck)
    #expect(LatencyMeasuredEvent.Kind.sttFirstPartial != .pushToTalkAck)
  }
}
