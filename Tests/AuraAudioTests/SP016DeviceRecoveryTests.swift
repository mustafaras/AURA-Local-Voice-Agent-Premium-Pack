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
@Suite("SP-016 audio device-change recovery")
struct SP016DeviceRecoveryTests {

  private func makeService(
    eventBus: AuraEventBus
  ) -> AuraAudio {
    AuraAudio(
      configuration: AudioConfiguration(),
      eventBus: eventBus,
      logger: AuraLogger(subsystem: "sp016", category: "audio"))
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
    // backoff, so poll rather than assuming an immediate transition.
    var recovered = false
    for _ in 0..<100 {
      try? await Task.sleep(nanoseconds: 20_000_000)
      if await service.currentState() == .running, !errors.events.isEmpty {
        recovered = true
        break
      }
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

    var suspended = false
    for _ in 0..<100 {
      try? await Task.sleep(nanoseconds: 20_000_000)
      if await service.currentState() == .recovering { suspended = true; break }
    }
    #expect(suspended, "sleep left capture running over torn-down audio hardware")
    #expect(
      errors.events.allSatisfy { $0.recoverable },
      "a sleep suspension must be reported as recoverable")

    NSWorkspace.shared.notificationCenter.post(
      name: NSWorkspace.didWakeNotification, object: nil)

    var resumed = false
    for _ in 0..<150 {
      try? await Task.sleep(nanoseconds: 20_000_000)
      if await service.currentState() == .running { resumed = true; break }
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
}
