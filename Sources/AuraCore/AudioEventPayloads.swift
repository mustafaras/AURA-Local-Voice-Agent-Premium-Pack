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

    public init(isActive: Bool, privacyMode: Bool) {
        self.isActive = isActive
        self.privacyMode = privacyMode
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

// MARK: - Streaming STT event payloads

/// Emitted for each volatile partial transcript. Display-only; not authorized
/// for intent execution.
public struct STTPartialEvent: EventPayload {
    public static let eventType = "stt.partial"

    public let text: String
    public let confidence: Double

    public init(text: String, confidence: Double) {
        self.text = text
        self.confidence = confidence
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

    public init(
        text: String,
        alternatives: [STTAlternative] = [],
        confidence: Double,
        deterministicCommand: String? = nil
    ) {
        self.text = text
        self.alternatives = alternatives
        self.confidence = confidence
        self.deterministicCommand = deterministicCommand
    }
}

/// Emitted when an STT session is cancelled.
public struct STTCancelledEvent: EventPayload {
    public static let eventType = "stt.cancelled"

    public init() {}
}

/// Emitted when the STT engine health changes or is polled.
public struct STTHealthEvent: EventPayload {
    public static let eventType = "stt.health"

    public let ready: Bool
    public let status: String
    public let detail: String

    public init(ready: Bool, status: String, detail: String) {
        self.ready = ready
        self.status = status
        self.detail = detail
    }
}
