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
  public var tts: TTSConfiguration
  public var conversation: ConversationConfiguration
  public var policy: PolicyConfiguration
  public var automation: AutomationConfiguration
  public var shell: ShellConfiguration
  public var vscode: VSCodeConfiguration
  public var privacy: PrivacyConfiguration
  public var log: LoggingConfiguration

  public init(
    app: AppConfiguration = AppConfiguration(),
    audio: AudioConfiguration = AudioConfiguration(),
    wake: WakeWordConfiguration = WakeWordConfiguration(),
    stt: STTConfiguration = STTConfiguration(),
    tts: TTSConfiguration = TTSConfiguration(),
    conversation: ConversationConfiguration = ConversationConfiguration(),
    policy: PolicyConfiguration = PolicyConfiguration(),
    automation: AutomationConfiguration = AutomationConfiguration(),
    shell: ShellConfiguration = ShellConfiguration(),
    vscode: VSCodeConfiguration = VSCodeConfiguration(),
    privacy: PrivacyConfiguration = PrivacyConfiguration(),
    log: LoggingConfiguration = LoggingConfiguration()
  ) {
    self.app = app
    self.audio = audio
    self.wake = wake
    self.stt = stt
    self.tts = tts
    self.conversation = conversation
    self.policy = policy
    self.automation = automation
    self.shell = shell
    self.vscode = vscode
    self.privacy = privacy
    self.log = log
  }

  /// Default configuration for bootstrap and tests.
  public static var `default`: AuraConfiguration { AuraConfiguration() }

  /// Alias used by tests that only need the base set of subsystems before
  /// Phase 4. It produces the same defaults as `default`.
  public static var defaultForPrePhase4: AuraConfiguration { AuraConfiguration() }

  /// Load configuration from JSON data, merging with defaults.
  ///
  /// The decoder tolerates missing keys by merging the decoded overrides
  /// over the hard-coded defaults; only explicitly provided fields replace
  /// defaults. Therefore decoding ignores missing keys and the entire
  /// structure can be partial.
  public static func load(from data: Data) throws(AuraError) -> AuraConfiguration {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    do {
      let overrides = try decoder.decode(AuraConfiguration.self, from: data)
      return overrides.mergedWithDefaults()
    } catch {
      throw AuraError.invalidConfiguration(error.localizedDescription)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    app = try container.decodeIfPresent(AppConfiguration.self, forKey: .app) ?? AppConfiguration()
    audio =
      try container.decodeIfPresent(AudioConfiguration.self, forKey: .audio) ?? AudioConfiguration()
    wake =
      try container.decodeIfPresent(WakeWordConfiguration.self, forKey: .wake)
      ?? WakeWordConfiguration()
    stt = try container.decodeIfPresent(STTConfiguration.self, forKey: .stt) ?? STTConfiguration()
    tts = try container.decodeIfPresent(TTSConfiguration.self, forKey: .tts) ?? TTSConfiguration()
    conversation =
      try container.decodeIfPresent(ConversationConfiguration.self, forKey: .conversation)
      ?? ConversationConfiguration()
    policy =
      try container.decodeIfPresent(PolicyConfiguration.self, forKey: .policy)
      ?? PolicyConfiguration()
    automation =
      try container.decodeIfPresent(AutomationConfiguration.self, forKey: .automation)
      ?? AutomationConfiguration()
    shell =
      try container.decodeIfPresent(ShellConfiguration.self, forKey: .shell)
      ?? ShellConfiguration()
    vscode =
      try container.decodeIfPresent(VSCodeConfiguration.self, forKey: .vscode)
      ?? VSCodeConfiguration()
    privacy =
      try container.decodeIfPresent(PrivacyConfiguration.self, forKey: .privacy)
      ?? PrivacyConfiguration()
    log =
      try container.decodeIfPresent(LoggingConfiguration.self, forKey: .log)
      ?? LoggingConfiguration()
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> AuraConfiguration {
    let defaultAudio = AudioConfiguration()
    _ = WakeWordConfiguration()
    return AuraConfiguration(
      app: AppConfiguration(
        bundleIdentifier: self.app.bundleIdentifier.isEmpty
          ? AppConfiguration().bundleIdentifier : self.app.bundleIdentifier,
        serviceName: self.app.serviceName.isEmpty
          ? AppConfiguration().serviceName : self.app.serviceName
      ),
      audio: AudioConfiguration(
        sampleRate: self.audio.sampleRate <= 0 ? defaultAudio.sampleRate : self.audio.sampleRate,
        channelCount: self.audio.channelCount <= 0
          ? defaultAudio.channelCount : self.audio.channelCount,
        frameLength: self.audio.frameLength <= 0
          ? defaultAudio.frameLength : self.audio.frameLength,
        ringBufferSeconds: self.audio.ringBufferSeconds <= 0
          ? defaultAudio.ringBufferSeconds : self.audio.ringBufferSeconds,
        captureBufferSize: self.audio.captureBufferSize <= 0
          ? defaultAudio.captureBufferSize : self.audio.captureBufferSize,
        enableEchoCancellation: self.audio.enableEchoCancellation
          || defaultAudio.enableEchoCancellation,
        enableAutomaticGainControl: self.audio.enableAutomaticGainControl
          || defaultAudio.enableAutomaticGainControl
      ),
      stt: STTConfiguration(
        engineID: self.stt.engineID.isEmpty ? STTConfiguration().engineID : self.stt.engineID,
        locale: self.stt.locale.isEmpty ? STTConfiguration().locale : self.stt.locale,
        partialBoundaryFrames: self.stt.partialBoundaryFrames <= 0
          ? STTConfiguration().partialBoundaryFrames : self.stt.partialBoundaryFrames,
        stabilizationDelayFrames: self.stt.stabilizationDelayFrames <= 0
          ? STTConfiguration().stabilizationDelayFrames : self.stt.stabilizationDelayFrames,
        enableCustomVocabulary: self.stt.enableCustomVocabulary
          || STTConfiguration().enableCustomVocabulary
      ),
      tts: TTSConfiguration(
        adapterChain: self.tts.adapterChain,
        defaultLocale: self.tts.defaultLocale.isEmpty
          ? TTSConfiguration().defaultLocale : self.tts.defaultLocale,
        defaultRate: self.tts.defaultRate <= 0
          ? TTSConfiguration().defaultRate : self.tts.defaultRate,
        enableBargeIn: self.tts.enableBargeIn,
        enableAntiTrigger: self.tts.enableAntiTrigger
      ),
      conversation: ConversationConfiguration(
        listenTimeoutSeconds: self.conversation.listenTimeoutSeconds <= 0
          ? ConversationConfiguration().listenTimeoutSeconds
          : self.conversation.listenTimeoutSeconds,
        thinkTimeoutSeconds: self.conversation.thinkTimeoutSeconds <= 0
          ? ConversationConfiguration().thinkTimeoutSeconds
          : self.conversation.thinkTimeoutSeconds,
        speechTimeoutSeconds: self.conversation.speechTimeoutSeconds <= 0
          ? ConversationConfiguration().speechTimeoutSeconds
          : self.conversation.speechTimeoutSeconds,
        bargeInGraceMilliseconds: self.conversation.bargeInGraceMilliseconds <= 0
          ? ConversationConfiguration().bargeInGraceMilliseconds
          : self.conversation.bargeInGraceMilliseconds,
        silenceEndFrames: self.conversation.silenceEndFrames <= 0
          ? ConversationConfiguration().silenceEndFrames
          : self.conversation.silenceEndFrames,
        deterministicStopCommands: self.conversation.deterministicStopCommands.isEmpty
          ? ConversationConfiguration().deterministicStopCommands
          : self.conversation.deterministicStopCommands,
        deterministicPauseResumeCommands: self.conversation.deterministicPauseResumeCommands.isEmpty
          ? ConversationConfiguration().deterministicPauseResumeCommands
          : self.conversation.deterministicPauseResumeCommands
      ),
      policy: self.policy.mergedWithDefaults(),
      automation: AutomationConfiguration(
        actionTimeoutSeconds: self.automation.actionTimeoutSeconds <= 0
          ? AutomationConfiguration().actionTimeoutSeconds
          : self.automation.actionTimeoutSeconds,
        observationTimeoutSeconds: self.automation.observationTimeoutSeconds <= 0
          ? AutomationConfiguration().observationTimeoutSeconds
          : self.automation.observationTimeoutSeconds,
        sensitiveBundleIdentifiers: self.automation.sensitiveBundleIdentifiers,
        allowedAutomationCapabilities: self.automation.allowedAutomationCapabilities
      ),
      shell: ShellConfiguration(
        defaultTimeoutSeconds: self.shell.defaultTimeoutSeconds <= 0
          ? ShellConfiguration().defaultTimeoutSeconds
          : self.shell.defaultTimeoutSeconds,
        maxOutputBytes: self.shell.maxOutputBytes <= 0
          ? ShellConfiguration().maxOutputBytes
          : self.shell.maxOutputBytes,
        maxOutputLines: self.shell.maxOutputLines <= 0
          ? ShellConfiguration().maxOutputLines
          : self.shell.maxOutputLines,
        allowedEnvironmentKeys: self.shell.allowedEnvironmentKeys.isEmpty
          ? ShellConfiguration().allowedEnvironmentKeys
          : self.shell.allowedEnvironmentKeys,
        redactionPatterns: self.shell.redactionPatterns.isEmpty
          ? ShellConfiguration().redactionPatterns
          : self.shell.redactionPatterns,
        allowedExecutablePaths: self.shell.allowedExecutablePaths.isEmpty
          ? ShellConfiguration().allowedExecutablePaths
          : self.shell.allowedExecutablePaths,
        allowedWorkingDirectories: self.shell.allowedWorkingDirectories.isEmpty
          ? ShellConfiguration().allowedWorkingDirectories
          : self.shell.allowedWorkingDirectories
      ),
      vscode: self.vscode.mergedWithDefaults(),
      privacy: PrivacyConfiguration(
        ambientAudioRetentionSeconds: self.privacy.ambientAudioRetentionSeconds < 0
          ? PrivacyConfiguration().ambientAudioRetentionSeconds
          : self.privacy.ambientAudioRetentionSeconds,
        screenshotRetentionDays: self.privacy.screenshotRetentionDays < 0
          ? PrivacyConfiguration().screenshotRetentionDays
          : self.privacy.screenshotRetentionDays
      ),
      log: LoggingConfiguration(
        minimumLevel: self.log.minimumLevel.isEmpty
          ? LoggingConfiguration().minimumLevel : self.log.minimumLevel,
        destination: self.log.destination.isEmpty
          ? LoggingConfiguration().destination : self.log.destination
      )
    )
  }

  /// Validate the fully resolved configuration.
  public func validate() throws(AuraError) {
    try app.validate()
    try audio.validate()
    try wake.validate()
    try stt.validate()
    try tts.validate()
    try conversation.validate()
    try policy.validate()
    try automation.validate()
    try shell.validate()
    try vscode.validate()
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

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    bundleIdentifier =
      try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) ?? "ai.aura.local"
    serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName) ?? "AuraCore"
  }
}

/// Configuration for the Visual Studio Code adapter.
public struct VSCodeConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `code` CLI executable.
  public var cliPath: String

  /// Timeout in seconds for any `code` CLI invocation.
  public var cliTimeoutSeconds: Double

  /// File path where a companion extension writes editor/terminal state JSON.
  public var bridgeStatePath: String?

  /// Maximum staleness allowed for extension bridge state before it is ignored.
  public var bridgeMaxStalenessSeconds: Double

  /// Whether terminal command injection requires cwd/shell verification.
  public var requireTerminalVerification: Bool

  /// Whether dirty-editor confirmation must be obtained before closing editors.
  public var requireDirtyEditorConfirmation: Bool

  /// Shell executables that may be used as integrated terminal targets.
  public var allowedTerminalShells: Set<String>

  public init(
    cliPath: String = "/usr/local/bin/code",
    cliTimeoutSeconds: Double = 10.0,
    bridgeStatePath: String? = nil,
    bridgeMaxStalenessSeconds: Double = 30.0,
    requireTerminalVerification: Bool = true,
    requireDirtyEditorConfirmation: Bool = true,
    allowedTerminalShells: Set<String> = [
      "/bin/zsh",
      "/bin/bash",
      "/bin/sh",
    ]
  ) {
    self.cliPath = cliPath
    self.cliTimeoutSeconds = cliTimeoutSeconds
    self.bridgeStatePath = bridgeStatePath
    self.bridgeMaxStalenessSeconds = bridgeMaxStalenessSeconds
    self.requireTerminalVerification = requireTerminalVerification
    self.requireDirtyEditorConfirmation = requireDirtyEditorConfirmation
    self.allowedTerminalShells = allowedTerminalShells
  }

  public func validate() throws(AuraError) {
    guard !cliPath.isEmpty else {
      throw AuraError.invalidConfiguration("vscode cliPath must not be empty")
    }
    guard cliTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("vscode cliTimeoutSeconds must be positive")
    }
    guard bridgeMaxStalenessSeconds >= 0 else {
      throw AuraError.invalidConfiguration("vscode bridgeMaxStalenessSeconds must be non-negative")
    }
    guard !allowedTerminalShells.isEmpty else {
      throw AuraError.invalidConfiguration("vscode allowedTerminalShells must not be empty")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> VSCodeConfiguration {
    VSCodeConfiguration(
      cliPath: self.cliPath.isEmpty ? VSCodeConfiguration().cliPath : self.cliPath,
      cliTimeoutSeconds: self.cliTimeoutSeconds <= 0
        ? VSCodeConfiguration().cliTimeoutSeconds
        : self.cliTimeoutSeconds,
      bridgeStatePath: self.bridgeStatePath ?? VSCodeConfiguration().bridgeStatePath,
      bridgeMaxStalenessSeconds: self.bridgeMaxStalenessSeconds < 0
        ? VSCodeConfiguration().bridgeMaxStalenessSeconds
        : self.bridgeMaxStalenessSeconds,
      requireTerminalVerification: self.requireTerminalVerification,
      requireDirtyEditorConfirmation: self.requireDirtyEditorConfirmation,
      allowedTerminalShells: self.allowedTerminalShells.isEmpty
        ? VSCodeConfiguration().allowedTerminalShells
        : self.allowedTerminalShells
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    cliPath = try container.decodeIfPresent(String.self, forKey: .cliPath) ?? "/usr/local/bin/code"
    cliTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .cliTimeoutSeconds) ?? 10.0
    bridgeStatePath = try container.decodeIfPresent(String.self, forKey: .bridgeStatePath)
    bridgeMaxStalenessSeconds =
      try container.decodeIfPresent(Double.self, forKey: .bridgeMaxStalenessSeconds) ?? 30.0
    requireTerminalVerification =
      try container.decodeIfPresent(Bool.self, forKey: .requireTerminalVerification) ?? true
    requireDirtyEditorConfirmation =
      try container.decodeIfPresent(Bool.self, forKey: .requireDirtyEditorConfirmation) ?? true
    allowedTerminalShells =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedTerminalShells)
      ?? [
        "/bin/zsh",
        "/bin/bash",
        "/bin/sh",
      ]
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

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    sampleRate = try container.decodeIfPresent(Double.self, forKey: .sampleRate) ?? 16_000
    channelCount = try container.decodeIfPresent(UInt32.self, forKey: .channelCount) ?? 1
    frameLength = try container.decodeIfPresent(UInt32.self, forKey: .frameLength) ?? 512
    ringBufferSeconds =
      try container.decodeIfPresent(Double.self, forKey: .ringBufferSeconds) ?? 5.0
    captureBufferSize =
      try container.decodeIfPresent(UInt32.self, forKey: .captureBufferSize) ?? 1024
    enableEchoCancellation =
      try container.decodeIfPresent(Bool.self, forKey: .enableEchoCancellation) ?? true
    enableAutomaticGainControl =
      try container.decodeIfPresent(Bool.self, forKey: .enableAutomaticGainControl) ?? true
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

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    engineID = try container.decodeIfPresent(String.self, forKey: .engineID) ?? "native-speech"
    locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? "tr-TR"
    partialBoundaryFrames =
      try container.decodeIfPresent(UInt32.self, forKey: .partialBoundaryFrames) ?? 3
    stabilizationDelayFrames =
      try container.decodeIfPresent(UInt32.self, forKey: .stabilizationDelayFrames) ?? 2
    enableCustomVocabulary =
      try container.decodeIfPresent(Bool.self, forKey: .enableCustomVocabulary) ?? true
  }
}

/// Configuration for text-to-speech adapters and turn-taking policy.
public struct TTSConfiguration: Codable, Sendable, Equatable {
  /// Priority-ordered list of TTS adapter identifiers.
  public var adapterChain: TTSAdapterChain

  /// Default BCP-47 locale for synthesized speech.
  public var defaultLocale: String

  /// Default speech rate. Must be positive.
  public var defaultRate: Double

  /// Whether user speech detected during assistant speech stops the assistant.
  public var enableBargeIn: Bool

  /// Whether assistant output should suppress wake-word detection.
  public var enableAntiTrigger: Bool

  public init(
    adapterChain: TTSAdapterChain = TTSAdapterChain(),
    defaultLocale: String = "en-US",
    defaultRate: Double = 1.0,
    enableBargeIn: Bool = true,
    enableAntiTrigger: Bool = true
  ) {
    self.adapterChain = adapterChain
    self.defaultLocale = defaultLocale
    self.defaultRate = defaultRate
    self.enableBargeIn = enableBargeIn
    self.enableAntiTrigger = enableAntiTrigger
  }

  public func validate() throws(AuraError) {
    try adapterChain.validate()
    guard !defaultLocale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.invalidConfiguration("tts defaultLocale must not be empty")
    }
    guard defaultRate > 0 else {
      throw AuraError.invalidConfiguration("tts defaultRate must be positive")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    adapterChain =
      try container.decodeIfPresent(TTSAdapterChain.self, forKey: .adapterChain)
      ?? TTSAdapterChain()
    defaultLocale = try container.decodeIfPresent(String.self, forKey: .defaultLocale) ?? "en-US"
    defaultRate = try container.decodeIfPresent(Double.self, forKey: .defaultRate) ?? 1.0
    enableBargeIn = try container.decodeIfPresent(Bool.self, forKey: .enableBargeIn) ?? true
    enableAntiTrigger = try container.decodeIfPresent(Bool.self, forKey: .enableAntiTrigger) ?? true
  }
}

/// Configuration for the conversation state machine and timeout policy.
public struct ConversationConfiguration: Codable, Sendable, Equatable {
  /// Seconds of silence or inactivity before aborting a listening turn.
  public var listenTimeoutSeconds: Double

  /// Seconds allowed for the intent engine to produce a response plan.
  public var thinkTimeoutSeconds: Double

  /// Seconds allowed for the TTS engine to complete a spoken response.
  public var speechTimeoutSeconds: Double

  /// Grace period after barge-in before another interruption is accepted.
  public var bargeInGraceMilliseconds: UInt32

  /// Number of consecutive silent frames required to end a listening turn.
  public var silenceEndFrames: UInt32

  /// Deterministic voice commands that always stop the assistant mid-speech.
  public var deterministicStopCommands: Set<String>

  /// Deterministic voice commands that toggle pause/resume.
  public var deterministicPauseResumeCommands: Set<String>

  public init(
    listenTimeoutSeconds: Double = 10.0,
    thinkTimeoutSeconds: Double = 30.0,
    speechTimeoutSeconds: Double = 60.0,
    bargeInGraceMilliseconds: UInt32 = 500,
    silenceEndFrames: UInt32 = 30,
    deterministicStopCommands: Set<String> = ["stop", "cancel", "abort", "quit"],
    deterministicPauseResumeCommands: Set<String> = ["pause", "resume", "continue"]
  ) {
    self.listenTimeoutSeconds = listenTimeoutSeconds
    self.thinkTimeoutSeconds = thinkTimeoutSeconds
    self.speechTimeoutSeconds = speechTimeoutSeconds
    self.bargeInGraceMilliseconds = bargeInGraceMilliseconds
    self.silenceEndFrames = silenceEndFrames
    self.deterministicStopCommands = deterministicStopCommands
    self.deterministicPauseResumeCommands = deterministicPauseResumeCommands
  }

  public func validate() throws(AuraError) {
    guard listenTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("listenTimeoutSeconds must be positive")
    }
    guard thinkTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("thinkTimeoutSeconds must be positive")
    }
    guard speechTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("speechTimeoutSeconds must be positive")
    }
    guard bargeInGraceMilliseconds > 0 else {
      throw AuraError.invalidConfiguration("bargeInGraceMilliseconds must be positive")
    }
    guard silenceEndFrames > 0 else {
      throw AuraError.invalidConfiguration("silenceEndFrames must be positive")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    listenTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .listenTimeoutSeconds) ?? 10.0
    thinkTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .thinkTimeoutSeconds) ?? 30.0
    speechTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .speechTimeoutSeconds) ?? 60.0
    bargeInGraceMilliseconds =
      try container.decodeIfPresent(UInt32.self, forKey: .bargeInGraceMilliseconds) ?? 500
    silenceEndFrames = try container.decodeIfPresent(UInt32.self, forKey: .silenceEndFrames) ?? 30
    deterministicStopCommands =
      try container.decodeIfPresent(Set<String>.self, forKey: .deterministicStopCommands) ?? [
        "stop", "cancel", "abort", "quit",
      ]
    deterministicPauseResumeCommands =
      try container.decodeIfPresent(Set<String>.self, forKey: .deterministicPauseResumeCommands)
      ?? ["pause", "resume", "continue"]
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

/// Configuration for native macOS automation and application control.
public struct AutomationConfiguration: Codable, Sendable, Equatable {
  /// Seconds allowed for a launch/activate/hide/quit action before timeout.
  public var actionTimeoutSeconds: Double

  /// Seconds allowed for an Accessibility observation before timeout.
  public var observationTimeoutSeconds: Double

  /// Bundle identifiers that must never be observed or controlled.
  public var sensitiveBundleIdentifiers: Set<String>

  /// Capability identifiers (domain.action) that automation may perform.
  public var allowedAutomationCapabilities: Set<String>

  public init(
    actionTimeoutSeconds: Double = 10.0,
    observationTimeoutSeconds: Double = 5.0,
    sensitiveBundleIdentifiers: Set<String> = [
      "com.apple.securityagent",
      "com.apple.keychainaccess",
    ],
    allowedAutomationCapabilities: Set<String> = [
      "app.activate",
      "app.terminate",
    ]
  ) {
    self.actionTimeoutSeconds = actionTimeoutSeconds
    self.observationTimeoutSeconds = observationTimeoutSeconds
    self.sensitiveBundleIdentifiers = sensitiveBundleIdentifiers
    self.allowedAutomationCapabilities = allowedAutomationCapabilities
  }

  public func validate() throws(AuraError) {
    guard actionTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("automation actionTimeoutSeconds must be positive")
    }
    guard observationTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration(
        "automation observationTimeoutSeconds must be positive")
    }
    guard !allowedAutomationCapabilities.isEmpty else {
      throw AuraError.invalidConfiguration(
        "automation allowedAutomationCapabilities must not be empty")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    actionTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .actionTimeoutSeconds) ?? 10.0
    observationTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .observationTimeoutSeconds) ?? 5.0
    sensitiveBundleIdentifiers =
      try container.decodeIfPresent(Set<String>.self, forKey: .sensitiveBundleIdentifiers)
      ?? [
        "com.apple.securityagent",
        "com.apple.keychainaccess",
      ]
    allowedAutomationCapabilities =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedAutomationCapabilities)
      ?? [
        "app.activate",
        "app.terminate",
      ]
  }
}

/// Configuration for typed shell / process execution.
public struct ShellConfiguration: Codable, Sendable, Equatable {
  /// Default timeout for any shell command unless overridden by the command.
  public var defaultTimeoutSeconds: Double

  /// Maximum bytes captured from combined stdout and stderr for a single command.
  public var maxOutputBytes: Int

  /// Maximum lines captured from combined stdout and stderr for a single command.
  public var maxOutputLines: Int

  /// Environment variable keys that may be forwarded to child processes.
  public var allowedEnvironmentKeys: Set<String>

  /// Regex patterns that, when matched in output, are replaced with `<redacted>`.
  public var redactionPatterns: [String]

  /// Absolute paths or path globs that commands are allowed to execute.
  public var allowedExecutablePaths: Set<String>

  /// Directories that may be used as working directories.
  public var allowedWorkingDirectories: Set<String>

  public init(
    defaultTimeoutSeconds: Double = 30.0,
    maxOutputBytes: Int = 1_048_576,
    maxOutputLines: Int = 10_000,
    allowedEnvironmentKeys: Set<String> = [
      "HOME",
      "USER",
      "LANG",
      "PATH",
    ],
    redactionPatterns: [String] = [
      "\\b[0-9a-fA-F]{40}\\b",
      "sk-[a-zA-Z0-9]{48}",
    ],
    allowedExecutablePaths: Set<String> = [
      "/bin/*",
      "/usr/bin/*",
      "/usr/local/bin/*",
      "/Library/Developer/CommandLineTools/usr/bin/*",
    ],
    allowedWorkingDirectories: Set<String> = [
      "$HOME",
      "$TMPDIR",
    ]
  ) {
    self.defaultTimeoutSeconds = defaultTimeoutSeconds
    self.maxOutputBytes = maxOutputBytes
    self.maxOutputLines = maxOutputLines
    self.allowedEnvironmentKeys = allowedEnvironmentKeys
    self.redactionPatterns = redactionPatterns
    self.allowedExecutablePaths = allowedExecutablePaths
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  public func validate() throws(AuraError) {
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("shell defaultTimeoutSeconds must be positive")
    }
    guard maxOutputBytes > 0 else {
      throw AuraError.invalidConfiguration("shell maxOutputBytes must be positive")
    }
    guard maxOutputLines > 0 else {
      throw AuraError.invalidConfiguration("shell maxOutputLines must be positive")
    }
    for pattern in redactionPatterns {
      guard !pattern.isEmpty else {
        throw AuraError.invalidConfiguration(
          "shell redactionPatterns must not contain empty patterns")
      }
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 30.0
    maxOutputBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 1_048_576
    maxOutputLines =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputLines) ?? 10_000
    allowedEnvironmentKeys =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedEnvironmentKeys)
      ?? [
        "HOME",
        "USER",
        "LANG",
        "PATH",
      ]
    redactionPatterns =
      try container.decodeIfPresent([String].self, forKey: .redactionPatterns)
      ?? [
        "\\b[0-9a-fA-F]{40}\\b",
        "sk-[a-zA-Z0-9]{48}",
      ]
    allowedExecutablePaths =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedExecutablePaths)
      ?? [
        "/bin/*",
        "/usr/bin/*",
        "/usr/local/bin/*",
        "/Library/Developer/CommandLineTools/usr/bin/*",
      ]
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories)
      ?? [
        "$HOME",
        "$TMPDIR",
      ]
  }
}

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

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    ambientAudioRetentionSeconds =
      try container.decodeIfPresent(Double.self, forKey: .ambientAudioRetentionSeconds) ?? 0
    screenshotRetentionDays =
      try container.decodeIfPresent(Int.self, forKey: .screenshotRetentionDays) ?? 7
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

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    minimumLevel = try container.decodeIfPresent(String.self, forKey: .minimumLevel) ?? "info"
    destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? "stderr"
  }
}
