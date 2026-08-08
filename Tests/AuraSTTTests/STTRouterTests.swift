import AuraAudio
import AuraCore
import AuraSTT
import Foundation
import Testing

@Suite("STT Router")
struct STTRouterTests {
  @Test func selectsTheFirstReadyLocalEngineAndAnnotatesResults() async throws {
    let unavailable = DeterministicMockSTTEngine(
      engineID: "native-tr",
      locale: Locale(identifier: "tr-TR"),
      script: [])
    let fallback = DeterministicMockSTTEngine(
      engineID: "native-en",
      locale: Locale(identifier: "en-US"),
      script: [
        .init(text: "run the tests", expectedFrameCount: 3)
      ])
    let router = STTRouter(candidates: [unavailable, fallback])

    let health = try await router.start()
    #expect(health.ready)
    #expect(health.engineID == "native-en")
    #expect(health.locale == "en-US")

    let stream = router.results
    let values = ResultCollector.collectUntilStable(stream)
    let resultTask = Task { await values.value }

    for index in 0..<3 {
      await router.ingest(
        AudioFrame(
          samples: [Float(index)], timestamp: Double(index), sequenceIndex: UInt64(index),
          isDiscontinuity: false),
        activationTime: 0)
    }
    await router.finalizeSession()

    let results = await resultTask.value
    #expect(results.contains { $0.isStable && $0.text == "run the tests" })
    #expect(results.allSatisfy { $0.metadata["routerEngineID"] == "stt-router" })
    #expect(results.allSatisfy { $0.metadata["selectedEngineID"] == "native-en" })

    await router.cancel()
    #expect(router.health().status == "cancelled")
  }

  @Test func resourceDenialFailsClosedBeforeStartingCandidates() async {
    let governor = VoiceResourceGovernor(
      configuration: VoiceResourceGovernorConfiguration(residentMemoryBudgetMB: 1))
    _ = await governor.reserve(.ttsNeural, estimatedMemoryMB: 1, priority: .speech)
    let candidate = DeterministicMockSTTEngine(
      engineID: "native-tr",
      locale: Locale(identifier: "tr-TR"),
      script: [.init(text: "merhaba", expectedFrameCount: 1)])
    let router = STTRouter(candidates: [candidate], governor: governor, reservationMB: 1)

    await #expect(throws: (any Error).self) {
      _ = try await router.start()
    }
    #expect(router.health().status == "resource-denied")
    #expect(!candidate.health().ready)
  }
}

private enum ResultCollector {
  static func collectUntilStable(
    _ stream: AsyncStream<STTTranscriptResult>
  ) -> Task<[STTTranscriptResult], Never> {
    Task {
      var values: [STTTranscriptResult] = []
      for await value in stream {
        values.append(value)
        if value.isStable { break }
      }
      return values
    }
  }
}
