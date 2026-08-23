import AuraCore
import Foundation
import Testing

@Suite("Voice Resource Governor")
struct VoiceResourceGovernorTests {
  @Test func rejectsReservationsThatExceedTheResidentBudget() async {
    let governor = VoiceResourceGovernor(
      configuration: VoiceResourceGovernorConfiguration(
        residentMemoryBudgetMB: 100,
        defaultReservationMB: 20))

    let first = await governor.reserve(
      .ttsNeural, estimatedMemoryMB: 80, priority: .speech)
    let second = await governor.reserve(
      .reasoning, estimatedMemoryMB: 30, priority: .interactive)

    #expect(first.granted)
    #expect(!second.granted)
    #expect(second.reason.contains("resident budget is full"))
    #expect(await governor.snapshot().reservedMemoryMB == 80)
  }

  @Test func criticalPressureKeepsSpeechCaptureAndFallbackAvailable() async {
    let governor = VoiceResourceGovernor()
    await governor.update(pressure: .critical)
    await governor.update(thermalState: .critical)

    let stt = await governor.reserve(.stt, estimatedMemoryMB: 10, priority: .speech)
    let tts = await governor.reserve(.ttsNeural, estimatedMemoryMB: 10, priority: .speech)
    let coding = await governor.reserve(.codingAgent, estimatedMemoryMB: 10, priority: .background)

    #expect(stt.granted)
    #expect(tts.granted)
    #expect(!coding.granted)
  }

  @Test func repeatedFailuresOpenAndResetTheCircuit() async {
    let governor = VoiceResourceGovernor(
      configuration: VoiceResourceGovernorConfiguration(circuitFailureLimit: 2))

    await governor.recordFailure(.ttsNeural)
    await governor.recordFailure(.ttsNeural)
    let blocked = await governor.reserve(.ttsNeural)
    #expect(!blocked.granted)
    #expect(blocked.reason.contains("circuit is open"))

    await governor.resetCircuit(.ttsNeural)
    let admitted = await governor.reserve(.ttsNeural)
    #expect(admitted.granted)
  }

  @Test func mapsPlatformThermalStatesToStablePublicStates() {
    #expect(VoiceResourceGovernor.map(.nominal) == .nominal)
    #expect(VoiceResourceGovernor.map(.fair) == .fair)
    #expect(VoiceResourceGovernor.map(.serious) == .serious)
    #expect(VoiceResourceGovernor.map(.critical) == .critical)
  }

  @Test func idleReservationsAreUnloadedAfterTheIdleWindow() async {
    let clock = Clock()
    let governor = VoiceResourceGovernor(
      configuration: VoiceResourceGovernorConfiguration(
        idleUnloadAfterSeconds: 10),
      now: { clock.value })

    _ = await governor.reserve(.ttsNeural, estimatedMemoryMB: 256, priority: .speech)
    #expect(await governor.snapshot().reservedMemoryMB == 256)

    // Advance the clock past the idle window and unload.
    clock.value = clock.value.addingTimeInterval(11)
    let unloaded = await governor.unloadIdleReservations()

    #expect(unloaded == [.ttsNeural])
    #expect(await governor.snapshot().reservedMemoryMB == 0)
  }

  @Test func recentReservationSurvivesIdleUnload() async {
    let clock = Clock()
    let governor = VoiceResourceGovernor(
      configuration: VoiceResourceGovernorConfiguration(
        idleUnloadAfterSeconds: 10),
      now: { clock.value })

    _ = await governor.reserve(.stt, estimatedMemoryMB: 256, priority: .speech)
    // Only 5 seconds have elapsed — inside the 10 s window.
    clock.value = clock.value.addingTimeInterval(5)
    let unloaded = await governor.unloadIdleReservations()

    #expect(unloaded.isEmpty)
    #expect(await governor.snapshot().reservedMemoryMB == 256)
  }

  @Test func reserveTouchesActivityClockSoLongRunningReservationIsNotUnloaded() async {
    let clock = Clock()
    let governor = VoiceResourceGovernor(
      configuration: VoiceResourceGovernorConfiguration(
        idleUnloadAfterSeconds: 10),
      now: { clock.value })

    _ = await governor.reserve(.reasoning, estimatedMemoryMB: 64, priority: .interactive)
    // Advance but re-reserve the same workload, which should refresh activity.
    clock.value = clock.value.addingTimeInterval(6)
    _ = await governor.reserve(.reasoning, estimatedMemoryMB: 64, priority: .interactive)
    clock.value = clock.value.addingTimeInterval(6)
    let unloaded = await governor.unloadIdleReservations()

    // 12s of wall time but only 6s since the last activity — survives.
    // The reservation is additive, so the total is 128 MB, still reserved.
    #expect(unloaded.isEmpty)
    #expect(await governor.snapshot().reservedMemoryMB == 128)
  }

  private final class Clock: @unchecked Sendable {
    var value = Date(timeIntervalSince1970: 1_700_000_000)
  }
}
