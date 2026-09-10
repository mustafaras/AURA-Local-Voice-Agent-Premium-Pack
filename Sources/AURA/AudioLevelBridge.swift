import AuraAudio
import AuraCore
import Foundation

/// Publishes a throttled, scalar microphone level for the conversation UI —
/// the listening-level bridge the Orb (UI-1) and the status surfaces (UI-2)
/// consume.
///
/// Design (ui-improvement-plan/01-conversation-experience.md §4.5, 13 §1.2):
///
/// - **Read-only subscriber.** The bridge subscribes to the existing
///   `AudioFrameEvent` stream and fetches the real samples through
///   `AuraAudio.frame(sequenceIndex:)` — the exact-lookup pattern
///   `AudioSampleBridge` established (the event deliberately carries no
///   sample data). Zero writes to the shared bus.
/// - **Scalar only.** Each fetched frame is reduced to one RMS→dBFS value —
///   computed exactly the way `VoiceActivityDetector.energyDB` computes it,
///   so the meter and the VAD agree on what one frame's loudness is — and
///   normalized to 0…1 for display. No sample leaves the audio layer; no
///   ring buffer of samples is held anywhere in the UI.
/// - **Honest idle.** `inputLevel` is `nil` whenever the assistant is not
///   listening. The model drives `setListening(_:)` from the same status
///   transitions the status pill renders, and a capture-stopped event nils
///   the meter immediately even if a status event is late. The meter never
///   freezes on a stale level.
/// - **Privacy posture.** In-session only, no persistence, no logging
///   (06-cross-cutting-constraints.md §6) — mirroring the zero-retention
///   defaults the audio events already follow.
/// - **Throttle.** Events arrive at the capture frame rate; the UI needs a
///   display rate. `levelRefreshInterval` caps publishes at 20 Hz (inside
///   the 15–30 Hz budget) so the level stream stays a transform-only
///   rendering path (11-motion-system.md §5: never `withAnimation` on the
///   level).
@MainActor
final class AudioLevelBridge: ObservableObject {
  /// UI refresh ceiling for the level stream: 20 Hz, inside the 15–30 Hz
  /// display budget.
  static let levelRefreshInterval: TimeInterval = 1.0 / 20.0

  /// dBFS normalization window for display. The floor is the quietest level
  /// worth rendering; VAD clamps its own noise floor at −80 dB, but a display
  /// meter reads meaningful energy only well above that.
  static let levelFloorDB: Double = -60.0
  /// Full-scale ceiling.
  static let levelCeilDB: Double = 0.0

  /// Scalar loudness for display, 0…1 while listening; `nil` when the
  /// assistant is not listening. No sample data, no history, no persistence.
  @Published private(set) var inputLevel: Double?

  /// Sink the composition root sets to mirror the level into the app model's
  /// own published `inputLevel`, so every surface reads one value. Called on
  /// the main actor for every publish, including the `nil` reset.
  var onLevelChange: ((Double?) -> Void)?

  private var audio: AuraAudio
  private var eventBus: AuraEventBus
  private var subscribed = false
  private var isListening = false
  private var lastPublishAt: TimeInterval?
  private var lastHandledSequenceIndex: UInt64?
  private let clock: () -> TimeInterval

  /// - Parameters:
  ///   - audio: The capture service whose ring buffer holds the real frames.
  ///   - eventBus: The shared bus to observe `AudioFrameEvent` on.
  ///   - clock: Monotonic time source for the throttle; injectable so tests
  ///     pin the cadence deterministically.
  init(
    audio: AuraAudio, eventBus: AuraEventBus,
    clock: @escaping () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }
  ) {
    self.audio = audio
    self.eventBus = eventBus
    self.clock = clock
  }

  /// Re-point the bridge at the kernel's real capture actor and bus during
  /// `bootstrap()` (the model constructs the bridge before the kernel exists).
  /// Idempotent before `start()`; must not be called after subscription — the
  /// runtime calls this exactly once, before `start()`.
  func reattach(audio: AuraAudio, eventBus: AuraEventBus) async {
    guard !subscribed else { return }
    self.audio = audio
    self.eventBus = eventBus
  }

  // No explicit unsubscribe: `AuraEventBus` exposes no handler-removal API,
  // and adding one is outside this phase's file scope. Exactly like
  // `AudioSampleBridge.stop()`, teardown is the weak-self contract — the
  // subscription closure holds `[weak self]`, so delivery becomes a no-op the
  // moment this bridge deallocates.

  /// Subscribe to `AudioFrameEvent` (and capture-stopped, for the honest
  /// reset). Idempotent; safe to call after capture has already started — a
  /// UI meter joining mid-session legitimately misses only the frames before
  /// it subscribed, and the next frame arrives within one capture interval.
  func start() async {
    guard !subscribed else { return }
    subscribed = true
    await eventBus.subscribe(AudioFrameEvent.self) { [weak self] envelope in
      await self?.handle(envelope.payload)
    }
    await eventBus.subscribe(AudioCaptureStoppedEvent.self) { [weak self] _ in
      await self?.handleCaptureStopped()
    }
  }

  /// Mark whether the assistant is actually listening. Any transition to not-
  /// listening publishes `nil` immediately — the honest idle state — and
  /// later frame events are ignored until listening resumes.
  func setListening(_ active: Bool) {
    guard isListening != active else { return }
    isListening = active
    if !active {
      publish(level: nil, at: clock())
    }
  }

  /// Pure throttle decision, extracted for deterministic tests: the first
  /// event publishes immediately; later ones only once `interval` has elapsed
  /// since the last publish.
  static func shouldPublish(
    now: TimeInterval, lastPublishAt: TimeInterval?, interval: TimeInterval
  ) -> Bool {
    guard let lastPublishAt else { return true }
    return now - lastPublishAt >= interval
  }

  /// RMS→dBFS, computed exactly as `VoiceActivityDetector.energyDB` computes
  /// it, so the meter and the VAD cannot disagree about one frame's energy.
  static func energyDB(of samples: [Float]) -> Double {
    guard !samples.isEmpty else { return -120.0 }
    var sum: Float = 0
    for sample in samples {
      sum += sample * sample
    }
    let mean = sum / Float(samples.count)
    guard mean > 0 else { return -120.0 }
    return 10.0 * log10(Double(mean))
  }

  /// Normalize a dBFS reading into 0…1 over the display window, clamping
  /// silence and full scale into the range ends.
  static func normalizedLevel(fromEnergyDB db: Double) -> Double {
    let clamped = min(max(db, levelFloorDB), levelCeilDB)
    return (clamped - levelFloorDB) / (levelCeilDB - levelFloorDB)
  }

  private func handle(_ event: AudioFrameEvent) async {
    guard isListening else { return }
    // Exact sequence match, mirroring AudioSampleBridge: a stale or repeated
    // event must not re-read an older frame.
    guard event.sequenceIndex != lastHandledSequenceIndex else { return }
    // Throttle first: the fetch below hops to the audio actor, and skipping
    // it for suppressed events keeps the meter free on the 15–30 Hz cadence.
    let now = clock()
    guard
      Self.shouldPublish(
        now: now, lastPublishAt: lastPublishAt, interval: Self.levelRefreshInterval)
    else { return }
    guard let frame = await audio.frame(sequenceIndex: event.sequenceIndex) else {
      return
    }
    lastHandledSequenceIndex = event.sequenceIndex
    publish(
      level: Self.normalizedLevel(fromEnergyDB: Self.energyDB(of: frame.samples)),
      at: now)
  }

  private func handleCaptureStopped() async {
    setListening(false)
  }

  private func publish(level: Double?, at now: TimeInterval) {
    lastPublishAt = now
    inputLevel = level
    onLevelChange?(level)
  }
}