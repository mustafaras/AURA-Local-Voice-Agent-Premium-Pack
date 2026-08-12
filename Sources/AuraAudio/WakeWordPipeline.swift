import AuraCore
import Foundation

/// Coordinates voice-activity detection, wake-word detection, optional speaker
/// verification, privacy mode, and anti-trigger suppression.
///
/// The pipeline consumes `AudioFrameEvent` from the event bus, never the raw
/// realtime tap. It is isolated on its own actor so that detector work does not
/// block audio capture.
public actor WakeWordPipeline {
  public enum State: String, Sendable, Equatable, CaseIterable {
    case idle
    case listening
    case privacyArmed
    case activated
    case speakerVerifying
  }

  public struct Metrics: Sendable, Equatable {
    public var falseAccepts: UInt64 = 0
    public var falseRejects: UInt64 = 0
    public var antiTriggerSuppressions: UInt64 = 0
    public var totalHypotheses: UInt64 = 0
    public var acceptedActivations: UInt64 = 0

    public init() {}
  }

  let configuration: WakeWordConfiguration
  let eventBus: AuraEventBus
  let logger: AuraLogger
  let vad: any VoiceActivityDetector
  let wakeDetector: any WakeWordDetector
  let speakerVerifier: (any SpeakerVerifier)?
  let sessionID: UUID

  var state: State = .idle
  var activeTurnContext: TurnContext?
  var privacyMode: Bool = false
  var privacyModeRequiresShortcut: Bool = true
  var lastAcceptedWakeTimestamp: TimeInterval = 0
  var isOutputActive: Bool = false
  var metrics: Metrics = Metrics()
  var subscriptionTask: Task<Void, Never>?
  var activationEndTask: Task<Void, Never>?
  let monotonicClock: () -> TimeInterval
  var retainedFrames: [UInt64: AudioFrame] = [:]

  /// Create a wake-word pipeline.
  ///
  /// - Parameters:
  ///   - configuration: Wake/VAD/speaker/privacy settings.
  ///   - eventBus: Bus to consume frame events from and emit pipeline events to.
  ///   - logger: Privacy-aware logger.
  ///   - vad: Voice-activity detector implementation.
  ///   - wakeDetector: Wake-word detector implementation.
  ///   - speakerVerifier: Optional speaker verifier; its output is treated as
  ///     an identity hint, not an authorization decision.
  ///   - monotonicClock: Injectible clock for tests.
  public init(
    configuration: WakeWordConfiguration,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    vad: any VoiceActivityDetector,
    wakeDetector: any WakeWordDetector,
    speakerVerifier: (any SpeakerVerifier)? = nil,
    monotonicClock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() },
    sessionID: UUID = UUID()
  ) {
    self.configuration = configuration
    self.eventBus = eventBus
    self.logger = logger
    self.vad = vad
    self.wakeDetector = wakeDetector
    self.speakerVerifier = speakerVerifier
    self.monotonicClock = monotonicClock
    self.sessionID = sessionID
    self.privacyModeRequiresShortcut = configuration.privacyModeRequiresKeyboardShortcut
  }

  deinit {
    subscriptionTask?.cancel()
    activationEndTask?.cancel()
  }
}
