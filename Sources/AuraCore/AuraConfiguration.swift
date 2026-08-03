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
  public var task: TaskConfiguration
  public var codex: CodexConfiguration
  public var claude: ClaudeConfiguration
  public var copilot: CopilotConfiguration
  public var ollama: OllamaConfiguration
  public var worktree: WorktreeConfiguration
  public var context: ContextConfiguration
  public var screen: ScreenContextConfiguration
  public var computerUse: ComputerUseConfiguration
  public var privacy: PrivacyConfiguration
  public var log: LoggingConfiguration
  public var security: SecurityConfiguration
  public var plugins: PluginConfiguration
  public var intent: IntentEngineConfiguration

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
    task: TaskConfiguration = TaskConfiguration(),
    codex: CodexConfiguration = CodexConfiguration(),
    claude: ClaudeConfiguration = ClaudeConfiguration(),
    copilot: CopilotConfiguration = CopilotConfiguration(),
    ollama: OllamaConfiguration = OllamaConfiguration(),
    worktree: WorktreeConfiguration = WorktreeConfiguration(),
    context: ContextConfiguration = ContextConfiguration(),
    screen: ScreenContextConfiguration = ScreenContextConfiguration(),
    computerUse: ComputerUseConfiguration = ComputerUseConfiguration(),
    privacy: PrivacyConfiguration = PrivacyConfiguration(),
    log: LoggingConfiguration = LoggingConfiguration(),
    security: SecurityConfiguration = SecurityConfiguration(),
    plugins: PluginConfiguration = PluginConfiguration(),
    intent: IntentEngineConfiguration = IntentEngineConfiguration()
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
    self.task = task
    self.codex = codex
    self.claude = claude
    self.copilot = copilot
    self.ollama = ollama
    self.worktree = worktree
    self.context = context
    self.screen = screen
    self.computerUse = computerUse
    self.privacy = privacy
    self.log = log
    self.security = security
    self.plugins = plugins
    self.intent = intent
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
    task =
      try container.decodeIfPresent(TaskConfiguration.self, forKey: .task)
      ?? TaskConfiguration()
    codex =
      try container.decodeIfPresent(CodexConfiguration.self, forKey: .codex)
      ?? CodexConfiguration()
    claude =
      try container.decodeIfPresent(ClaudeConfiguration.self, forKey: .claude)
      ?? ClaudeConfiguration()
    copilot =
      try container.decodeIfPresent(CopilotConfiguration.self, forKey: .copilot)
      ?? CopilotConfiguration()
    ollama =
      try container.decodeIfPresent(OllamaConfiguration.self, forKey: .ollama)
      ?? OllamaConfiguration()
    worktree =
      try container.decodeIfPresent(WorktreeConfiguration.self, forKey: .worktree)
      ?? WorktreeConfiguration()
    context =
      try container.decodeIfPresent(ContextConfiguration.self, forKey: .context)
      ?? ContextConfiguration()
    screen =
      try container.decodeIfPresent(ScreenContextConfiguration.self, forKey: .screen)
      ?? ScreenContextConfiguration()
    computerUse =
      try container.decodeIfPresent(ComputerUseConfiguration.self, forKey: .computerUse)
      ?? ComputerUseConfiguration()
    privacy =
      try container.decodeIfPresent(PrivacyConfiguration.self, forKey: .privacy)
      ?? PrivacyConfiguration()
    log =
      try container.decodeIfPresent(LoggingConfiguration.self, forKey: .log)
      ?? LoggingConfiguration()
    security =
      try container.decodeIfPresent(SecurityConfiguration.self, forKey: .security)
      ?? SecurityConfiguration()
    plugins =
      try container.decodeIfPresent(PluginConfiguration.self, forKey: .plugins)
      ?? PluginConfiguration()
    intent =
      try container.decodeIfPresent(IntentEngineConfiguration.self, forKey: .intent)
      ?? IntentEngineConfiguration()
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
        preferredSystemVoiceIdentifier: self.tts.preferredSystemVoiceIdentifier.isEmpty
          ? TTSConfiguration().preferredSystemVoiceIdentifier
          : self.tts.preferredSystemVoiceIdentifier,
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
      task: TaskConfiguration(
        defaultMaxRetries: self.task.defaultMaxRetries < 0
          ? TaskConfiguration().defaultMaxRetries : self.task.defaultMaxRetries,
        defaultInactivityTimeoutSeconds: self.task.defaultInactivityTimeoutSeconds <= 0
          ? TaskConfiguration().defaultInactivityTimeoutSeconds
          : self.task.defaultInactivityTimeoutSeconds,
        checkpointRetentionDays: self.task.checkpointRetentionDays <= 0
          ? TaskConfiguration().checkpointRetentionDays : self.task.checkpointRetentionDays,
        maxConcurrentTasks: self.task.maxConcurrentTasks <= 0
          ? TaskConfiguration().maxConcurrentTasks : self.task.maxConcurrentTasks,
        queueCapacity: self.task.queueCapacity <= 0
          ? TaskConfiguration().queueCapacity : self.task.queueCapacity
      ),
      codex: self.codex.mergedWithDefaults(),
      claude: self.claude.mergedWithDefaults(),
      copilot: self.copilot.mergedWithDefaults(),
      ollama: self.ollama.mergedWithDefaults(),
      worktree: self.worktree.mergedWithDefaults(),
      context: self.context.mergedWithDefaults(),
      screen: self.screen.mergedWithDefaults(),
      computerUse: self.computerUse.mergedWithDefaults(),
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
      ),
      security: self.security.mergedWithDefaults(),
      plugins: self.plugins.mergedWithDefaults(),
      intent: self.intent.mergedWithDefaults()
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
    try task.validate()
    try codex.validate()
    try claude.validate()
    try copilot.validate()
    try ollama.validate()
    try worktree.validate()
    try context.validate()
    try screen.validate()
    try computerUse.validate()
    try privacy.validate()
    try log.validate()
    try security.validate()
    try plugins.validate()
    try intent.validate()
  }
}

/// Configuration for the durable task engine.
public struct TaskConfiguration: Codable, Sendable, Equatable {
  /// Default maximum number of bounded retries for a recoverable task step.
  public var defaultMaxRetries: Int

  /// Seconds of inactivity before a running task is automatically paused.
  public var defaultInactivityTimeoutSeconds: Double

  /// Days to retain checkpoints before they become eligible for eviction.
  public var checkpointRetentionDays: Int

  /// Maximum number of tasks allowed to run concurrently.
  public var maxConcurrentTasks: Int

  /// Maximum number of pending tasks in the queue.
  public var queueCapacity: Int

  public init(
    defaultMaxRetries: Int = 3,
    defaultInactivityTimeoutSeconds: Double = 300.0,
    checkpointRetentionDays: Int = 30,
    maxConcurrentTasks: Int = 3,
    queueCapacity: Int = 100
  ) {
    self.defaultMaxRetries = defaultMaxRetries
    self.defaultInactivityTimeoutSeconds = defaultInactivityTimeoutSeconds
    self.checkpointRetentionDays = checkpointRetentionDays
    self.maxConcurrentTasks = maxConcurrentTasks
    self.queueCapacity = queueCapacity
  }

  public func validate() throws(AuraError) {
    guard defaultMaxRetries >= 0 else {
      throw AuraError.invalidConfiguration("task defaultMaxRetries must be non-negative")
    }
    guard defaultInactivityTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("task defaultInactivityTimeoutSeconds must be positive")
    }
    guard checkpointRetentionDays > 0 else {
      throw AuraError.invalidConfiguration("task checkpointRetentionDays must be positive")
    }
    guard maxConcurrentTasks > 0 else {
      throw AuraError.invalidConfiguration("task maxConcurrentTasks must be positive")
    }
    guard queueCapacity > 0 else {
      throw AuraError.invalidConfiguration("task queueCapacity must be positive")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    defaultMaxRetries = try container.decodeIfPresent(Int.self, forKey: .defaultMaxRetries) ?? 3
    defaultInactivityTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultInactivityTimeoutSeconds) ?? 300.0
    checkpointRetentionDays =
      try container.decodeIfPresent(Int.self, forKey: .checkpointRetentionDays) ?? 30
    maxConcurrentTasks =
      try container.decodeIfPresent(Int.self, forKey: .maxConcurrentTasks) ?? 3
    queueCapacity = try container.decodeIfPresent(Int.self, forKey: .queueCapacity) ?? 100
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

  /// Explicit local system voice used when the neural adapter is unavailable.
  public var preferredSystemVoiceIdentifier: String

  /// Whether user speech detected during assistant speech stops the assistant.
  public var enableBargeIn: Bool

  /// Whether assistant output should suppress wake-word detection.
  public var enableAntiTrigger: Bool

  public init(
    adapterChain: TTSAdapterChain = TTSAdapterChain(),
    defaultLocale: String = "tr-TR",
    defaultRate: Double = 0.92,
    preferredSystemVoiceIdentifier: String = "com.apple.voice.compact.tr-TR.Yelda",
    enableBargeIn: Bool = true,
    enableAntiTrigger: Bool = true
  ) {
    self.adapterChain = adapterChain
    self.defaultLocale = defaultLocale
    self.defaultRate = defaultRate
    self.preferredSystemVoiceIdentifier = preferredSystemVoiceIdentifier
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
    defaultLocale = try container.decodeIfPresent(String.self, forKey: .defaultLocale) ?? "tr-TR"
    defaultRate = try container.decodeIfPresent(Double.self, forKey: .defaultRate) ?? 0.92
    preferredSystemVoiceIdentifier =
      try container.decodeIfPresent(String.self, forKey: .preferredSystemVoiceIdentifier)
      ?? "com.apple.voice.compact.tr-TR.Yelda"
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
    deterministicStopCommands: Set<String> = [
      "stop", "cancel", "abort", "quit", "dur", "iptal", "vazgeç"
    ],
    deterministicPauseResumeCommands: Set<String> = [
      "pause", "resume", "continue", "duraklat", "sürdür", "devam et"
    ]
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
        "stop", "cancel", "abort", "quit", "dur", "iptal", "vazgeç",
      ]
    deterministicPauseResumeCommands =
      try container.decodeIfPresent(Set<String>.self, forKey: .deterministicPauseResumeCommands)
      ?? ["pause", "resume", "continue", "duraklat", "sürdür", "devam et"]
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

/// Configuration for the Codex CLI adapter.
///
/// `codex exec` is always invoked with `-a never` (hardcoded in `CodexArguments`,
/// never derived from configuration) since non-interactive runs have no TTY to
/// answer an approval prompt; this configuration only controls sandboxing,
/// timeouts, output bounds, and soft budgets.
public struct CodexConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `codex` CLI executable.
  public var executablePath: String

  /// Default timeout in seconds for a `codex exec` invocation.
  public var defaultTimeoutSeconds: Double

  /// Hard ceiling on `timeoutSeconds` a caller may request for a single run.
  public var maxTimeoutSeconds: Double

  /// Maximum bytes captured from combined stdout/stderr for a single run.
  public var maxOutputBytes: Int

  /// Maximum lines captured from combined stdout/stderr for a single run.
  public var maxOutputLines: Int

  /// Maximum number of file-change items tolerated before a run is cancelled.
  public var maxFileWritesPerRun: Int

  /// Soft token budget. `nil` disables token-budget enforcement (default,
  /// since `usage` field names are unverified pending live observation).
  public var maxTokensPerRun: Int?

  /// Soft estimated-cost budget in USD. `nil` disables cost enforcement.
  public var maxEstimatedCostUSD: Double?

  /// Price per token used to estimate cost from observed usage. `nil` means
  /// cost is never estimated, only raw token counts are reported.
  public var costPerTokenUSD: Double?

  /// Whether `--ephemeral` (skip session persistence) is passed by default.
  public var ephemeralByDefault: Bool

  /// Whether `--skip-git-repo-check` is passed by default.
  public var skipGitRepoCheckByDefault: Bool

  /// Whether `--ignore-user-config` (skip `~/.codex/config.toml`) is passed
  /// by default, favoring reproducibility over ambient user configuration.
  public var ignoreUserConfigByDefault: Bool

  /// Directories a run's working directory or `--add-dir` targets must fall
  /// under.
  public var allowedWorkingDirectories: Set<String>

  public init(
    executablePath: String = "/opt/homebrew/bin/codex",
    defaultTimeoutSeconds: Double = 300.0,
    maxTimeoutSeconds: Double = 1800.0,
    maxOutputBytes: Int = 4_194_304,
    maxOutputLines: Int = 50_000,
    maxFileWritesPerRun: Int = 20,
    maxTokensPerRun: Int? = nil,
    maxEstimatedCostUSD: Double? = nil,
    costPerTokenUSD: Double? = nil,
    ephemeralByDefault: Bool = true,
    skipGitRepoCheckByDefault: Bool = false,
    ignoreUserConfigByDefault: Bool = true,
    allowedWorkingDirectories: Set<String> = [
      "$HOME",
      "$TMPDIR",
    ]
  ) {
    self.executablePath = executablePath
    self.defaultTimeoutSeconds = defaultTimeoutSeconds
    self.maxTimeoutSeconds = maxTimeoutSeconds
    self.maxOutputBytes = maxOutputBytes
    self.maxOutputLines = maxOutputLines
    self.maxFileWritesPerRun = maxFileWritesPerRun
    self.maxTokensPerRun = maxTokensPerRun
    self.maxEstimatedCostUSD = maxEstimatedCostUSD
    self.costPerTokenUSD = costPerTokenUSD
    self.ephemeralByDefault = ephemeralByDefault
    self.skipGitRepoCheckByDefault = skipGitRepoCheckByDefault
    self.ignoreUserConfigByDefault = ignoreUserConfigByDefault
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  public func validate() throws(AuraError) {
    guard !executablePath.isEmpty else {
      throw AuraError.invalidConfiguration("codex executablePath must not be empty")
    }
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("codex defaultTimeoutSeconds must be positive")
    }
    guard maxTimeoutSeconds >= defaultTimeoutSeconds else {
      throw AuraError.invalidConfiguration(
        "codex maxTimeoutSeconds must be at least defaultTimeoutSeconds")
    }
    guard maxOutputBytes > 0 else {
      throw AuraError.invalidConfiguration("codex maxOutputBytes must be positive")
    }
    guard maxOutputLines > 0 else {
      throw AuraError.invalidConfiguration("codex maxOutputLines must be positive")
    }
    guard maxFileWritesPerRun > 0 else {
      throw AuraError.invalidConfiguration("codex maxFileWritesPerRun must be positive")
    }
    if let maxTokensPerRun {
      guard maxTokensPerRun > 0 else {
        throw AuraError.invalidConfiguration("codex maxTokensPerRun must be positive when set")
      }
    }
    if let maxEstimatedCostUSD {
      guard maxEstimatedCostUSD > 0 else {
        throw AuraError.invalidConfiguration("codex maxEstimatedCostUSD must be positive when set")
      }
    }
    if let costPerTokenUSD {
      guard costPerTokenUSD > 0 else {
        throw AuraError.invalidConfiguration("codex costPerTokenUSD must be positive when set")
      }
    }
    guard !allowedWorkingDirectories.isEmpty else {
      throw AuraError.invalidConfiguration("codex allowedWorkingDirectories must not be empty")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> CodexConfiguration {
    CodexConfiguration(
      executablePath: self.executablePath.isEmpty
        ? CodexConfiguration().executablePath
        : self.executablePath,
      defaultTimeoutSeconds: self.defaultTimeoutSeconds <= 0
        ? CodexConfiguration().defaultTimeoutSeconds
        : self.defaultTimeoutSeconds,
      maxTimeoutSeconds: self.maxTimeoutSeconds <= 0
        ? CodexConfiguration().maxTimeoutSeconds
        : self.maxTimeoutSeconds,
      maxOutputBytes: self.maxOutputBytes <= 0
        ? CodexConfiguration().maxOutputBytes
        : self.maxOutputBytes,
      maxOutputLines: self.maxOutputLines <= 0
        ? CodexConfiguration().maxOutputLines
        : self.maxOutputLines,
      maxFileWritesPerRun: self.maxFileWritesPerRun <= 0
        ? CodexConfiguration().maxFileWritesPerRun
        : self.maxFileWritesPerRun,
      maxTokensPerRun: self.maxTokensPerRun,
      maxEstimatedCostUSD: self.maxEstimatedCostUSD,
      costPerTokenUSD: self.costPerTokenUSD,
      ephemeralByDefault: self.ephemeralByDefault,
      skipGitRepoCheckByDefault: self.skipGitRepoCheckByDefault,
      ignoreUserConfigByDefault: self.ignoreUserConfigByDefault,
      allowedWorkingDirectories: self.allowedWorkingDirectories.isEmpty
        ? CodexConfiguration().allowedWorkingDirectories
        : self.allowedWorkingDirectories
    )
  }

  /// A `ShellConfiguration` scoped to only ever launch the configured Codex
  /// binary. `ShellConfiguration`'s own defaults do not include
  /// `/opt/homebrew/bin`, so callers must not widen the shared default
  /// configuration just to accommodate Codex; a dedicated `AuraShell`
  /// built from this narrow configuration is used instead.
  public func derivedShellConfiguration() -> ShellConfiguration {
    ShellConfiguration(
      defaultTimeoutSeconds: defaultTimeoutSeconds,
      maxOutputBytes: maxOutputBytes,
      maxOutputLines: maxOutputLines,
      allowedExecutablePaths: [executablePath],
      allowedWorkingDirectories: allowedWorkingDirectories
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    executablePath =
      try container.decodeIfPresent(String.self, forKey: .executablePath)
      ?? "/opt/homebrew/bin/codex"
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 300.0
    maxTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .maxTimeoutSeconds) ?? 1800.0
    maxOutputBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 4_194_304
    maxOutputLines =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputLines) ?? 50_000
    maxFileWritesPerRun =
      try container.decodeIfPresent(Int.self, forKey: .maxFileWritesPerRun) ?? 20
    maxTokensPerRun = try container.decodeIfPresent(Int.self, forKey: .maxTokensPerRun)
    maxEstimatedCostUSD =
      try container.decodeIfPresent(Double.self, forKey: .maxEstimatedCostUSD)
    costPerTokenUSD = try container.decodeIfPresent(Double.self, forKey: .costPerTokenUSD)
    ephemeralByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .ephemeralByDefault) ?? true
    skipGitRepoCheckByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .skipGitRepoCheckByDefault) ?? false
    ignoreUserConfigByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .ignoreUserConfigByDefault) ?? true
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories)
      ?? [
        "$HOME",
        "$TMPDIR",
      ]
  }
}

/// Configuration for the Claude Code CLI adapter.
///
/// `claude -p` is always invoked with `--permission-mode dontAsk` (hardcoded
/// in `ClaudeArguments`, never derived from configuration) — the same
/// reasoning as `CodexConfiguration`: a non-interactive run has no TTY to
/// answer a permission prompt, so any mode other than the deny-and-continue
/// one could block forever. This configuration controls tool availability,
/// hooks/settings scoping, timeouts, output bounds, and budgets.
public struct ClaudeConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `claude` CLI executable.
  public var executablePath: String

  /// Default timeout in seconds for a `claude -p` invocation.
  public var defaultTimeoutSeconds: Double

  /// Hard ceiling on `timeoutSeconds` a caller may request for a single run.
  public var maxTimeoutSeconds: Double

  /// Maximum bytes captured from combined stdout/stderr for a single run.
  public var maxOutputBytes: Int

  /// Maximum lines captured from combined stdout/stderr for a single run.
  public var maxOutputLines: Int

  /// Estimated-cost budget in USD, enforced natively by the CLI via
  /// `--max-budget-usd` when set. `nil` disables cost enforcement.
  ///
  /// Unlike `CodexConfiguration`, there is no `maxFileWritesPerRun`: the
  /// authorized smoke test ran with `--tools ""`, so `tool_use`/`tool_result`
  /// content-block field names were never observed and are not fabricated
  /// here. `.readOnly` tool profile prevents writes by construction (no
  /// write-capable tool exists in that tier) instead of by counting after
  /// the fact — see ADR-012.
  public var maxEstimatedCostUSD: Double?

  /// Whether `--no-session-persistence` is passed by default.
  public var ephemeralByDefault: Bool

  /// Which settings layers (`user`, `project`, `local`) `--setting-sources`
  /// loads. Defaults to `["user"]` only — excluding `project`/`local` means
  /// a target repository's own `.claude/settings.json`/`settings.local.json`
  /// (where hooks and `.mcp.json`-referenced servers are configured) never
  /// loads, while the operating user's own trusted `~/.claude/settings.json`
  /// still does. `--bare` (which also skips OAuth/keychain auth) is
  /// deliberately not the default; see ADR-012.
  public var settingSources: Set<String>

  /// Built-in tool names available in the read-only tier (`--tools`).
  public var readOnlyTools: [String]

  /// Built-in tool names available in the workspace-write tier (`--tools`).
  public var workspaceWriteTools: [String]

  /// Directories a run's working directory or `--add-dir` targets must fall
  /// under.
  public var allowedWorkingDirectories: Set<String>

  public init(
    executablePath: String = "/opt/homebrew/bin/claude",
    defaultTimeoutSeconds: Double = 300.0,
    maxTimeoutSeconds: Double = 1800.0,
    maxOutputBytes: Int = 4_194_304,
    maxOutputLines: Int = 50_000,
    maxEstimatedCostUSD: Double? = nil,
    ephemeralByDefault: Bool = true,
    settingSources: Set<String> = ["user"],
    readOnlyTools: [String] = ["Read", "Grep", "Glob"],
    workspaceWriteTools: [String] = ["Bash", "Read", "Edit", "Write", "Grep", "Glob"],
    allowedWorkingDirectories: Set<String> = [
      "$HOME",
      "$TMPDIR",
    ]
  ) {
    self.executablePath = executablePath
    self.defaultTimeoutSeconds = defaultTimeoutSeconds
    self.maxTimeoutSeconds = maxTimeoutSeconds
    self.maxOutputBytes = maxOutputBytes
    self.maxOutputLines = maxOutputLines
    self.maxEstimatedCostUSD = maxEstimatedCostUSD
    self.ephemeralByDefault = ephemeralByDefault
    self.settingSources = settingSources
    self.readOnlyTools = readOnlyTools
    self.workspaceWriteTools = workspaceWriteTools
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  public func validate() throws(AuraError) {
    guard !executablePath.isEmpty else {
      throw AuraError.invalidConfiguration("claude executablePath must not be empty")
    }
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("claude defaultTimeoutSeconds must be positive")
    }
    guard maxTimeoutSeconds >= defaultTimeoutSeconds else {
      throw AuraError.invalidConfiguration(
        "claude maxTimeoutSeconds must be at least defaultTimeoutSeconds")
    }
    guard maxOutputBytes > 0 else {
      throw AuraError.invalidConfiguration("claude maxOutputBytes must be positive")
    }
    guard maxOutputLines > 0 else {
      throw AuraError.invalidConfiguration("claude maxOutputLines must be positive")
    }
    if let maxEstimatedCostUSD {
      guard maxEstimatedCostUSD > 0 else {
        throw AuraError.invalidConfiguration("claude maxEstimatedCostUSD must be positive when set")
      }
    }
    guard !readOnlyTools.isEmpty else {
      throw AuraError.invalidConfiguration("claude readOnlyTools must not be empty")
    }
    guard !workspaceWriteTools.isEmpty else {
      throw AuraError.invalidConfiguration("claude workspaceWriteTools must not be empty")
    }
    guard !allowedWorkingDirectories.isEmpty else {
      throw AuraError.invalidConfiguration("claude allowedWorkingDirectories must not be empty")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> ClaudeConfiguration {
    ClaudeConfiguration(
      executablePath: self.executablePath.isEmpty
        ? ClaudeConfiguration().executablePath
        : self.executablePath,
      defaultTimeoutSeconds: self.defaultTimeoutSeconds <= 0
        ? ClaudeConfiguration().defaultTimeoutSeconds
        : self.defaultTimeoutSeconds,
      maxTimeoutSeconds: self.maxTimeoutSeconds <= 0
        ? ClaudeConfiguration().maxTimeoutSeconds
        : self.maxTimeoutSeconds,
      maxOutputBytes: self.maxOutputBytes <= 0
        ? ClaudeConfiguration().maxOutputBytes
        : self.maxOutputBytes,
      maxOutputLines: self.maxOutputLines <= 0
        ? ClaudeConfiguration().maxOutputLines
        : self.maxOutputLines,
      maxEstimatedCostUSD: self.maxEstimatedCostUSD,
      ephemeralByDefault: self.ephemeralByDefault,
      settingSources: self.settingSources.isEmpty
        ? ClaudeConfiguration().settingSources
        : self.settingSources,
      readOnlyTools: self.readOnlyTools.isEmpty
        ? ClaudeConfiguration().readOnlyTools
        : self.readOnlyTools,
      workspaceWriteTools: self.workspaceWriteTools.isEmpty
        ? ClaudeConfiguration().workspaceWriteTools
        : self.workspaceWriteTools,
      allowedWorkingDirectories: self.allowedWorkingDirectories.isEmpty
        ? ClaudeConfiguration().allowedWorkingDirectories
        : self.allowedWorkingDirectories
    )
  }

  /// A `ShellConfiguration` scoped to only ever launch the configured Claude
  /// binary. `ShellConfiguration`'s own defaults do not include
  /// `/opt/homebrew/bin`, so callers must not widen the shared default
  /// configuration just to accommodate Claude; a dedicated `AuraShell` built
  /// from this narrow configuration is used instead.
  public func derivedShellConfiguration() -> ShellConfiguration {
    ShellConfiguration(
      defaultTimeoutSeconds: defaultTimeoutSeconds,
      maxOutputBytes: maxOutputBytes,
      maxOutputLines: maxOutputLines,
      allowedExecutablePaths: [executablePath],
      allowedWorkingDirectories: allowedWorkingDirectories
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    executablePath =
      try container.decodeIfPresent(String.self, forKey: .executablePath)
      ?? "/opt/homebrew/bin/claude"
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 300.0
    maxTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .maxTimeoutSeconds) ?? 1800.0
    maxOutputBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 4_194_304
    maxOutputLines =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputLines) ?? 50_000
    maxEstimatedCostUSD =
      try container.decodeIfPresent(Double.self, forKey: .maxEstimatedCostUSD)
    ephemeralByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .ephemeralByDefault) ?? true
    settingSources =
      try container.decodeIfPresent(Set<String>.self, forKey: .settingSources) ?? ["user"]
    readOnlyTools =
      try container.decodeIfPresent([String].self, forKey: .readOnlyTools)
      ?? ["Read", "Grep", "Glob"]
    workspaceWriteTools =
      try container.decodeIfPresent([String].self, forKey: .workspaceWriteTools)
      ?? ["Bash", "Read", "Edit", "Write", "Grep", "Glob"]
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories)
      ?? [
        "$HOME",
        "$TMPDIR",
      ]
  }
}

/// Configuration for the GitHub Copilot CLI adapter.
///
/// `copilot -p` (non-interactive mode) always runs with `--disable-builtin-mcps`
/// (the built-in `github-mcp-server` can create real, team-visible GitHub API
/// side effects — out of scope for local execution) and never with
/// `--allow-all`/`--yolo`/`--allow-all-paths`/`--allow-all-urls`/`--remote`/
/// `--remote-export`/`--share`/`--share-gist` (all unreachable by
/// construction). See ADR-013.
public struct CopilotConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `copilot` CLI executable.
  public var executablePath: String

  /// Default timeout in seconds for a `copilot -p` invocation.
  public var defaultTimeoutSeconds: Double

  /// Hard ceiling on `timeoutSeconds` a caller may request for a single run.
  public var maxTimeoutSeconds: Double

  /// Maximum bytes captured from combined stdout/stderr for a single run.
  public var maxOutputBytes: Int

  /// Maximum lines captured from combined stdout/stderr for a single run.
  public var maxOutputLines: Int

  /// Soft AI-credit budget, enforced natively by the CLI via
  /// `--max-ai-credits` when set. `nil` disables credit-budget enforcement.
  public var maxAICredits: Int?

  /// Maximum number of files the CLI's own `result.usage.codeChanges
  /// .filesModified` may report before a run is flagged as having exceeded
  /// its file-write budget. This is a post-hoc observability check (the run
  /// has already finished by the time the final `result` is known), not a
  /// live pre-emptive cancel — the CLI does not stream a per-file-write event
  /// this phase's normalizer decodes.
  public var maxFileWritesPerRun: Int

  /// Whether repository custom instructions (`.github/copilot-instructions.md`,
  /// `AGENTS.md`, etc.) are loaded by default. When `true`, `CopilotAdapter`
  /// still scans them for secret patterns before every run regardless of
  /// `scanRepositoryInstructionsForSecrets`.
  public var loadCustomInstructionsByDefault: Bool

  /// Whether repository-customization files are scanned for secret-looking
  /// content before a run; a match causes the run to be refused.
  public var scanRepositoryInstructionsForSecrets: Bool

  /// Directories a run's working directory or `--add-dir` targets must fall
  /// under.
  public var allowedWorkingDirectories: Set<String>

  public init(
    executablePath: String = "/opt/homebrew/bin/copilot",
    defaultTimeoutSeconds: Double = 300.0,
    maxTimeoutSeconds: Double = 1800.0,
    maxOutputBytes: Int = 4_194_304,
    maxOutputLines: Int = 50_000,
    maxAICredits: Int? = nil,
    maxFileWritesPerRun: Int = 20,
    loadCustomInstructionsByDefault: Bool = true,
    scanRepositoryInstructionsForSecrets: Bool = true,
    allowedWorkingDirectories: Set<String> = [
      "$HOME",
      "$TMPDIR",
    ]
  ) {
    self.executablePath = executablePath
    self.defaultTimeoutSeconds = defaultTimeoutSeconds
    self.maxTimeoutSeconds = maxTimeoutSeconds
    self.maxOutputBytes = maxOutputBytes
    self.maxOutputLines = maxOutputLines
    self.maxAICredits = maxAICredits
    self.maxFileWritesPerRun = maxFileWritesPerRun
    self.loadCustomInstructionsByDefault = loadCustomInstructionsByDefault
    self.scanRepositoryInstructionsForSecrets = scanRepositoryInstructionsForSecrets
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  public func validate() throws(AuraError) {
    guard !executablePath.isEmpty else {
      throw AuraError.invalidConfiguration("copilot executablePath must not be empty")
    }
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("copilot defaultTimeoutSeconds must be positive")
    }
    guard maxTimeoutSeconds >= defaultTimeoutSeconds else {
      throw AuraError.invalidConfiguration(
        "copilot maxTimeoutSeconds must be at least defaultTimeoutSeconds")
    }
    guard maxOutputBytes > 0 else {
      throw AuraError.invalidConfiguration("copilot maxOutputBytes must be positive")
    }
    guard maxOutputLines > 0 else {
      throw AuraError.invalidConfiguration("copilot maxOutputLines must be positive")
    }
    if let maxAICredits {
      guard maxAICredits > 0 else {
        throw AuraError.invalidConfiguration("copilot maxAICredits must be positive when set")
      }
    }
    guard maxFileWritesPerRun > 0 else {
      throw AuraError.invalidConfiguration("copilot maxFileWritesPerRun must be positive")
    }
    guard !allowedWorkingDirectories.isEmpty else {
      throw AuraError.invalidConfiguration("copilot allowedWorkingDirectories must not be empty")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> CopilotConfiguration {
    CopilotConfiguration(
      executablePath: self.executablePath.isEmpty
        ? CopilotConfiguration().executablePath
        : self.executablePath,
      defaultTimeoutSeconds: self.defaultTimeoutSeconds <= 0
        ? CopilotConfiguration().defaultTimeoutSeconds
        : self.defaultTimeoutSeconds,
      maxTimeoutSeconds: self.maxTimeoutSeconds <= 0
        ? CopilotConfiguration().maxTimeoutSeconds
        : self.maxTimeoutSeconds,
      maxOutputBytes: self.maxOutputBytes <= 0
        ? CopilotConfiguration().maxOutputBytes
        : self.maxOutputBytes,
      maxOutputLines: self.maxOutputLines <= 0
        ? CopilotConfiguration().maxOutputLines
        : self.maxOutputLines,
      maxAICredits: self.maxAICredits,
      maxFileWritesPerRun: self.maxFileWritesPerRun <= 0
        ? CopilotConfiguration().maxFileWritesPerRun
        : self.maxFileWritesPerRun,
      loadCustomInstructionsByDefault: self.loadCustomInstructionsByDefault,
      scanRepositoryInstructionsForSecrets: self.scanRepositoryInstructionsForSecrets,
      allowedWorkingDirectories: self.allowedWorkingDirectories.isEmpty
        ? CopilotConfiguration().allowedWorkingDirectories
        : self.allowedWorkingDirectories
    )
  }

  /// A `ShellConfiguration` scoped to only ever launch the configured
  /// Copilot binary. `ShellConfiguration`'s own defaults do not include
  /// `/opt/homebrew/bin`, so callers must not widen the shared default
  /// configuration just to accommodate Copilot; a dedicated `AuraShell`
  /// built from this narrow configuration is used instead.
  public func derivedShellConfiguration() -> ShellConfiguration {
    ShellConfiguration(
      defaultTimeoutSeconds: defaultTimeoutSeconds,
      maxOutputBytes: maxOutputBytes,
      maxOutputLines: maxOutputLines,
      allowedExecutablePaths: [executablePath],
      allowedWorkingDirectories: allowedWorkingDirectories
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    executablePath =
      try container.decodeIfPresent(String.self, forKey: .executablePath)
      ?? "/opt/homebrew/bin/copilot"
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 300.0
    maxTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .maxTimeoutSeconds) ?? 1800.0
    maxOutputBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 4_194_304
    maxOutputLines =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputLines) ?? 50_000
    maxAICredits = try container.decodeIfPresent(Int.self, forKey: .maxAICredits)
    maxFileWritesPerRun =
      try container.decodeIfPresent(Int.self, forKey: .maxFileWritesPerRun) ?? 20
    loadCustomInstructionsByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .loadCustomInstructionsByDefault) ?? true
    scanRepositoryInstructionsForSecrets =
      try container.decodeIfPresent(Bool.self, forKey: .scanRepositoryInstructionsForSecrets)
      ?? true
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories)
      ?? [
        "$HOME",
        "$TMPDIR",
      ]
  }
}

public struct OllamaConfiguration: Codable, Sendable, Equatable {
  /// Base URL of the local Ollama daemon's HTTP API. Must resolve to a
  /// loopback host (`127.0.0.1`, `::1`, or `localhost`) — `validate()`
  /// rejects any other host so AURA can never be silently pointed at a
  /// remote Ollama instance.
  public var baseURL: String

  /// Timeout in seconds for a single inference request (`/api/generate` or
  /// `/api/chat`). Local models can take tens of seconds to load on first
  /// use, so this is deliberately generous.
  public var requestTimeoutSeconds: Double

  /// Timeout in seconds for the lightweight health probe (`/api/version`).
  public var healthCheckTimeoutSeconds: Double

  /// Soft ceiling on the combined `size_vram` of all currently resident
  /// models (per `/api/ps`) before a new model load is refused or a
  /// least-recently-used model is unloaded first. Defaults conservatively
  /// for the documented 16 GB unified-memory target profile, leaving
  /// headroom for STT/TTS/vision models running elsewhere in AURA.
  public var maxResidentModelBytes: UInt64

  /// Seconds an idle model is kept resident before Ollama unloads it,
  /// passed as `keep_alive` on every request.
  public var keepAliveSeconds: Double

  /// Whether models whose `/api/tags` entry reports a non-empty
  /// `remote_host` (Ollama's `:cloud` models, proxied to Ollama's hosted
  /// backend) may be used at all. `false` by default — "local does not mean
  /// safe" cuts both ways: a `:cloud`-suffixed name is a naming convention,
  /// not a contract, so routing decisions must key off the real
  /// `remote_host` field, and cloud-proxied inference must be an explicit
  /// opt-in, not a silent default.
  public var allowCloudModels: Bool

  /// Whether a new model load is refused while
  /// `ProcessInfo.processInfo.thermalState` is `.critical`.
  public var thermalAwarenessEnabled: Bool

  public init(
    baseURL: String = "http://127.0.0.1:11434",
    requestTimeoutSeconds: Double = 120.0,
    healthCheckTimeoutSeconds: Double = 5.0,
    maxResidentModelBytes: UInt64 = 6_000_000_000,
    keepAliveSeconds: Double = 300.0,
    allowCloudModels: Bool = false,
    thermalAwarenessEnabled: Bool = true
  ) {
    self.baseURL = baseURL
    self.requestTimeoutSeconds = requestTimeoutSeconds
    self.healthCheckTimeoutSeconds = healthCheckTimeoutSeconds
    self.maxResidentModelBytes = maxResidentModelBytes
    self.keepAliveSeconds = keepAliveSeconds
    self.allowCloudModels = allowCloudModels
    self.thermalAwarenessEnabled = thermalAwarenessEnabled
  }

  /// Hosts AURA will accept as the Ollama daemon's `baseURL`. Anything else
  /// is rejected by `validate()`.
  public static let allowedLoopbackHosts: Set<String> = ["127.0.0.1", "::1", "localhost"]

  public func validate() throws(AuraError) {
    guard !baseURL.isEmpty else {
      throw AuraError.invalidConfiguration("ollama baseURL must not be empty")
    }
    guard let url = URL(string: baseURL), let host = url.host, !host.isEmpty else {
      throw AuraError.invalidConfiguration("ollama baseURL must be a valid URL with a host")
    }
    guard Self.allowedLoopbackHosts.contains(host) else {
      throw AuraError.invalidConfiguration(
        "ollama baseURL host '\(host)' must be a loopback address (127.0.0.1, ::1, or localhost)")
    }
    guard requestTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("ollama requestTimeoutSeconds must be positive")
    }
    guard healthCheckTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("ollama healthCheckTimeoutSeconds must be positive")
    }
    guard maxResidentModelBytes > 0 else {
      throw AuraError.invalidConfiguration("ollama maxResidentModelBytes must be positive")
    }
    guard keepAliveSeconds >= 0 else {
      throw AuraError.invalidConfiguration("ollama keepAliveSeconds must be non-negative")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> OllamaConfiguration {
    OllamaConfiguration(
      baseURL: self.baseURL.isEmpty ? OllamaConfiguration().baseURL : self.baseURL,
      requestTimeoutSeconds: self.requestTimeoutSeconds <= 0
        ? OllamaConfiguration().requestTimeoutSeconds
        : self.requestTimeoutSeconds,
      healthCheckTimeoutSeconds: self.healthCheckTimeoutSeconds <= 0
        ? OllamaConfiguration().healthCheckTimeoutSeconds
        : self.healthCheckTimeoutSeconds,
      maxResidentModelBytes: self.maxResidentModelBytes == 0
        ? OllamaConfiguration().maxResidentModelBytes
        : self.maxResidentModelBytes,
      keepAliveSeconds: self.keepAliveSeconds < 0
        ? OllamaConfiguration().keepAliveSeconds
        : self.keepAliveSeconds,
      allowCloudModels: self.allowCloudModels,
      thermalAwarenessEnabled: self.thermalAwarenessEnabled
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    baseURL =
      try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "http://127.0.0.1:11434"
    requestTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .requestTimeoutSeconds) ?? 120.0
    healthCheckTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .healthCheckTimeoutSeconds) ?? 5.0
    maxResidentModelBytes =
      try container.decodeIfPresent(UInt64.self, forKey: .maxResidentModelBytes) ?? 6_000_000_000
    keepAliveSeconds =
      try container.decodeIfPresent(Double.self, forKey: .keepAliveSeconds) ?? 300.0
    allowCloudModels =
      try container.decodeIfPresent(Bool.self, forKey: .allowCloudModels) ?? false
    thermalAwarenessEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .thermalAwarenessEnabled) ?? true
  }
}

/// Configuration for `WorktreeManager`'s isolated `git worktree` lifecycle,
/// used by `MultiAgentOrchestrator` to give each mutable orchestration task
/// its own working directory.
public struct WorktreeConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `git` executable.
  public var gitExecutablePath: String

  /// Default timeout in seconds for a single `git worktree`/`git diff`
  /// invocation.
  public var defaultTimeoutSeconds: Double

  /// Branch name prefix for orchestration-created branches; the task ID is
  /// appended to form the full branch name.
  public var branchPrefix: String

  /// Name of the directory (relative to a repository's root) under which
  /// per-task worktrees are created. Operators should add this to the
  /// repository's `.gitignore`.
  public var worktreeDirectoryName: String

  /// Directories a repository root or worktree path must fall under.
  ///
  /// Unlike `CodexConfiguration.allowedWorkingDirectories` (which is only
  /// ever compared against a literal repository root), worktree operations
  /// always operate on nested subdirectories (`<repositoryRoot>/
  /// <worktreeDirectoryName>/<taskID>`), and `Command.validate`'s own
  /// allowlist check (`ShellConfiguration.allowedWorkingDirectories`, applied
  /// via `derivedShellConfiguration()`) is exact-match unless a pattern ends
  /// in `*`. The defaults here therefore use trailing-wildcard patterns so a
  /// real project directory anywhere under `$HOME`/`$TMPDIR` — and its
  /// worktrees — are actually reachable, not just the literal home directory
  /// itself.
  public var allowedWorkingDirectories: Set<String>

  public init(
    gitExecutablePath: String = "/usr/bin/git",
    defaultTimeoutSeconds: Double = 60.0,
    branchPrefix: String = "aura/orchestration-",
    worktreeDirectoryName: String = ".aura-worktrees",
    allowedWorkingDirectories: Set<String> = [
      "$HOME/*",
      "$TMPDIR/*",
    ]
  ) {
    self.gitExecutablePath = gitExecutablePath
    self.defaultTimeoutSeconds = defaultTimeoutSeconds
    self.branchPrefix = branchPrefix
    self.worktreeDirectoryName = worktreeDirectoryName
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  /// The directory under which per-task worktrees for `repositoryRoot` are
  /// created: `<repositoryRoot>/<worktreeDirectoryName>`.
  public func worktreeRoot(for repositoryRoot: String) -> String {
    (repositoryRoot as NSString).appendingPathComponent(worktreeDirectoryName)
  }

  public func validate() throws(AuraError) {
    guard !gitExecutablePath.isEmpty else {
      throw AuraError.invalidConfiguration("worktree gitExecutablePath must not be empty")
    }
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("worktree defaultTimeoutSeconds must be positive")
    }
    guard !branchPrefix.isEmpty else {
      throw AuraError.invalidConfiguration("worktree branchPrefix must not be empty")
    }
    guard !worktreeDirectoryName.isEmpty else {
      throw AuraError.invalidConfiguration("worktree worktreeDirectoryName must not be empty")
    }
    guard !allowedWorkingDirectories.isEmpty else {
      throw AuraError.invalidConfiguration("worktree allowedWorkingDirectories must not be empty")
    }
  }

  /// A `ShellConfiguration` scoped to only ever launch the configured `git`
  /// binary, mirroring `CodexConfiguration.derivedShellConfiguration()`.
  public func derivedShellConfiguration() -> ShellConfiguration {
    ShellConfiguration(
      defaultTimeoutSeconds: defaultTimeoutSeconds,
      allowedExecutablePaths: [gitExecutablePath],
      allowedWorkingDirectories: allowedWorkingDirectories
    )
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> WorktreeConfiguration {
    WorktreeConfiguration(
      gitExecutablePath: self.gitExecutablePath.isEmpty
        ? WorktreeConfiguration().gitExecutablePath
        : self.gitExecutablePath,
      defaultTimeoutSeconds: self.defaultTimeoutSeconds <= 0
        ? WorktreeConfiguration().defaultTimeoutSeconds
        : self.defaultTimeoutSeconds,
      branchPrefix: self.branchPrefix.isEmpty
        ? WorktreeConfiguration().branchPrefix
        : self.branchPrefix,
      worktreeDirectoryName: self.worktreeDirectoryName.isEmpty
        ? WorktreeConfiguration().worktreeDirectoryName
        : self.worktreeDirectoryName,
      allowedWorkingDirectories: self.allowedWorkingDirectories.isEmpty
        ? WorktreeConfiguration().allowedWorkingDirectories
        : self.allowedWorkingDirectories
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    gitExecutablePath =
      try container.decodeIfPresent(String.self, forKey: .gitExecutablePath) ?? "/usr/bin/git"
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 60.0
    branchPrefix =
      try container.decodeIfPresent(String.self, forKey: .branchPrefix) ?? "aura/orchestration-"
    worktreeDirectoryName =
      try container.decodeIfPresent(String.self, forKey: .worktreeDirectoryName)
      ?? ".aura-worktrees"
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories) ?? [
        "$HOME/*", "$TMPDIR/*",
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

/// Configuration for `ScreenContextEngine` (Phase 17) — off-by-default
/// capture, sensitive-app/self exclusion, redaction thresholds, and
/// diagnostic raw-frame retention (governed by `PrivacyConfiguration.
/// screenshotRetentionDays`, not a duplicate field here).
public struct ScreenContextConfiguration: Codable, Sendable, Equatable {
  /// Master switch. Screen capture is off until this is explicitly set —
  /// "off until granted and actively needed."
  public var enabled: Bool

  /// Application bundle identifiers that must never be captured: password
  /// managers, Notification Center, and system security surfaces.
  public var sensitiveApplicationBundleIdentifiers: Set<String>

  /// Rectangular regions (normalized `[0, 1]`, window-relative) that are
  /// always redacted regardless of recognized content.
  public var userDefinedRedactionRegions: [UserDefinedRedactionRegion]

  /// Regex-based patterns applied to OCR-recognized text to catch financial
  /// data, authentication codes, and other configured secret shapes.
  public var redactionPatterns: [RedactionRule]

  /// Whether OCR-based text redaction runs at all. Disabling this leaves
  /// only sensitive-app exclusion and user-defined-region redaction active —
  /// a deliberate degrade path, not a silent capability loss, if Vision text
  /// recognition is ever unavailable or undesired.
  public var ocrRedactionEnabled: Bool

  /// Whether a captured raw image may be retained in memory for diagnostics.
  /// Off by default — "no retained screen data unless diagnostic opt-in."
  /// When enabled, retention duration is governed by the existing
  /// `PrivacyConfiguration.screenshotRetentionDays`, not a separate field.
  public var retainRawFrames: Bool

  /// Seconds after capture that an observation is still considered fresh.
  public var freshnessSeconds: Double

  /// Maximum width/height, in pixels, requested from the capture API —
  /// bounds both cost and the amount of detail retained even transiently.
  public var maxCaptureDimension: Int

  public init(
    enabled: Bool = false,
    sensitiveApplicationBundleIdentifiers: Set<String> = [
      "com.apple.keychainaccess",
      "com.apple.SecurityAgent",
      "com.apple.notificationcenterui",
      "com.1password.1password",
      "com.agilebits.onepassword7",
      "com.bitwarden.desktop",
      "com.lastpass.LastPass",
      "com.dashlane.dashlanephonefinal",
    ],
    userDefinedRedactionRegions: [UserDefinedRedactionRegion] = [],
    redactionPatterns: [RedactionRule] = ScreenContextConfiguration.defaultRedactionPatterns,
    ocrRedactionEnabled: Bool = true,
    retainRawFrames: Bool = false,
    freshnessSeconds: Double = 5.0,
    maxCaptureDimension: Int = 2048
  ) {
    self.enabled = enabled
    self.sensitiveApplicationBundleIdentifiers = sensitiveApplicationBundleIdentifiers
    self.userDefinedRedactionRegions = userDefinedRedactionRegions
    self.redactionPatterns = redactionPatterns
    self.ocrRedactionEnabled = ocrRedactionEnabled
    self.retainRawFrames = retainRawFrames
    self.freshnessSeconds = freshnessSeconds
    self.maxCaptureDimension = maxCaptureDimension
  }

  /// Financial-data and authentication-code shapes, in addition to
  /// `OutputRedactor.default`'s generic secret-token patterns.
  public static let defaultRedactionPatterns: [RedactionRule] = [
    RedactionRule(pattern: "\\b(?:\\d[ -]*?){13,19}\\b", replacement: "<redacted-card-number>"),
    RedactionRule(pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b", replacement: "<redacted-ssn-shaped>"),
    RedactionRule(
      pattern: "\\b(?:[Cc]ode|OTP|otp)[:\\s]+\\d{4,8}\\b",
      replacement: "<redacted-auth-code>"),
    RedactionRule(pattern: "sk-[a-zA-Z0-9]{20,}", replacement: "<redacted-api-key>"),
    RedactionRule(
      pattern: "eyJ[A-Za-z0-9_-]*\\.eyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*",
      replacement: "<redacted-jwt>"),
  ]

  public func validate() throws(AuraError) {
    guard freshnessSeconds > 0 else {
      throw AuraError.invalidConfiguration("screen freshnessSeconds must be positive")
    }
    guard maxCaptureDimension > 0 else {
      throw AuraError.invalidConfiguration("screen maxCaptureDimension must be positive")
    }
    for region in userDefinedRedactionRegions {
      guard region.width > 0, region.height > 0 else {
        throw AuraError.invalidConfiguration(
          "screen userDefinedRedactionRegions entries must have positive width/height")
      }
      guard (0...1).contains(region.x), (0...1).contains(region.y) else {
        throw AuraError.invalidConfiguration(
          "screen userDefinedRedactionRegions entries must have x/y in [0, 1]")
      }
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> ScreenContextConfiguration {
    let defaults = ScreenContextConfiguration()
    return ScreenContextConfiguration(
      enabled: self.enabled,
      sensitiveApplicationBundleIdentifiers: self.sensitiveApplicationBundleIdentifiers.isEmpty
        ? defaults.sensitiveApplicationBundleIdentifiers
        : self.sensitiveApplicationBundleIdentifiers,
      userDefinedRedactionRegions: self.userDefinedRedactionRegions,
      redactionPatterns: self.redactionPatterns.isEmpty
        ? defaults.redactionPatterns
        : self.redactionPatterns,
      ocrRedactionEnabled: self.ocrRedactionEnabled,
      retainRawFrames: self.retainRawFrames,
      freshnessSeconds: self.freshnessSeconds <= 0
        ? defaults.freshnessSeconds
        : self.freshnessSeconds,
      maxCaptureDimension: self.maxCaptureDimension <= 0
        ? defaults.maxCaptureDimension
        : self.maxCaptureDimension
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = ScreenContextConfiguration()
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
    sensitiveApplicationBundleIdentifiers =
      try container.decodeIfPresent(
        Set<String>.self, forKey: .sensitiveApplicationBundleIdentifiers)
      ?? defaults.sensitiveApplicationBundleIdentifiers
    userDefinedRedactionRegions =
      try container.decodeIfPresent(
        [UserDefinedRedactionRegion].self, forKey: .userDefinedRedactionRegions)
      ?? defaults.userDefinedRedactionRegions
    redactionPatterns =
      try container.decodeIfPresent([RedactionRule].self, forKey: .redactionPatterns)
      ?? defaults.redactionPatterns
    ocrRedactionEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .ocrRedactionEnabled)
      ?? defaults.ocrRedactionEnabled
    retainRawFrames =
      try container.decodeIfPresent(Bool.self, forKey: .retainRawFrames) ?? defaults.retainRawFrames
    freshnessSeconds =
      try container.decodeIfPresent(Double.self, forKey: .freshnessSeconds)
      ?? defaults.freshnessSeconds
    maxCaptureDimension =
      try container.decodeIfPresent(Int.self, forKey: .maxCaptureDimension)
      ?? defaults.maxCaptureDimension
  }
}

/// Configuration for `ComputerUseControlLoop` (Phase 18) — iteration and
/// plan-size bounds, no-progress detection sensitivity, and action rate
/// limiting. Confirmation requirements for destructive intents are
/// deliberately *not* configurable here — see
/// `ComputerUseSemanticIntent.mandatoryConfirmationIntents`, a fixed
/// constant no configuration can relax.
public struct ComputerUseConfiguration: Codable, Sendable, Equatable {
  /// Hard ceiling on observe-plan-policy-act-verify iterations per session.
  public var maxIterations: Int

  /// Hard ceiling on action steps within a single proposed plan — "one
  /// bounded action or a short atomic sequence." A plan exceeding this is
  /// rejected outright, never silently truncated.
  public var maxStepsPerPlan: Int

  /// Consecutive iterations with no observable change (identical content
  /// hash) before the loop escalates to `.noProgress` instead of continuing
  /// indefinitely.
  public var noProgressIterationThreshold: Int

  /// Minimum seconds required between two consecutive executed action
  /// steps — bounds the action rate against the approved target.
  public var minActionIntervalSeconds: Double

  public init(
    maxIterations: Int = 25,
    maxStepsPerPlan: Int = 5,
    noProgressIterationThreshold: Int = 3,
    minActionIntervalSeconds: Double = 0.2
  ) {
    self.maxIterations = maxIterations
    self.maxStepsPerPlan = maxStepsPerPlan
    self.noProgressIterationThreshold = noProgressIterationThreshold
    self.minActionIntervalSeconds = minActionIntervalSeconds
  }

  public func validate() throws(AuraError) {
    guard maxIterations > 0 else {
      throw AuraError.invalidConfiguration("computerUse maxIterations must be positive")
    }
    guard maxStepsPerPlan > 0 else {
      throw AuraError.invalidConfiguration("computerUse maxStepsPerPlan must be positive")
    }
    guard noProgressIterationThreshold > 0 else {
      throw AuraError.invalidConfiguration(
        "computerUse noProgressIterationThreshold must be positive")
    }
    guard minActionIntervalSeconds >= 0 else {
      throw AuraError.invalidConfiguration(
        "computerUse minActionIntervalSeconds must not be negative")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> ComputerUseConfiguration {
    let defaults = ComputerUseConfiguration()
    return ComputerUseConfiguration(
      maxIterations: self.maxIterations <= 0 ? defaults.maxIterations : self.maxIterations,
      maxStepsPerPlan: self.maxStepsPerPlan <= 0
        ? defaults.maxStepsPerPlan : self.maxStepsPerPlan,
      noProgressIterationThreshold: self.noProgressIterationThreshold <= 0
        ? defaults.noProgressIterationThreshold : self.noProgressIterationThreshold,
      minActionIntervalSeconds: self.minActionIntervalSeconds < 0
        ? defaults.minActionIntervalSeconds : self.minActionIntervalSeconds
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = ComputerUseConfiguration()
    maxIterations =
      try container.decodeIfPresent(Int.self, forKey: .maxIterations) ?? defaults.maxIterations
    maxStepsPerPlan =
      try container.decodeIfPresent(Int.self, forKey: .maxStepsPerPlan)
      ?? defaults.maxStepsPerPlan
    noProgressIterationThreshold =
      try container.decodeIfPresent(Int.self, forKey: .noProgressIterationThreshold)
      ?? defaults.noProgressIterationThreshold
    minActionIntervalSeconds =
      try container.decodeIfPresent(Double.self, forKey: .minActionIntervalSeconds)
      ?? defaults.minActionIntervalSeconds
  }
}

/// Configuration for `ContextEngine` (Phase 16) — ranking weights, bundle
/// size budgets, semantic-match threshold, and reference-resolution
/// guardrails for the destructive-target-on-weak-evidence gate.
public struct ContextConfiguration: Codable, Sendable, Equatable {
  /// Ranking weight for scope match (project/task/session). All five
  /// `rankingWeight*` fields must be non-negative and sum to `1.0`.
  public var rankingWeightScope: Double
  /// Ranking weight for recency (exponential decay, see `recencyHalfLifeSeconds`).
  public var rankingWeightRecency: Double
  /// Ranking weight for provenance authority (`ContextAuthority`).
  public var rankingWeightAuthority: Double
  /// Ranking weight for the candidate's own confidence value.
  public var rankingWeightConfidence: Double
  /// Ranking weight for presence of direct evidence references.
  public var rankingWeightEvidence: Double

  /// Half-life, in seconds, of the recency score's exponential decay.
  public var recencyHalfLifeSeconds: Double

  /// Maximum number of project-ledger entries considered for a bundle.
  public var maxLedgerEntries: Int
  /// Maximum number of individual decisions (drawn from those ledger
  /// entries) considered for a bundle.
  public var maxDecisions: Int
  /// Maximum number of user-preference memory records considered.
  public var maxPreferences: Int
  /// Maximum number of semantic-retrieval matches considered.
  public var maxSemanticMatches: Int
  /// Maximum number of optional (non-mandatory) items kept in a bundle after
  /// ranking — the "minimal and sufficient" budget.
  public var maxBundleItems: Int

  /// Minimum keyword-containment score (see `ContextRanking.containmentScore`)
  /// for a memory record to count as a semantic-retrieval match.
  public var semanticMatchMinimumOverlap: Double

  /// Minimum score gap between the top two reference candidates required to
  /// treat resolution as unambiguous.
  public var referenceSeparationMargin: Double
  /// Minimum confidence a guarded-tier reference candidate must have before
  /// it can auto-resolve.
  public var referenceGuardedMinimumConfidence: Double
  /// The lowest `PermissionRiskTier` at which a reference candidate is
  /// "guarded" — auto-resolution requires an unambiguous top candidate,
  /// direct evidence, non-inferred authority, in-scope, and confidence at or
  /// above `referenceGuardedMinimumConfidence`. Below this tier, an
  /// unambiguous top candidate resolves without the extra evidence checks.
  public var referenceGuardedTierThreshold: PermissionRiskTier
  /// Additional Phase 22 reference-graph weight for turn-local
  /// conversational salience. It supplements (and never bypasses) the five
  /// evidence-ranking dimensions.
  public var referenceSalienceWeight: Double
  /// Hard estimated-token ceiling for a final deep-context bundle.
  public var maxTokenBudget: Int
  /// Maximum provenance hops followed from any included memory record.
  public var maxGraphDepth: Int
  /// Maximum graph-derived context nodes admitted across the whole bundle.
  public var maxGraphItems: Int
  /// Measured local lookup budget. Exceeding it is reported in the result
  /// and audit event; no claim of meeting the budget is made unless tested.
  public var lookupLatencyBudgetSeconds: Double

  public init(
    rankingWeightScope: Double = 0.30,
    rankingWeightRecency: Double = 0.25,
    rankingWeightAuthority: Double = 0.20,
    rankingWeightConfidence: Double = 0.15,
    rankingWeightEvidence: Double = 0.10,
    recencyHalfLifeSeconds: Double = 3600,
    maxLedgerEntries: Int = 5,
    maxDecisions: Int = 5,
    maxPreferences: Int = 5,
    maxSemanticMatches: Int = 3,
    maxBundleItems: Int = 12,
    semanticMatchMinimumOverlap: Double = 0.34,
    referenceSeparationMargin: Double = 0.12,
    referenceGuardedMinimumConfidence: Double = 0.85,
    referenceGuardedTierThreshold: PermissionRiskTier = .mutation,
    referenceSalienceWeight: Double = 0.15,
    maxTokenBudget: Int = 1_024,
    maxGraphDepth: Int = 4,
    maxGraphItems: Int = 12,
    lookupLatencyBudgetSeconds: Double = 0.25
  ) {
    self.rankingWeightScope = rankingWeightScope
    self.rankingWeightRecency = rankingWeightRecency
    self.rankingWeightAuthority = rankingWeightAuthority
    self.rankingWeightConfidence = rankingWeightConfidence
    self.rankingWeightEvidence = rankingWeightEvidence
    self.recencyHalfLifeSeconds = recencyHalfLifeSeconds
    self.maxLedgerEntries = maxLedgerEntries
    self.maxDecisions = maxDecisions
    self.maxPreferences = maxPreferences
    self.maxSemanticMatches = maxSemanticMatches
    self.maxBundleItems = maxBundleItems
    self.semanticMatchMinimumOverlap = semanticMatchMinimumOverlap
    self.referenceSeparationMargin = referenceSeparationMargin
    self.referenceGuardedMinimumConfidence = referenceGuardedMinimumConfidence
    self.referenceGuardedTierThreshold = referenceGuardedTierThreshold
    self.referenceSalienceWeight = referenceSalienceWeight
    self.maxTokenBudget = maxTokenBudget
    self.maxGraphDepth = maxGraphDepth
    self.maxGraphItems = maxGraphItems
    self.lookupLatencyBudgetSeconds = lookupLatencyBudgetSeconds
  }

  private var rankingWeights: [Double] {
    [
      rankingWeightScope, rankingWeightRecency, rankingWeightAuthority, rankingWeightConfidence,
      rankingWeightEvidence,
    ]
  }

  public func validate() throws(AuraError) {
    guard rankingWeights.allSatisfy({ $0 >= 0 }) else {
      throw AuraError.invalidConfiguration("context ranking weights must be non-negative")
    }
    let sum = rankingWeights.reduce(0, +)
    guard abs(sum - 1.0) < 0.0001 else {
      throw AuraError.invalidConfiguration("context ranking weights must sum to 1.0, got \(sum)")
    }
    guard recencyHalfLifeSeconds > 0 else {
      throw AuraError.invalidConfiguration("context recencyHalfLifeSeconds must be positive")
    }
    guard maxLedgerEntries > 0 else {
      throw AuraError.invalidConfiguration("context maxLedgerEntries must be positive")
    }
    guard maxDecisions > 0 else {
      throw AuraError.invalidConfiguration("context maxDecisions must be positive")
    }
    guard maxPreferences > 0 else {
      throw AuraError.invalidConfiguration("context maxPreferences must be positive")
    }
    guard maxSemanticMatches > 0 else {
      throw AuraError.invalidConfiguration("context maxSemanticMatches must be positive")
    }
    guard referenceSalienceWeight >= 0 else {
      throw AuraError.invalidConfiguration("context referenceSalienceWeight must be non-negative")
    }
    guard maxTokenBudget > 0 else {
      throw AuraError.invalidConfiguration("context maxTokenBudget must be positive")
    }
    guard maxGraphDepth >= 0 else {
      throw AuraError.invalidConfiguration("context maxGraphDepth must be non-negative")
    }
    guard maxGraphItems >= 0 else {
      throw AuraError.invalidConfiguration("context maxGraphItems must be non-negative")
    }
    guard lookupLatencyBudgetSeconds > 0 else {
      throw AuraError.invalidConfiguration(
        "context lookupLatencyBudgetSeconds must be positive")
    }
    guard maxBundleItems > 0 else {
      throw AuraError.invalidConfiguration("context maxBundleItems must be positive")
    }
    guard semanticMatchMinimumOverlap > 0, semanticMatchMinimumOverlap <= 1 else {
      throw AuraError.invalidConfiguration(
        "context semanticMatchMinimumOverlap must be in (0, 1]")
    }
    guard referenceSeparationMargin >= 0 else {
      throw AuraError.invalidConfiguration("context referenceSeparationMargin must be non-negative")
    }
    guard referenceGuardedMinimumConfidence >= 0, referenceGuardedMinimumConfidence <= 1 else {
      throw AuraError.invalidConfiguration(
        "context referenceGuardedMinimumConfidence must be in [0, 1]")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults. The five
  /// ranking weights are merged as one group — a partially-overridden weight
  /// vector cannot preserve the "sums to 1.0" invariant, so any invalid
  /// (negative, or non-summing-to-1.0) group falls back to the full default
  /// set together rather than field by field.
  public func mergedWithDefaults() -> ContextConfiguration {
    let defaults = ContextConfiguration()
    let weightsValid =
      rankingWeights.allSatisfy { $0 >= 0 } && abs(rankingWeights.reduce(0, +) - 1.0) < 0.0001
    return ContextConfiguration(
      rankingWeightScope: weightsValid ? rankingWeightScope : defaults.rankingWeightScope,
      rankingWeightRecency: weightsValid ? rankingWeightRecency : defaults.rankingWeightRecency,
      rankingWeightAuthority: weightsValid
        ? rankingWeightAuthority : defaults.rankingWeightAuthority,
      rankingWeightConfidence: weightsValid
        ? rankingWeightConfidence : defaults.rankingWeightConfidence,
      rankingWeightEvidence: weightsValid ? rankingWeightEvidence : defaults.rankingWeightEvidence,
      recencyHalfLifeSeconds: recencyHalfLifeSeconds <= 0
        ? defaults.recencyHalfLifeSeconds : recencyHalfLifeSeconds,
      maxLedgerEntries: maxLedgerEntries <= 0 ? defaults.maxLedgerEntries : maxLedgerEntries,
      maxDecisions: maxDecisions <= 0 ? defaults.maxDecisions : maxDecisions,
      maxPreferences: maxPreferences <= 0 ? defaults.maxPreferences : maxPreferences,
      maxSemanticMatches: maxSemanticMatches <= 0
        ? defaults.maxSemanticMatches : maxSemanticMatches,
      maxBundleItems: maxBundleItems <= 0 ? defaults.maxBundleItems : maxBundleItems,
      semanticMatchMinimumOverlap: (semanticMatchMinimumOverlap <= 0
        || semanticMatchMinimumOverlap > 1)
        ? defaults.semanticMatchMinimumOverlap : semanticMatchMinimumOverlap,
      referenceSeparationMargin: referenceSeparationMargin < 0
        ? defaults.referenceSeparationMargin : referenceSeparationMargin,
      referenceGuardedMinimumConfidence: (referenceGuardedMinimumConfidence < 0
        || referenceGuardedMinimumConfidence > 1)
        ? defaults.referenceGuardedMinimumConfidence : referenceGuardedMinimumConfidence,
      referenceGuardedTierThreshold: referenceGuardedTierThreshold,
      referenceSalienceWeight: referenceSalienceWeight < 0
        ? defaults.referenceSalienceWeight : referenceSalienceWeight,
      maxTokenBudget: maxTokenBudget <= 0 ? defaults.maxTokenBudget : maxTokenBudget,
      maxGraphDepth: maxGraphDepth < 0 ? defaults.maxGraphDepth : maxGraphDepth,
      maxGraphItems: maxGraphItems < 0 ? defaults.maxGraphItems : maxGraphItems,
      lookupLatencyBudgetSeconds: lookupLatencyBudgetSeconds <= 0
        ? defaults.lookupLatencyBudgetSeconds : lookupLatencyBudgetSeconds
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = ContextConfiguration()
    rankingWeightScope =
      try container.decodeIfPresent(Double.self, forKey: .rankingWeightScope)
      ?? defaults.rankingWeightScope
    rankingWeightRecency =
      try container.decodeIfPresent(Double.self, forKey: .rankingWeightRecency)
      ?? defaults.rankingWeightRecency
    rankingWeightAuthority =
      try container.decodeIfPresent(Double.self, forKey: .rankingWeightAuthority)
      ?? defaults.rankingWeightAuthority
    rankingWeightConfidence =
      try container.decodeIfPresent(Double.self, forKey: .rankingWeightConfidence)
      ?? defaults.rankingWeightConfidence
    rankingWeightEvidence =
      try container.decodeIfPresent(Double.self, forKey: .rankingWeightEvidence)
      ?? defaults.rankingWeightEvidence
    recencyHalfLifeSeconds =
      try container.decodeIfPresent(Double.self, forKey: .recencyHalfLifeSeconds)
      ?? defaults.recencyHalfLifeSeconds
    maxLedgerEntries =
      try container.decodeIfPresent(Int.self, forKey: .maxLedgerEntries)
      ?? defaults.maxLedgerEntries
    maxDecisions =
      try container.decodeIfPresent(Int.self, forKey: .maxDecisions) ?? defaults.maxDecisions
    maxPreferences =
      try container.decodeIfPresent(Int.self, forKey: .maxPreferences) ?? defaults.maxPreferences
    maxSemanticMatches =
      try container.decodeIfPresent(Int.self, forKey: .maxSemanticMatches)
      ?? defaults.maxSemanticMatches
    maxBundleItems =
      try container.decodeIfPresent(Int.self, forKey: .maxBundleItems) ?? defaults.maxBundleItems
    semanticMatchMinimumOverlap =
      try container.decodeIfPresent(Double.self, forKey: .semanticMatchMinimumOverlap)
      ?? defaults.semanticMatchMinimumOverlap
    referenceSeparationMargin =
      try container.decodeIfPresent(Double.self, forKey: .referenceSeparationMargin)
      ?? defaults.referenceSeparationMargin
    referenceGuardedMinimumConfidence =
      try container.decodeIfPresent(Double.self, forKey: .referenceGuardedMinimumConfidence)
      ?? defaults.referenceGuardedMinimumConfidence
    referenceGuardedTierThreshold =
      try container.decodeIfPresent(PermissionRiskTier.self, forKey: .referenceGuardedTierThreshold)
      ?? defaults.referenceGuardedTierThreshold
    referenceSalienceWeight =
      try container.decodeIfPresent(Double.self, forKey: .referenceSalienceWeight)
      ?? defaults.referenceSalienceWeight
    maxTokenBudget =
      try container.decodeIfPresent(Int.self, forKey: .maxTokenBudget) ?? defaults.maxTokenBudget
    maxGraphDepth =
      try container.decodeIfPresent(Int.self, forKey: .maxGraphDepth) ?? defaults.maxGraphDepth
    maxGraphItems =
      try container.decodeIfPresent(Int.self, forKey: .maxGraphItems) ?? defaults.maxGraphItems
    lookupLatencyBudgetSeconds =
      try container.decodeIfPresent(Double.self, forKey: .lookupLatencyBudgetSeconds)
      ?? defaults.lookupLatencyBudgetSeconds
  }
}

/// Configuration for `AuraSecurity` (Phase 19) — the Keychain-backed secret
/// store, the deterministic prompt-injection classifier, and the outbound
/// network domain allowlist. `Ollama`'s own network egress is governed
/// separately and more strictly by `OllamaConfiguration.allowedLoopbackHosts`
/// (a host-family restriction, not a domain list); `networkAllowlist` here
/// is for any future non-loopback network capability.
public struct SecurityConfiguration: Codable, Sendable, Equatable {
  /// Keychain service name secrets are stored under. Namespaced by the app
  /// bundle identifier so a Keychain search never leaks across apps.
  public var secretKeychainServiceName: String

  /// Host allowlist for outbound network requests evaluated through
  /// `NetworkAllowlist`. Deny-by-default: empty means no host is allowed.
  /// A leading `*.` matches any subdomain (e.g. `*.githubusercontent.com`).
  public var networkAllowlist: Set<String>

  /// Whether `PromptInjectionClassifier` is consulted at all. `false` only
  /// for narrow diagnostic scenarios; production defaults to `true`.
  public var injectionClassifierEnabled: Bool

  /// Cumulative matched-rule severity at or above which a classification is
  /// `.blocked` rather than merely `.suspicious`.
  public var injectionBlockSeverityThreshold: Int

  public init(
    secretKeychainServiceName: String = "ai.aura.local.secrets",
    networkAllowlist: Set<String> = [],
    injectionClassifierEnabled: Bool = true,
    injectionBlockSeverityThreshold: Int = 3
  ) {
    self.secretKeychainServiceName = secretKeychainServiceName
    self.networkAllowlist = networkAllowlist
    self.injectionClassifierEnabled = injectionClassifierEnabled
    self.injectionBlockSeverityThreshold = injectionBlockSeverityThreshold
  }

  public func validate() throws(AuraError) {
    guard !secretKeychainServiceName.isEmpty else {
      throw AuraError.invalidConfiguration("security secretKeychainServiceName must not be empty")
    }
    guard injectionBlockSeverityThreshold > 0 else {
      throw AuraError.invalidConfiguration(
        "security injectionBlockSeverityThreshold must be positive")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> SecurityConfiguration {
    SecurityConfiguration(
      secretKeychainServiceName: self.secretKeychainServiceName.isEmpty
        ? SecurityConfiguration().secretKeychainServiceName
        : self.secretKeychainServiceName,
      networkAllowlist: self.networkAllowlist,
      injectionClassifierEnabled: self.injectionClassifierEnabled,
      injectionBlockSeverityThreshold: self.injectionBlockSeverityThreshold <= 0
        ? SecurityConfiguration().injectionBlockSeverityThreshold
        : self.injectionBlockSeverityThreshold
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = SecurityConfiguration()
    secretKeychainServiceName =
      try container.decodeIfPresent(String.self, forKey: .secretKeychainServiceName)
      ?? defaults.secretKeychainServiceName
    networkAllowlist =
      try container.decodeIfPresent(Set<String>.self, forKey: .networkAllowlist)
      ?? defaults.networkAllowlist
    injectionClassifierEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .injectionClassifierEnabled)
      ?? defaults.injectionClassifierEnabled
    injectionBlockSeverityThreshold =
      try container.decodeIfPresent(Int.self, forKey: .injectionBlockSeverityThreshold)
      ?? defaults.injectionBlockSeverityThreshold
  }
}

/// Configuration for `AuraPlugins` (Phase 19 foundation, Phase 23 runtime)
/// — manifest verification, lifecycle, artifacts, and the isolated helper.
/// `trustedVendorPublicKeysBase64` is
/// deny-by-default (empty): a vendor must be explicitly added before any of
/// its plugins can pass `PluginVerifier`, matching the deny-by-default
/// posture used everywhere else in the policy engine.
public struct PluginConfiguration: Codable, Sendable, Equatable {
  /// Vendor display name → base64-encoded 32-byte raw Curve25519 (Ed25519)
  /// signing public key. A plugin manifest's `vendorName` must have a key
  /// here for its signature to ever verify.
  public var trustedVendorPublicKeysBase64: [String: String]
  /// `"normalized vendor#keyID"` → base64 Ed25519 public key. This is the
  /// Phase 23 rotation-capable trust map; the vendor-only map above remains
  /// as a `#default` migration surface.
  public var trustedVendorPublicKeysByKeyIDBase64: [String: String]

  /// Store key under which the plugin registry's lifecycle state is
  /// persisted, mirroring `PolicyConfiguration.grantStoreKey`'s convention.
  public var registryStoreKey: String
  /// Versioned plugin payload root. Empty means runtime installation is
  /// unavailable and execution fails closed.
  public var artifactRootPath: String
  /// Fixed AURA-owned sandboxed helper executable. Empty disables runtime.
  public var helperExecutablePath: String
  /// Pinned lowercase SHA-256 of the helper executable.
  public var helperSHA256Hex: String

  public init(
    trustedVendorPublicKeysBase64: [String: String] = [:],
    trustedVendorPublicKeysByKeyIDBase64: [String: String] = [:],
    registryStoreKey: String = "aura.plugins.registry",
    artifactRootPath: String = "",
    helperExecutablePath: String = "",
    helperSHA256Hex: String = ""
  ) {
    self.trustedVendorPublicKeysBase64 = trustedVendorPublicKeysBase64
    self.trustedVendorPublicKeysByKeyIDBase64 = trustedVendorPublicKeysByKeyIDBase64
    self.registryStoreKey = registryStoreKey
    self.artifactRootPath = artifactRootPath
    self.helperExecutablePath = helperExecutablePath
    self.helperSHA256Hex = helperSHA256Hex
  }

  public func validate() throws(AuraError) {
    guard !registryStoreKey.isEmpty else {
      throw AuraError.invalidConfiguration("plugins registryStoreKey must not be empty")
    }
    let helperFields = [helperExecutablePath, helperSHA256Hex]
    guard helperFields.allSatisfy(\.isEmpty) || helperFields.allSatisfy({ !$0.isEmpty }) else {
      throw AuraError.invalidConfiguration(
        "plugins helperExecutablePath and helperSHA256Hex must be configured together")
    }
    if !helperSHA256Hex.isEmpty {
      guard helperSHA256Hex.count == 64,
        helperSHA256Hex == helperSHA256Hex.lowercased(),
        helperSHA256Hex.allSatisfy(\.isHexDigit)
      else {
        throw AuraError.invalidConfiguration(
          "plugins helperSHA256Hex must be 64 lowercase hex characters")
      }
    }
    for (vendor, keyBase64) in trustedVendorPublicKeysBase64 {
      guard !vendor.isEmpty else {
        throw AuraError.invalidConfiguration(
          "plugins trustedVendorPublicKeysBase64 has an empty vendor name")
      }
      guard let data = Data(base64Encoded: keyBase64), data.count == 32 else {
        throw AuraError.invalidConfiguration(
          "plugins trustedVendorPublicKeysBase64[\(vendor)] must be a base64-encoded 32-byte Curve25519 public key"
        )
      }
    }
    for (vendorAndKeyID, keyBase64) in trustedVendorPublicKeysByKeyIDBase64 {
      let parts = vendorAndKeyID.split(separator: "#", omittingEmptySubsequences: false)
      guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else {
        throw AuraError.invalidConfiguration(
          "plugins trustedVendorPublicKeysByKeyIDBase64 keys must be vendor#keyID")
      }
      guard let data = Data(base64Encoded: keyBase64), data.count == 32 else {
        throw AuraError.invalidConfiguration(
          "plugins trustedVendorPublicKeysByKeyIDBase64[\(vendorAndKeyID)] must be a base64-encoded 32-byte Curve25519 public key"
        )
      }
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> PluginConfiguration {
    PluginConfiguration(
      trustedVendorPublicKeysBase64: self.trustedVendorPublicKeysBase64,
      trustedVendorPublicKeysByKeyIDBase64: self.trustedVendorPublicKeysByKeyIDBase64,
      registryStoreKey: self.registryStoreKey.isEmpty
        ? PluginConfiguration().registryStoreKey
        : self.registryStoreKey,
      artifactRootPath: self.artifactRootPath,
      helperExecutablePath: self.helperExecutablePath,
      helperSHA256Hex: self.helperSHA256Hex
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = PluginConfiguration()
    trustedVendorPublicKeysBase64 =
      try container.decodeIfPresent([String: String].self, forKey: .trustedVendorPublicKeysBase64)
      ?? defaults.trustedVendorPublicKeysBase64
    trustedVendorPublicKeysByKeyIDBase64 =
      try container.decodeIfPresent(
        [String: String].self, forKey: .trustedVendorPublicKeysByKeyIDBase64)
      ?? defaults.trustedVendorPublicKeysByKeyIDBase64
    registryStoreKey =
      try container.decodeIfPresent(String.self, forKey: .registryStoreKey)
      ?? defaults.registryStoreKey
    artifactRootPath =
      try container.decodeIfPresent(String.self, forKey: .artifactRootPath)
      ?? defaults.artifactRootPath
    helperExecutablePath =
      try container.decodeIfPresent(String.self, forKey: .helperExecutablePath)
      ?? defaults.helperExecutablePath
    helperSHA256Hex =
      try container.decodeIfPresent(String.self, forKey: .helperSHA256Hex)
      ?? defaults.helperSHA256Hex
  }
}

/// Configuration for `IntentEngine`/`ToolRouter` (`AuraIntent`) — the
/// classifier's confidence gate, the default coding-agent backend/working
/// directory a `.codingAgentRun` intent uses, and the conservative
/// destructive-shell pattern denylist `ToolRouter` checks before a
/// `.shellExecute` intent is allowed to remain at that (non-destructive)
/// tier.
public struct IntentEngineConfiguration: Codable, Sendable, Equatable {
  /// Below this classification confidence, an intent is forced to
  /// `.unknown`/`isAmbiguous` regardless of what the classifier proposed.
  public var minimumClassificationConfidence: Double

  /// Which `AgentBackendTaskRunner`-registered backend a `.codingAgentRun`
  /// intent uses when the utterance does not name one explicitly.
  public var defaultCodingAgentBackend: String

  /// Working directory a `.codingAgentRun` task is enqueued against when
  /// the utterance does not name one explicitly.
  public var defaultCodingAgentWorkingDirectory: String

  /// Seconds a clarification slot remains eligible for a follow-up answer.
  public var clarificationExpirySeconds: Double

  /// Regex patterns that, when matched against a shell intent's executable
  /// plus arguments, escalate it from `.shellExecute` to `.shellDestructive`
  /// (`Capability.shellExecDestructive`, no grant seeded by default). A
  /// deliberately small, conservative, defense-in-depth list — never the
  /// only thing standing between a shell intent and execution, since plain
  /// `.shellExecute` already requires `.always` confirmation by default.
  public var destructiveShellPatterns: [String]

  public init(
    minimumClassificationConfidence: Double = 0.6,
    defaultCodingAgentBackend: String = "codex",
    defaultCodingAgentWorkingDirectory: String = "$HOME",
    clarificationExpirySeconds: Double = 60,
    destructiveShellPatterns: [String] = [
      "rm\\s+-[a-zA-Z]*[rf][a-zA-Z]*[rf]",
      "diskutil\\s+(erase|reformat|partitionDisk)",
      "dd\\s+.*of=/dev/",
      ":\\(\\)\\s*\\{\\s*:\\|:&\\s*\\}\\s*;\\s*:",
    ]
  ) {
    self.minimumClassificationConfidence = minimumClassificationConfidence
    self.defaultCodingAgentBackend = defaultCodingAgentBackend
    self.defaultCodingAgentWorkingDirectory = defaultCodingAgentWorkingDirectory
    self.clarificationExpirySeconds = clarificationExpirySeconds
    self.destructiveShellPatterns = destructiveShellPatterns
  }

  public func validate() throws(AuraError) {
    guard minimumClassificationConfidence >= 0, minimumClassificationConfidence <= 1 else {
      throw AuraError.invalidConfiguration(
        "intent minimumClassificationConfidence must be in [0, 1]")
    }
    guard !defaultCodingAgentBackend.isEmpty else {
      throw AuraError.invalidConfiguration("intent defaultCodingAgentBackend must not be empty")
    }
    guard !defaultCodingAgentWorkingDirectory.isEmpty else {
      throw AuraError.invalidConfiguration(
        "intent defaultCodingAgentWorkingDirectory must not be empty")
    }
    guard clarificationExpirySeconds > 0 else {
      throw AuraError.invalidConfiguration("intent clarificationExpirySeconds must be positive")
    }
    for pattern in destructiveShellPatterns {
      guard !pattern.isEmpty else {
        throw AuraError.invalidConfiguration(
          "intent destructiveShellPatterns must not contain empty patterns")
      }
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> IntentEngineConfiguration {
    IntentEngineConfiguration(
      minimumClassificationConfidence: (self.minimumClassificationConfidence < 0
        || self.minimumClassificationConfidence > 1)
        ? IntentEngineConfiguration().minimumClassificationConfidence
        : self.minimumClassificationConfidence,
      defaultCodingAgentBackend: self.defaultCodingAgentBackend.isEmpty
        ? IntentEngineConfiguration().defaultCodingAgentBackend
        : self.defaultCodingAgentBackend,
      defaultCodingAgentWorkingDirectory: self.defaultCodingAgentWorkingDirectory.isEmpty
        ? IntentEngineConfiguration().defaultCodingAgentWorkingDirectory
        : self.defaultCodingAgentWorkingDirectory,
      clarificationExpirySeconds: self.clarificationExpirySeconds <= 0
        ? IntentEngineConfiguration().clarificationExpirySeconds
        : self.clarificationExpirySeconds,
      destructiveShellPatterns: self.destructiveShellPatterns.isEmpty
        ? IntentEngineConfiguration().destructiveShellPatterns
        : self.destructiveShellPatterns
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = IntentEngineConfiguration()
    minimumClassificationConfidence =
      try container.decodeIfPresent(Double.self, forKey: .minimumClassificationConfidence)
      ?? defaults.minimumClassificationConfidence
    defaultCodingAgentBackend =
      try container.decodeIfPresent(String.self, forKey: .defaultCodingAgentBackend)
      ?? defaults.defaultCodingAgentBackend
    defaultCodingAgentWorkingDirectory =
      try container.decodeIfPresent(String.self, forKey: .defaultCodingAgentWorkingDirectory)
      ?? defaults.defaultCodingAgentWorkingDirectory
    clarificationExpirySeconds =
      try container.decodeIfPresent(Double.self, forKey: .clarificationExpirySeconds)
      ?? defaults.clarificationExpirySeconds
    destructiveShellPatterns =
      try container.decodeIfPresent([String].self, forKey: .destructiveShellPatterns)
      ?? defaults.destructiveShellPatterns
  }
}
