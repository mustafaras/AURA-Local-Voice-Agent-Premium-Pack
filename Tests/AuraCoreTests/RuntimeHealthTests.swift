import AuraCore
import Foundation
import Testing

struct RuntimeHealthTests {
  @Test func snapshotIsSortedAndRetainsLatestState() async {
    let observedDate = Date(timeIntervalSince1970: 100)
    let registry = RuntimeHealthRegistry(now: { observedDate })

    await registry.record(componentID: "tts", status: .degraded, detail: "fallback")
    await registry.recordReady("audio", detail: "capture ready")
    await registry.recordReady("tts", detail: "system fallback ready")

    let snapshot = await registry.snapshot()
    #expect(snapshot.map(\.componentID) == ["audio", "tts"])
    #expect(await registry.health(for: "tts")?.status == .ready)
    #expect(await registry.health(for: "tts")?.detail == "system fallback ready")
    #expect(snapshot.last?.observedAt == observedDate)
  }

  @Test func failureAndPermissionStatesAreInspectable() async {
    let registry = RuntimeHealthRegistry(now: { Date(timeIntervalSince1970: 7) })
    await registry.recordFailure("ollama", detail: "service unavailable")
    await registry.record(
      componentID: "microphone",
      status: .permissionBlocked,
      detail: "user permission required")

    let snapshot = await registry.snapshot()
    #expect(snapshot.contains { $0.componentID == "ollama" && $0.status == .failed })
    #expect(
      snapshot.contains {
        $0.componentID == "microphone" && $0.status == .permissionBlocked
      })
  }

  private actor RuntimeHealthEventCapture {
    private(set) var health: [RuntimeHealth] = []

    func append(_ value: RuntimeHealth) {
      health.append(value)
    }
  }

  @Test func recordPublishesLiveHealthChanges() async {
    let eventBus = AuraEventBus(logger: AuraLogger(subsystem: "AuraCoreTests", category: "health"))
    let capture = RuntimeHealthEventCapture()
    await eventBus.subscribe(RuntimeHealthChangedEvent.self) { envelope in
      await capture.append(envelope.payload.health)
    }
    let registry = RuntimeHealthRegistry(
      now: { Date(timeIntervalSince1970: 11) }, eventBus: eventBus)

    await registry.record(componentID: "stt", status: .loading, detail: "starting")
    await registry.recordReady("stt", detail: "ready")

    #expect(await capture.health.map(\.status) == [.loading, .ready])
    #expect(await capture.health.last?.observedAt == Date(timeIntervalSince1970: 11))
  }
}
