import Foundation

// MARK: - STT shared result type

/// A single alternative transcript with its confidence.
/// Lives in AuraCore so that cross-target events can carry alternatives
/// without creating an import cycle with AuraSTT.
public struct STTAlternative: Codable, Sendable, Equatable {
  public let text: String
  public let confidence: Double

  public init(text: String, confidence: Double) {
    self.text = text
    self.confidence = confidence
  }
}

// MARK: - Audio capture event payloads

/// Emitted when the audio service has started capturing.
public struct AudioCaptureStartedEvent: EventPayload {
  public static let eventType = "audio.capture.started"

  public let deviceID: String?
  public let sampleRate: Double
  public let channelCount: UInt32

  public init(deviceID: String?, sampleRate: Double, channelCount: UInt32) {
    self.deviceID = deviceID
    self.sampleRate = sampleRate
    self.channelCount = channelCount
  }
}

/// Emitted for each captured frame after format conversion.
public struct AudioFrameEvent: EventPayload {
  public static let eventType = "audio.frame"

  /// Number of samples in the frame.
  public let sampleCount: Int

  /// Host monotonic timestamp of the first sample (seconds).
  public let timestamp: TimeInterval

  /// Sequence index of the frame since capture started.
  public let sequenceIndex: UInt64

  /// True if a discontinuity was detected before this frame.
  public let isDiscontinuity: Bool

  public init(
    sampleCount: Int,
    timestamp: TimeInterval,
    sequenceIndex: UInt64,
    isDiscontinuity: Bool = false
  ) {
    self.sampleCount = sampleCount
    self.timestamp = timestamp
    self.sequenceIndex = sequenceIndex
    self.isDiscontinuity = isDiscontinuity
  }
}

/// Emitted when the audio service stops capturing.
public struct AudioCaptureStoppedEvent: EventPayload {
  public static let eventType = "audio.capture.stopped"

  public let reason: String
  public let totalFrames: UInt64

  public init(reason: String, totalFrames: UInt64) {
    self.reason = reason
    self.totalFrames = totalFrames
  }
}

/// Emitted when a capture or device error occurs.
public struct AudioCaptureErrorEvent: EventPayload {
  public static let eventType = "audio.capture.error"

  public let errorMessage: String
  public let recoverable: Bool

  public init(errorMessage: String, recoverable: Bool) {
    self.errorMessage = errorMessage
    self.recoverable = recoverable
  }
}

/// Emitted when the privacy-visible indicator state changes.
public struct AudioIndicatorEvent: EventPayload {
  public static let eventType = "audio.indicator"

  public let isActive: Bool

  public init(isActive: Bool) {
    self.isActive = isActive
  }
}

// MARK: - Wake word / VAD event payloads

/// Emitted when voice activity is detected or has ended.
public struct VoiceActivityEvent: EventPayload {
  public static let eventType = "audio.vad.activity"

  /// True when speech begins, false when the configured silence budget expires.
  public let isActive: Bool

  /// Estimated signal energy in dBFS.
  public let energyDB: Double

  /// Number of frames that contributed to the decision.
  public let frameCount: UInt64

  public init(isActive: Bool, energyDB: Double, frameCount: UInt64) {
    self.isActive = isActive
    self.energyDB = energyDB
    self.frameCount = frameCount
  }
}

/// Emitted when a wake-word detector hypothesizes a detection.
public struct WakeWordHypothesisEvent: EventPayload {
  public static let eventType = "audio.wake.hypothesis"

  /// Detector-assigned confidence in [0, 1].
  public let confidence: Double

  /// Phrase that was matched (may differ from configured phrase for model-based detectors).
  public let matchedPhrase: String

  /// True if the detector flagged the hypothesis as self-triggered and suppressed.
  public let suppressedAsAntiTrigger: Bool

  public init(confidence: Double, matchedPhrase: String, suppressedAsAntiTrigger: Bool) {
    self.confidence = confidence
    self.matchedPhrase = matchedPhrase
    self.suppressedAsAntiTrigger = suppressedAsAntiTrigger
  }
}

/// Emitted when a wake-word detection passes thresholds and debounce.
public struct WakeWordDetectedEvent: EventPayload {
  public static let eventType = "audio.wake.detected"

  public let confidence: Double
  public let matchedPhrase: String
  public let preRollFrames: UInt64

  public init(confidence: Double, matchedPhrase: String, preRollFrames: UInt64) {
    self.confidence = confidence
    self.matchedPhrase = matchedPhrase
    self.preRollFrames = preRollFrames
  }
}

/// Emitted when a speaker verification profile is enrolled or updated.
public struct SpeakerEnrollmentEvent: EventPayload {
  public static let eventType = "audio.speaker.enrollment"

  public let profileID: String
  public let samplesEnrolled: UInt32

  public init(profileID: String, samplesEnrolled: UInt32) {
    self.profileID = profileID
    self.samplesEnrolled = samplesEnrolled
  }
}

/// Emitted when speaker verification produces an identity hint after a wake.
public struct SpeakerVerificationEvent: EventPayload {
  public static let eventType = "audio.speaker.verified"

  public let profileID: String?
  public let score: Double
  public let isMatch: Bool

  public init(profileID: String?, score: Double, isMatch: Bool) {
    self.profileID = profileID
    self.score = score
    self.isMatch = isMatch
  }
}

/// Emitted when the system enters or leaves a listening activation.
public struct WakeActivationEvent: EventPayload {
  public static let eventType = "audio.wake.activation"

  public let isActive: Bool
  public let privacyMode: Bool
  public let turnContext: TurnContext?

  public init(
    isActive: Bool,
    privacyMode: Bool,
    turnContext: TurnContext? = nil
  ) {
    self.isActive = isActive
    self.privacyMode = privacyMode
    self.turnContext = turnContext
  }
}

/// Emitted when privacy mode toggles.
public struct PrivacyModeEvent: EventPayload {
  public static let eventType = "privacy.mode.changed"

  public let enabled: Bool
  public let triggeredByKeyboardShortcut: Bool

  public init(enabled: Bool, triggeredByKeyboardShortcut: Bool) {
    self.enabled = enabled
    self.triggeredByKeyboardShortcut = triggeredByKeyboardShortcut
  }
}

/// Emitted to report wake-word pipeline metrics (false accept/false reject
/// counters, etc.). May be emitted from a background actor and is purely
/// diagnostic.
public struct WakeWordMetricsEvent: EventPayload {
  public static let eventType = "audio.wake.metrics"

  public let falseAccepts: UInt64
  public let falseRejects: UInt64
  public let antiTriggerSuppressions: UInt64
  public let totalHypotheses: UInt64

  public init(
    falseAccepts: UInt64,
    falseRejects: UInt64,
    antiTriggerSuppressions: UInt64,
    totalHypotheses: UInt64
  ) {
    self.falseAccepts = falseAccepts
    self.falseRejects = falseRejects
    self.antiTriggerSuppressions = antiTriggerSuppressions
    self.totalHypotheses = totalHypotheses
  }
}

/// Emitted when the TTS subsystem begins speaking a prompt.
public struct TTSStartedEvent: EventPayload {
  public static let eventType = "tts.started"

  public let engineID: String
  public let promptID: String
  public let text: String

  public init(engineID: String, promptID: String, text: String) {
    self.engineID = engineID
    self.promptID = promptID
    self.text = text
  }
}

/// Emitted as a TTS engine streams audio or progress markers.
public struct TTSChunkEvent: EventPayload {
  public static let eventType = "tts.chunk"

  public let promptID: String
  public let chunk: TTSChunk

  public init(promptID: String, chunk: TTSChunk) {
    self.promptID = promptID
    self.chunk = chunk
  }
}

/// Emitted when the TTS subsystem stops a prompt early (interruption) or
/// finishes normally.
public struct TTSStoppedEvent: EventPayload {
  public static let eventType = "tts.stopped"

  public let promptID: String
  public let reason: TTSStopReason

  public init(promptID: String, reason: TTSStopReason) {
    self.promptID = promptID
    self.reason = reason
  }
}

/// Reason a TTS prompt stopped.
public enum TTSStopReason: String, Codable, Sendable, Equatable {
  case completed
  case interrupted
  case error
  case timeout
}

// MARK: - Conversation state payloads

/// Emitted whenever the conversation state machine changes state. Used by UI
/// for status display and by the orchestrator for coordination.
public struct ConversationStateEvent: EventPayload {
  public static let eventType = "conversation.state"

  public let state: ConversationState
  public let previousState: ConversationState?
  public let reason: String

  public init(
    state: ConversationState,
    previousState: ConversationState? = nil,
    reason: String = ""
  ) {
    self.state = state
    self.previousState = previousState
    self.reason = reason
  }
}

/// Discrete conversation states.
public enum ConversationState: String, Codable, Sendable, Equatable {
  case idle
  case listening
  case thinking
  case speaking
  case interrupted
  case timeout
  case error
}

/// Emitted when the user barge-in (new speech while the assistant is speaking)
/// is detected and accepted. The downstream coordinator must stop TTS.
public struct BargeInEvent: EventPayload {
  public static let eventType = "conversation.bargein"

  public let atState: ConversationState
  public let reason: String

  public init(atState: ConversationState, reason: String) {
    self.atState = atState
    self.reason = reason
  }
}

/// Emitted when a user turn completes semantically, either because speech
/// ended and the STT segment is stable, or because a deterministic command was
/// matched. The payload carries enough context for the intent engine to begin
/// planning.
public struct TurnCompletedEvent: EventPayload {
  public static let eventType = "conversation.turn.completed"

  public let text: String
  public let confidence: Double
  public let isFinal: Bool
  public let deterministicCommand: String?
  public let requiresPolicyReview: Bool
  public let turnContext: TurnContext?

  public init(
    text: String,
    confidence: Double,
    isFinal: Bool,
    deterministicCommand: String? = nil,
    requiresPolicyReview: Bool = true,
    turnContext: TurnContext? = nil
  ) {
    self.text = text
    self.confidence = confidence
    self.isFinal = isFinal
    self.deterministicCommand = deterministicCommand
    self.requiresPolicyReview = requiresPolicyReview
    self.turnContext = turnContext
  }
}

/// Emitted when the intent engine has produced a response plan and the TTS
/// queue is about to be scheduled. Carries a non-executable summary for UI.
public struct ResponsePlanEvent: EventPayload {
  public static let eventType = "conversation.response.plan"

  public let planID: String
  public let summary: String
  public let hasSpokenResponse: Bool

  /// True when the plan is the result of a local, no-remote-model intent
  /// (e.g. `appActivate`, `appTerminate`, or `shellExecute`). `Conversation`
  /// uses this flag to decide whether the current turn qualifies for the
  /// simple-command completion latency budget.
  public let isSimpleCommand: Bool
  public let language: DialogueLanguage?
  public let turnContext: TurnContext?

  public init(
    planID: String,
    summary: String,
    hasSpokenResponse: Bool,
    isSimpleCommand: Bool = false,
    language: DialogueLanguage? = nil,
    turnContext: TurnContext? = nil
  ) {
    self.planID = planID
    self.summary = summary
    self.hasSpokenResponse = hasSpokenResponse
    self.isSimpleCommand = isSimpleCommand
    self.language = language
    self.turnContext = turnContext
  }
}

/// Emitted when the conversation state machine detects that the user has gone
/// silent for too long while listening or that an engine has exceeded its budget.
public struct ConversationTimeoutEvent: EventPayload {
  public static let eventType = "conversation.timeout"

  public let stateAtTimeout: ConversationState
  public let timeoutKind: String

  public init(stateAtTimeout: ConversationState, timeoutKind: String) {
    self.stateAtTimeout = stateAtTimeout
    self.timeoutKind = timeoutKind
  }
}

// MARK: - Streaming STT event payloads

/// Emitted for each volatile partial transcript. Display-only; not authorized
/// for intent execution.
public struct STTPartialEvent: EventPayload {
  public static let eventType = "stt.partial"

  public let text: String
  public let confidence: Double
  public let turnContext: TurnContext?

  public init(text: String, confidence: Double, turnContext: TurnContext? = nil) {
    self.text = text
    self.confidence = confidence
    self.turnContext = turnContext
  }
}

/// Emitted when a transcript segment stabilizes and becomes available for
/// downstream intent processing (subject to policy authorization).
public struct STTStableSegmentEvent: EventPayload {
  public static let eventType = "stt.segment.stable"

  public let text: String
  public let alternatives: [STTAlternative]
  public let confidence: Double

  /// If the stable segment matched a deterministic early-command, this is
  /// the canonical command string. Nil otherwise.
  public let deterministicCommand: String?
  public let turnContext: TurnContext?

  public init(
    text: String,
    alternatives: [STTAlternative] = [],
    confidence: Double,
    deterministicCommand: String? = nil,
    turnContext: TurnContext? = nil
  ) {
    self.text = text
    self.alternatives = alternatives
    self.confidence = confidence
    self.deterministicCommand = deterministicCommand
    self.turnContext = turnContext
  }
}

/// Emitted when an STT session is cancelled.
public struct STTCancelledEvent: EventPayload {
  public static let eventType = "stt.cancelled"
  public let turnContext: TurnContext?

  public init(turnContext: TurnContext? = nil) {
    self.turnContext = turnContext
  }
}

/// Emitted when a latency-sensitive milestone is measured by the conversation
/// state machine. Both `wakeToAck` and `simpleCommandCompletion` are measured
/// from the accepted wake activation time so the numbers remain comparable.
public struct LatencyMeasuredEvent: EventPayload {
  public static let eventType = "performance.latency.measured"

  public enum Kind: String, Codable, Sendable, Equatable {
    /// Wake-word activation to first response-plan emission (acknowledgement).
    case wakeToAck

    /// Wake-word activation to end of spoken response for a deterministic
    /// command that needs no remote model.
    case simpleCommandCompletion
  }

  public let kind: Kind
  public let latencySeconds: Double
  public let budgetSeconds: Double
  public let isMockEngine: Bool
  public let measuredAt: Date
  public let turnID: UUID?
  public let sessionID: UUID?
  public let backendIDs: TurnBackendIDs?

  public init(
    kind: Kind,
    latencySeconds: Double,
    budgetSeconds: Double,
    isMockEngine: Bool? = nil,
    turnContext: TurnContext? = nil,
    measuredAt: Date = Date()
  ) {
    self.kind = kind
    self.latencySeconds = latencySeconds
    self.budgetSeconds = budgetSeconds
    self.isMockEngine = isMockEngine ?? turnContext?.backendIDs.usesMockBackend ?? false
    self.measuredAt = measuredAt
    self.turnID = turnContext?.turnID
    self.sessionID = turnContext?.sessionID
    self.backendIDs = turnContext?.backendIDs
  }
}

/// Emitted when the STT engine health changes or is polled.
public struct STTHealthEvent: EventPayload {
  public static let eventType = "stt.health"

  public let ready: Bool
  public let status: String
  public let detail: String
  public let turnContext: TurnContext?

  public init(
    ready: Bool,
    status: String,
    detail: String,
    turnContext: TurnContext? = nil
  ) {
    self.ready = ready
    self.status = status
    self.detail = detail
    self.turnContext = turnContext
  }
}
