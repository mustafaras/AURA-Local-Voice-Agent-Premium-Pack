import AVFoundation
import AuraCore
import Foundation

/// Owns a callback-local PCM copy while it crosses into `AuraAudio` actor
/// isolation. The buffer is immutable after construction and consumed only by
/// the actor.
final class CapturedPCMBuffer: @unchecked Sendable {
  let value: AVAudioPCMBuffer

  init(_ value: AVAudioPCMBuffer) {
    self.value = value
  }
}

/// A synchronous `NotificationCenter` observer token. `NSObjectProtocol` is
/// not `Sendable`, so it is wrapped for storage inside the actor. The token is
/// only ever touched on the actor, so this is isolated in practice.
typealias ObserverToken = NSObjectProtocol

/// Real-time audio capture service for AURA.
///
/// Responsibilities:
/// - Configure and start/stop an `AVAudioEngine` input node capture tap.
/// - Convert raw PCM to mono float at the configured sample rate.
/// - Maintain a bounded ring buffer for short-term audio context.
/// - Emit typed lifecycle, frame, error, and privacy-indicator events.
/// - Recover safely from `AVAudioEngineConfigurationChange` notifications.
///
/// The service is an actor; all public entry points are isolated. The tap callback
/// runs on a realtime AVFoundation queue and must therefore perform no blocking,
/// allocation-heavy, or model work. It copies samples into a pre-allocated buffer
/// and immediately returns.
public actor AuraAudio {
  /// Current capture state.
  public enum State: String, Sendable, Equatable, CaseIterable {
    case idle
    case starting
    case running
    case stopping
    case recovering
  }

  /// Diagnostic capture policy. Defaults are privacy-first: no retention,
  /// no encryption expectation at rest, and the indicator is off when not
  /// actively capturing.
  public struct PrivacyControls: Sendable, Equatable {
    public var enableDiagnosticCapture: Bool
    public var diagnosticRetentionHours: UInt
    public var encryptDiagnostics: Bool
    public var visibleIndicatorWhenActive: Bool

    public init(
      enableDiagnosticCapture: Bool = false,
      diagnosticRetentionHours: UInt = 24,
      encryptDiagnostics: Bool = true,
      visibleIndicatorWhenActive: Bool = true
    ) {
      self.enableDiagnosticCapture = enableDiagnosticCapture
      self.diagnosticRetentionHours = diagnosticRetentionHours
      self.encryptDiagnostics = encryptDiagnostics
      self.visibleIndicatorWhenActive = visibleIndicatorWhenActive
    }
  }

  let configuration: AudioConfiguration
  let eventBus: AuraEventBus
  let logger: AuraLogger
  let ringBuffer: AudioRingBuffer
  var privacyControls: PrivacyControls

  var engine: AVAudioEngine?
  var state: State = .idle
  var sequenceIndex: UInt64 = 0
  var totalFrames: UInt64 = 0
  var lastTapTimestamp: TimeInterval = 0
  /// Synchronous `NotificationCenter` observers registered in `start()`.
  ///
  /// These replace the earlier `Task { for await ... }` subscription pattern,
  /// which had an async-registration race: `start()` could return before the
  /// `for await` loop was actually subscribed, so a notification posted
  /// immediately afterwards was dropped forever and the recovery path never
  /// ran. `NotificationCenter.addObserver` is synchronous — once `start()`
  /// returns, the observers are guaranteed registered, so every posted
  /// notification deterministically reaches the handler.
  var configurationChangeObserver: ObserverToken?
  var sleepObserver: ObserverToken?
  var wakeObserver: ObserverToken?
  /// Set only when the system put the machine to sleep while capture was
  /// running. It is the sole authority for resuming on wake, so an explicit
  /// user stop can never be undone by a later wake notification.
  var shouldResumeAfterWake: Bool = false
  var captureCorrelationID: UUID?

  /// Monotonic clock source for tests and frame timestamps.
  let monotonicClock: () -> TimeInterval

  /// Create a new audio service.
  ///
  /// - Parameters:
  ///   - configuration: Audio capture settings.
  ///   - eventBus: Bus for audio events.
  ///   - logger: Privacy-aware logger.
  ///   - ringBuffer: Optional external ring buffer; if nil, one is created from
  ///     `configuration.ringBufferSeconds` and `configuration.frameLength`.
  ///   - privacyControls: Diagnostic capture and indicator policy.
  ///   - monotonicClock: Injectible clock; defaults to `CFAbsoluteTimeGetCurrent`.
  public init(
    configuration: AudioConfiguration,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    ringBuffer: AudioRingBuffer? = nil,
    privacyControls: PrivacyControls = PrivacyControls(),
    monotonicClock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }
  ) {
    self.configuration = configuration
    self.eventBus = eventBus
    self.logger = logger
    if let ringBuffer = ringBuffer {
      self.ringBuffer = ringBuffer
    } else {
      let capacity = Int(
        max(
          1,
          (configuration.ringBufferSeconds * Double(configuration.sampleRate))
            / Double(configuration.frameLength)
        )
      )
      self.ringBuffer = AudioRingBuffer(capacity: capacity)
    }
    self.privacyControls = privacyControls
    self.monotonicClock = monotonicClock
  }

}
