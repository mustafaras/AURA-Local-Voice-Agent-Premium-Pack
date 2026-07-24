import Foundation

/// Hierarchical configuration with typed validation and default values.
///
/// Configuration is loaded from JSON, merged with defaults, and validated
/// before any subsystem consumes it. No secrets are stored here.
public struct AuraConfiguration: Codable, Sendable, Equatable {
    public var app: AppConfiguration
    public var audio: AudioConfiguration
    public var wake: WakeWordConfiguration
    public var stt: STTConfiguration
    public var privacy: PrivacyConfiguration
    public var log: LoggingConfiguration

    public init(
        app: AppConfiguration = AppConfiguration(),
        audio: AudioConfiguration = AudioConfiguration(),
        wake: WakeWordConfiguration = WakeWordConfiguration(),
        stt: STTConfiguration = STTConfiguration(),
        privacy: PrivacyConfiguration = PrivacyConfiguration(),
        log: LoggingConfiguration = LoggingConfiguration()
    ) {
        self.app = app
        self.audio = audio
        self.wake = wake
        self.stt = stt
        self.privacy = privacy
        self.log = log
    }

    /// Default configuration for bootstrap and tests.
    public static var `default`: AuraConfiguration { AuraConfiguration() }

    /// Load configuration from JSON data, merging with defaults.
    public static func load(from data: Data) throws(AuraError) -> AuraConfiguration {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let overrides = try decoder.decode(AuraConfiguration.self, from: data)
            return overrides.mergedWithDefaults()
        } catch {
            throw AuraError.invalidConfiguration(error.localizedDescription)
        }
    }

    /// Merge a partial configuration over the hard-coded defaults.
    public func mergedWithDefaults() -> AuraConfiguration {
        let defaultAudio = AudioConfiguration()
        _ = WakeWordConfiguration()
        return AuraConfiguration(
            app: AppConfiguration(
                bundleIdentifier: self.app.bundleIdentifier.isEmpty ? AppConfiguration().bundleIdentifier : self.app.bundleIdentifier,
                serviceName: self.app.serviceName.isEmpty ? AppConfiguration().serviceName : self.app.serviceName
            ),
            audio: AudioConfiguration(
                sampleRate: self.audio.sampleRate <= 0 ? defaultAudio.sampleRate : self.audio.sampleRate,
                channelCount: self.audio.channelCount <= 0 ? defaultAudio.channelCount : self.audio.channelCount,
                frameLength: self.audio.frameLength <= 0 ? defaultAudio.frameLength : self.audio.frameLength,
                ringBufferSeconds: self.audio.ringBufferSeconds <= 0 ? defaultAudio.ringBufferSeconds : self.audio.ringBufferSeconds,
                captureBufferSize: self.audio.captureBufferSize <= 0 ? defaultAudio.captureBufferSize : self.audio.captureBufferSize,
                enableEchoCancellation: self.audio.enableEchoCancellation || defaultAudio.enableEchoCancellation,
                enableAutomaticGainControl: self.audio.enableAutomaticGainControl || defaultAudio.enableAutomaticGainControl
            ),
            stt: STTConfiguration(
                engineID: self.stt.engineID.isEmpty ? STTConfiguration().engineID : self.stt.engineID,
                locale: self.stt.locale.isEmpty ? STTConfiguration().locale : self.stt.locale,
                partialBoundaryFrames: self.stt.partialBoundaryFrames <= 0 ? STTConfiguration().partialBoundaryFrames : self.stt.partialBoundaryFrames,
                stabilizationDelayFrames: self.stt.stabilizationDelayFrames <= 0 ? STTConfiguration().stabilizationDelayFrames : self.stt.stabilizationDelayFrames,
                enableCustomVocabulary: self.stt.enableCustomVocabulary || STTConfiguration().enableCustomVocabulary
            ),
            privacy: PrivacyConfiguration(
                ambientAudioRetentionSeconds: self.privacy.ambientAudioRetentionSeconds < 0
                    ? PrivacyConfiguration().ambientAudioRetentionSeconds
                    : self.privacy.ambientAudioRetentionSeconds,
                screenshotRetentionDays: self.privacy.screenshotRetentionDays < 0
                    ? PrivacyConfiguration().screenshotRetentionDays
                    : self.privacy.screenshotRetentionDays
            ),
            log: LoggingConfiguration(
                minimumLevel: self.log.minimumLevel.isEmpty ? LoggingConfiguration().minimumLevel : self.log.minimumLevel,
                destination: self.log.destination.isEmpty ? LoggingConfiguration().destination : self.log.destination
            )
        )
    }

    /// Validate the fully resolved configuration.
    public func validate() throws(AuraError) {
        try app.validate()
        try audio.validate()
        try wake.validate()
        try stt.validate()
        try privacy.validate()
        try log.validate()
    }
}

public struct AppConfiguration: Codable, Sendable, Equatable {
    public var bundleIdentifier: String
    public var serviceName: String

    public init(
        bundleIdentifier: String = "ai.aura.local",
        serviceName: String = "AuraCore"
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.serviceName = serviceName
    }

    public func validate() throws(AuraError) {
        guard !bundleIdentifier.isEmpty else {
            throw AuraError.invalidConfiguration("bundleIdentifier must not be empty")
        }
        guard !serviceName.isEmpty else {
            throw AuraError.invalidConfiguration("serviceName must not be empty")
        }
    }
}

/// Configuration for the real-time audio capture pipeline.
///
/// Defaults are chosen for a 16 kHz mono wake-word/STT input stream on macOS.
public struct AudioConfiguration: Codable, Sendable, Equatable {
    public var sampleRate: Double
    public var channelCount: UInt32
    public var frameLength: UInt32
    public var ringBufferSeconds: Double
    public var captureBufferSize: UInt32
    public var enableEchoCancellation: Bool
    public var enableAutomaticGainControl: Bool

    public init(
        sampleRate: Double = 16_000,
        channelCount: UInt32 = 1,
        frameLength: UInt32 = 512,
        ringBufferSeconds: Double = 5.0,
        captureBufferSize: UInt32 = 1024,
        enableEchoCancellation: Bool = true,
        enableAutomaticGainControl: Bool = true
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameLength = frameLength
        self.ringBufferSeconds = ringBufferSeconds
        self.captureBufferSize = captureBufferSize
        self.enableEchoCancellation = enableEchoCancellation
        self.enableAutomaticGainControl = enableAutomaticGainControl
    }

    public func validate() throws(AuraError) {
        guard sampleRate > 0 else {
            throw AuraError.invalidConfiguration("sampleRate must be positive")
        }
        guard channelCount > 0 else {
            throw AuraError.invalidConfiguration("channelCount must be positive")
        }
        guard frameLength > 0 else {
            throw AuraError.invalidConfiguration("frameLength must be positive")
        }
        guard ringBufferSeconds > 0 else {
            throw AuraError.invalidConfiguration("ringBufferSeconds must be positive")
        }
        guard captureBufferSize > 0 else {
            throw AuraError.invalidConfiguration("captureBufferSize must be positive")
        }
    }
}

/// Configuration for wake-word detection, voice activity detection, speaker
/// verification, and privacy-mode activation.
public struct STTConfiguration: Codable, Sendable, Equatable {
    /// Engine adapter to load (e.g. "native-speech", "mock-stt").
    public var engineID: String

    /// Primary locale for transcription, in BCP-47 form.
    public var locale: String

    /// Number of frames ingested before a partial result is emitted.
    public var partialBoundaryFrames: UInt32

    /// Additional frames required before a partial is promoted to stable.
    public var stabilizationDelayFrames: UInt32

    /// Whether to enable user vocabulary hints when supported by the engine.
    public var enableCustomVocabulary: Bool

    public init(
        engineID: String = "native-speech",
        locale: String = "tr-TR",
        partialBoundaryFrames: UInt32 = 3,
        stabilizationDelayFrames: UInt32 = 2,
        enableCustomVocabulary: Bool = true
    ) {
        self.engineID = engineID
        self.locale = locale
        self.partialBoundaryFrames = partialBoundaryFrames
        self.stabilizationDelayFrames = stabilizationDelayFrames
        self.enableCustomVocabulary = enableCustomVocabulary
    }

    public func validate() throws(AuraError) {
        guard !engineID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuraError.invalidConfiguration("stt engineID must not be empty")
        }
        guard !locale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuraError.invalidConfiguration("stt locale must not be empty")
        }
        guard partialBoundaryFrames > 0 else {
            throw AuraError.invalidConfiguration("stt partialBoundaryFrames must be positive")
        }
        guard stabilizationDelayFrames > 0 else {
            throw AuraError.invalidConfiguration("stt stabilizationDelayFrames must be positive")
        }
    }
}

public struct WakeWordConfiguration: Codable, Sendable, Equatable {
    /// Phrase to listen for (used by configurable detectors; may be ignored
    /// by model-based detectors that have a fixed trigger).
    public var phrase: String

    /// Voice-activity energy threshold in dBFS (negative). Values closer to
    /// zero are more sensitive; lower values are less sensitive.
    public var vadEnergyThresholdDB: Double

    /// Number of consecutive silent frames before VAD reports speech end.
    public var vadSilenceFrames: UInt32

    /// Minimum wake-word confidence in [0, 1].
    public var wakeConfidenceThreshold: Double

    /// Minimum time between accepted wake detections (seconds).
    public var wakeDebounceSeconds: Double

    /// Suppress assistant-generated wake phrase and other self-trigger sources.
    public var enableAntiTriggerProtection: Bool

    /// Whether to run optional speaker verification after a wake detection.
    public var speakerVerificationEnabled: Bool

    /// Speaker verification similarity threshold in [0, 1].
    public var speakerVerificationThreshold: Double

    /// Keyboard shortcut that enables privacy mode (e.g. "⇧⌘L"). Empty means
    /// no shortcut is configured and the menu-bar toggle is used instead.
    public var privacyModeKeyboardShortcut: String

    /// When true, listening in privacy mode is only armed by the keyboard
    /// shortcut rather than continuous wake-word detection.
    public var privacyModeRequiresKeyboardShortcut: Bool

    public init(
        phrase: String = "hey aura",
        vadEnergyThresholdDB: Double = -40.0,
        vadSilenceFrames: UInt32 = 20,
        wakeConfidenceThreshold: Double = 0.75,
        wakeDebounceSeconds: Double = 2.0,
        enableAntiTriggerProtection: Bool = true,
        speakerVerificationEnabled: Bool = false,
        speakerVerificationThreshold: Double = 0.80,
        privacyModeKeyboardShortcut: String = "⇧⌘L",
        privacyModeRequiresKeyboardShortcut: Bool = true
    ) {
        self.phrase = phrase
        self.vadEnergyThresholdDB = vadEnergyThresholdDB
        self.vadSilenceFrames = vadSilenceFrames
        self.wakeConfidenceThreshold = wakeConfidenceThreshold
        self.wakeDebounceSeconds = wakeDebounceSeconds
        self.enableAntiTriggerProtection = enableAntiTriggerProtection
        self.speakerVerificationEnabled = speakerVerificationEnabled
        self.speakerVerificationThreshold = speakerVerificationThreshold
        self.privacyModeKeyboardShortcut = privacyModeKeyboardShortcut
        self.privacyModeRequiresKeyboardShortcut = privacyModeRequiresKeyboardShortcut
    }

    public func validate() throws(AuraError) {
        guard !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuraError.invalidConfiguration("wake phrase must not be empty")
        }
        guard vadEnergyThresholdDB <= 0 else {
            throw AuraError.invalidConfiguration("vadEnergyThresholdDB must be negative or zero")
        }
        guard vadSilenceFrames > 0 else {
            throw AuraError.invalidConfiguration("vadSilenceFrames must be positive")
        }
        guard wakeConfidenceThreshold >= 0, wakeConfidenceThreshold <= 1 else {
            throw AuraError.invalidConfiguration("wakeConfidenceThreshold must be in [0, 1]")
        }
        guard wakeDebounceSeconds >= 0 else {
            throw AuraError.invalidConfiguration("wakeDebounceSeconds must be non-negative")
        }
        guard speakerVerificationThreshold >= 0, speakerVerificationThreshold <= 1 else {
            throw AuraError.invalidConfiguration("speakerVerificationThreshold must be in [0, 1]")
        }
    }
}

// `AVAudioFrameCount` is provided by AVFoundation; do not redefine it.

public struct PrivacyConfiguration: Codable, Sendable, Equatable {
    public var ambientAudioRetentionSeconds: Double
    public var screenshotRetentionDays: Int

    public init(
        ambientAudioRetentionSeconds: Double = 0,
        screenshotRetentionDays: Int = 7
    ) {
        self.ambientAudioRetentionSeconds = ambientAudioRetentionSeconds
        self.screenshotRetentionDays = screenshotRetentionDays
    }

    public func validate() throws(AuraError) {
        guard ambientAudioRetentionSeconds >= 0 else {
            throw AuraError.invalidConfiguration("ambientAudioRetentionSeconds must be non-negative")
        }
        guard screenshotRetentionDays >= 0 else {
            throw AuraError.invalidConfiguration("screenshotRetentionDays must be non-negative")
        }
    }
}

public struct LoggingConfiguration: Codable, Sendable, Equatable {
    public var minimumLevel: String
    public var destination: String

    public init(
        minimumLevel: String = "info",
        destination: String = "stderr"
    ) {
        self.minimumLevel = minimumLevel
        self.destination = destination
    }

    public func validate() throws(AuraError) {
        let validLevels = ["trace", "debug", "info", "warning", "error", "critical"]
        guard validLevels.contains(minimumLevel.lowercased()) else {
            throw AuraError.invalidConfiguration("minimumLevel must be one of \(validLevels)")
        }
        guard !destination.isEmpty else {
            throw AuraError.invalidConfiguration("destination must not be empty")
        }
    }
}
