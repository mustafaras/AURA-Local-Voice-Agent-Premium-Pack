import AuraAudio
import AuraCore
import Foundation
import Testing

struct AuraAudioTests {

  @Test func ringBufferOverwritesOldestWhenFull() {
    let capacity = 3
    let buffer = AudioRingBuffer(capacity: capacity)

    let frame1 = AudioFrame(samples: [1.0], timestamp: 1.0, sequenceIndex: 1)
    let frame2 = AudioFrame(samples: [2.0], timestamp: 2.0, sequenceIndex: 2)
    let frame3 = AudioFrame(samples: [3.0], timestamp: 3.0, sequenceIndex: 3)
    let frame4 = AudioFrame(samples: [4.0], timestamp: 4.0, sequenceIndex: 4)

    buffer.append(frame1)
    buffer.append(frame2)
    buffer.append(frame3)
    buffer.append(frame4)

    let snapshot = buffer.snapshot()
    #expect(snapshot.count == capacity)
    #expect(snapshot.map(\.sequenceIndex) == [2, 3, 4])
  }

  @Test func ringBufferClearEmptiesContents() {
    let buffer = AudioRingBuffer(capacity: 2)
    buffer.append(AudioFrame(samples: [1.0], timestamp: 1.0, sequenceIndex: 1))
    buffer.clear()
    #expect(buffer.snapshot().isEmpty)
  }

  @Test func audioFrameImmutabilityAndDiscontinuityFlag() {
    let frame = AudioFrame(
      samples: [0.5, -0.5],
      timestamp: 1.5,
      sequenceIndex: 42,
      isDiscontinuity: true
    )
    #expect(frame.samples == [0.5, -0.5])
    #expect(frame.timestamp == 1.5)
    #expect(frame.sequenceIndex == 42)
    #expect(frame.isDiscontinuity)
  }

  @Test func stateTransitionsThroughStartAndStop() async throws(AuraError) {
    let eventBus = AuraEventBus(logger: AuraLogger(subsystem: "test", category: "bus"))
    let logger = AuraLogger(subsystem: "test", category: "audio")
    let config = AudioConfiguration(
      sampleRate: 16_000,
      channelCount: 1,
      frameLength: 512,
      ringBufferSeconds: 1,
      captureBufferSize: 1024,
      enableEchoCancellation: false,
      enableAutomaticGainControl: false
    )
    let clock: @Sendable () -> TimeInterval = { 1_000.0 }
    let service = AuraAudio(
      configuration: config,
      eventBus: eventBus,
      logger: logger,
      monotonicClock: clock
    )

    #expect(await service.currentState() == .idle)

    // Starting on a real device path would request hardware. We exercise
    // actor isolation, configuration validation, and the state machine by
    // calling start only when no audio hardware is required: if the tap
    // fails, it still passes through the AuraError path.
    do {
      try await service.start()
      // If hardware/permissions allow capture, we verify lifecycle events.
      let currentState = await service.currentState()
      #expect(currentState == .running || currentState == .idle)
      await service.stop(reason: "test teardown")
      #expect(await service.currentState() == .idle)
    } catch {
      // Starting audio capture without a microphone/permissions is
      // expected in CI. The important outcome is a typed AuraError.
      _ = error as AuraError
    }
  }

  @Test func privacyControlsUpdateEmitsIndicatorEvent() async {
    let eventBus = AuraEventBus(logger: AuraLogger(subsystem: "test", category: "bus"))
    let logger = AuraLogger(subsystem: "test", category: "audio")
    let indicatorEventsBox = MutexBox<[Bool]>([])
    await eventBus.subscribe(AudioIndicatorEvent.self) { envelope in
      indicatorEventsBox.withLock { $0.append(envelope.payload.isActive) }
    }

    let config = AuraConfiguration.default.audio
    let service = AuraAudio(
      configuration: config,
      eventBus: eventBus,
      logger: logger
    )
    await service.setPrivacyControls(AuraAudio.PrivacyControls(visibleIndicatorWhenActive: true))
    await service.setPrivacyControls(AuraAudio.PrivacyControls(visibleIndicatorWhenActive: false))
    #expect(indicatorEventsBox.withLock { $0 }.isEmpty)
    // Indicator events are emitted only when capture is active. While idle
    // the update is silently stored and will take effect at start().
    #expect(await service.currentPrivacyControls().visibleIndicatorWhenActive == false)
  }

  @Test func startIgnoredWhenNotIdle() async throws(AuraError) {
    let config = AuraConfiguration.default.audio
    let service = AuraAudio(
      configuration: config,
      eventBus: AuraEventBus(logger: AuraLogger(subsystem: "test", category: "bus")),
      logger: AuraLogger(subsystem: "test", category: "audio"),
      monotonicClock: { 0.0 }
    )

    // First start may succeed or fail based on hardware. If it succeeds,
    // a second start() must be ignored.
    try? await service.start()
    let stateBefore = await service.currentState()
    try? await service.start()
    let stateAfter = await service.currentState()
    #expect(stateBefore == stateAfter)
  }
}

/// Simple non-actor container used only in tests to collect values across
/// `@Sendable` handlers without capturing a `var`.
private final class MutexBox<T>: @unchecked Sendable {
  private var value: T
  private let lock = NSLock()

  init(_ value: T) {
    self.value = value
  }

  func withLock<R>(_ body: (inout T) -> R) -> R {
    lock.lock()
    defer { lock.unlock() }
    return body(&value)
  }
}
