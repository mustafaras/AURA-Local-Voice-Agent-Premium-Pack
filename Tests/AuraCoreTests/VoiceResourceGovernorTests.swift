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
}
