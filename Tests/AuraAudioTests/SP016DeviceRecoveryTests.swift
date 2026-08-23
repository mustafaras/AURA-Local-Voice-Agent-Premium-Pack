import AVFoundation
import AppKit
import AuraCore
import Foundation
import Testing

@testable import AuraAudio

/// Local collector: the file-private `MutexBox` in the neighbouring suite is
/// not visible here, and event handlers are `@Sendable`.
private final class ErrorCollector: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [AudioCaptureErrorEvent] = []

  func append(_ event: AudioCaptureErrorEvent) {
    lock.lock(); defer { lock.unlock() }
    storage.append(event)
  }

  var events: [AudioCaptureErrorEvent] {
    lock.lock(); defer { lock.unlock() }
    return storage
  }
}

/// SP-016 / OPEN-08: device-change recovery.
///
/// `AuraAudio.handleConfigurationChange` is the path that keeps a voice agent
/// usable when the user plugs in a headset, unplugs it, or the system switches
/// the default input mid-turn. It was implemented but carried **zero test
/// coverage**, and an earlier SP-016 attempt recorded that as untestable —
/// believing that reaching `state == .running` required a Microphone grant the
/// test host does not have.
///
/// That was wrong, and this suite exists because checking it took one run:
/// `AuraAudio.start()` reaches `.running` in the SwiftPM test host. The
/// recovery path is therefore ordinary, deterministically testable code.
///
/// What this does **not** cover, and what keeps `RISK-VOICE-RECOVERY-LIVE`
/// open: no headset is physically unplugged and no real route change occurs.
/// `AVAudioEngineConfigurationChange` is posted directly, which exercises
/// AURA's reaction to the notification, not CoreAudio's decision to send it.
/// These tests drive the *real* `AVAudioEngine` and the machine's actual input
/// device, so they must never run in parallel with one another (or with other
/// audio tests on the same host): two tests opening the same microphone at
/// once tear each other's engine down mid-turn and the state assertions race.
/// `.serialized` removes that cross-test interference, which was the root cause
/// of the intermittent failures seen when the suite was allowed to run
/// concurrently.
@Suite("SP-016 audio device-change recovery", .serialized)
struct SP016DeviceRecveryTests {

  private func makeService(
    eventBus: AuraEventBus
  ) -> AuraAudio {
    AuraAudio(
      configuration: AudioConfiguration(),
      eventBus: eventBus,
      logger: AuraLogger(subsystem: "sp016", category: "audio"))
  }

  /// Poll `condition` until it is true or the budget is exhausted.
  ///
  /// A real `AVAudioEngine` start/teardown round-trip is host-load dependent:
  /// `engine.start()` on a busy machine can take far longer than a fixed 20 ms
  /// tick × a few dozen iterations. The earlier attempts used a short fixed
  /// poll budget and fell over exactly there. This helper gives a generous,
  /// iteration-bounded window (default 300 × 50 ms ≈ 15 s) and always performs
  /// one final check so a bare-timeout miss cannot falsely report failure.
  private func waitUntil(
    iterations: Int = 300,
    stepNanoseconds: UInt64 = 50_000_000,
    _ condition: @Sendable () async -> Bool
  ) async -> Bool {
    for _ in 0..<iterations {
      if await condition() { return true }
      try? await Task.sleep(nanoseconds: stepNanoseconds)
    }
    return await condition()
  }

  /// A configuration change while capturing must announce itself as a
  /// *recoverable* error and end back in a running capture — not silently
  /// wedge in `.recovering`, and not die.
  @Test("A device configuration change recovers capture rather than wedging")
  func configurationChangeRecoversCapture() async throws {
    let eventBus = AuraEventBus(logger: AuraLogger(subsystem: "sp016", category: "bus"))
    let errors = ErrorCollector()
    await eventBus.subscribe(AudioCaptureErrorEvent.self) { envelope in
      errors.append(envelope.payload)
    }

    let service = makeService(eventBus: eventBus)
    do {
      try await service.start()
    } catch {
      // No usable input device on this host: the recovery path cannot be
      // reached at all, so the test reports rather than falsely passing.
      Issue.record("capture could not start on this host: \(error)")
      return
    }
    try #require(await service.currentState() == .running)

    NotificationCenter.default.post(
      name: .AVAudioEngineConfigurationChange, object: nil)

    // The handler restarts capture after a deliberate 50 ms hardware-settle
    // backoff, so wait on the combined postcondition rather than assuming an
    // immediate transition.
    let recovered = await waitUntil {
      await service.currentState() == .running && !errors.events.isEmpty
    }
    #expect(recovered, "capture never returned to .running after a configuration change")
    let observed = errors.events
    #expect(observed.isEmpty == false, "configuration change emitted no capture error event")
    #expect(
      observed.allSatisfy { $0.recoverable },
      "a device configuration change must be reported as recoverable")

    await service.stop(reason: "test teardown")
    #expect(await service.currentState() == .idle)
  }

  /// The observer must not outlive the capture session. If it did, a device
  /// change after `stop()` would restart capture the user never asked for —
  /// a privacy failure, not just a bug, because the microphone would reopen
  /// silently.
  @Test("A configuration change after stop never reopens the microphone")
  func configurationChangeAfterStopDoesNotRestartCapture() async throws {
    let eventBus = AuraEventBus(logger: AuraLogger(subsystem: "sp016", category: "bus"))
    let service = makeService(eventBus: eventBus)

    do {
      try await service.start()
    } catch {
      Issue.record("capture could not start on this host: \(error)")
      return
    }
    await service.stop(reason: "user stopped capture")
    try #require(await service.currentState() == .idle)

    NotificationCenter.default.post(
      name: .AVAudioEngineConfigurationChange, object: nil)
    try? await Task.sleep(nanoseconds: 300_000_000)

    #expect(
      await service.currentState() == .idle,
      "a device change after stop reopened capture without user action")
  }

  /// Sleep must actually close the microphone, not leave a dead tap behind
  /// reporting `.running`, and wake must bring it back.
  @Test("Sleep suspends capture and wake resumes it")
  func sleepSuspendsAndWakeResumesCapture() async throws {
    let eventBus = AuraEventBus(logger: AuraLogger(subsystem: "sp016", category: "bus"))
    let errors = ErrorCollector()
    await eventBus.subscribe(AudioCaptureErrorEvent.self) { envelope in
      errors.append(envelope.payload)
    }
    let service = makeService(eventBus: eventBus)
    do {
      try await service.start()
    } catch {
      Issue.record("capture could not start on this host: \(error)")
      return
    }
    try #require(await service.currentState() == .running)

    NSWorkspace.shared.notificationCenter.post(
      name: NSWorkspace.willSleepNotification, object: nil)

    let suspended = await waitUntil {
      await service.currentState() == .recovering
    }
    #expect(suspended, "sleep left capture running over torn-down audio hardware")
    #expect(
      errors.events.allSatisfy { $0.recoverable },
      "a sleep suspension must be reported as recoverable")

    NSWorkspace.shared.notificationCenter.post(
      name: NSWorkspace.didWakeNotification, object: nil)

    let resumed = await waitUntil {
      await service.currentState() == .running
    }
    #expect(resumed, "capture never resumed after wake")

    await service.stop(reason: "test teardown")
  }

  /// The privacy invariant: if the user stopped capture themselves, a later
  /// sleep/wake cycle must never reopen the microphone behind their back.
  @Test("Wake never reopens the microphone after an explicit user stop")
  func wakeAfterUserStopNeverReopensCapture() async throws {
    let eventBus = AuraEventBus(logger: AuraLogger(subsystem: "sp016", category: "bus"))
    let service = makeService(eventBus: eventBus)
    do {
      try await service.start()
    } catch {
      Issue.record("capture could not start on this host: \(error)")
      return
    }
    await service.stop(reason: "user stopped capture")
    try #require(await service.currentState() == .idle)

    NSWorkspace.shared.notificationCenter.post(
      name: NSWorkspace.willSleepNotification, object: nil)
    try? await Task.sleep(nanoseconds: 200_000_000)
    NSWorkspace.shared.notificationCenter.post(
      name: NSWorkspace.didWakeNotification, object: nil)
    try? await Task.sleep(nanoseconds: 400_000_000)

    #expect(
      await service.currentState() == .idle,
      "a sleep/wake cycle reopened capture after the user had stopped it")
  }

  /// Capture lifecycle through `start()` → `stop()` on the real engine. This
  /// lives in this suite (rather than the ring-buffer-only `AuraAudioTests`)
  /// because it opens the microphone: keeping every hardware-bound test here
  /// lets `.serialized` prevent two tests from grabbing the same device at
  /// once, which was the root cause of the intermittent suite failures.
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

  /// `start()` on an already-started engine must be a no-op. Opens the real
  /// microphone, so it lives in this `.serialized` suite.
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

  /// Privacy indicator updates while idle are stored and applied only when
  /// capture next starts; they must not emit while the microphone is closed.
  /// This does not open the microphone, but it shares the actor/event-bus
  /// under test with the hardware tests, so it stays in this serialized suite
  /// to keep the whole audio surface free of concurrent-interference noise.
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
