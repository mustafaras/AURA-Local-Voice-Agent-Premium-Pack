import Foundation

extension AuraConfiguration {
  /// Default configuration for bootstrap and tests. Remains neutral so unit
  /// tests and production launches never carry a real account or test flag.
  public static var `default`: AuraConfiguration { AuraConfiguration() }

  /// Configuration used only for the SP-011 Productivity Live Acceptance run.
  /// Enabled by setting `AURA_SP011_LIVE_ACCEPTANCE=1` in the environment.
  /// The approved test Gmail account is read from `AURA_SP011_TEST_EMAIL` so
  /// no real account address is hard-coded in source or ledgers.
  public static var liveAcceptance: AuraConfiguration {
    liveAcceptance(environment: ProcessInfo.processInfo.environment)
  }

  /// Injectable environment projection keeps the acceptance-only account
  /// ambiguity path deterministic in tests. The optional second account is
  /// never a fallback choice: two entries deliberately keep mail disabled
  /// until the user identifies one.
  public static func liveAcceptance(environment: [String: String]) -> AuraConfiguration {
    let testEmail = environment["AURA_SP011_TEST_EMAIL"] ?? ""
    let secondTestEmail = environment["AURA_SP011_SECOND_TEST_EMAIL"] ?? ""
    let oauthClientID = environment["AURA_SP011_OAUTH_CLIENT_ID"] ?? ""
    let accounts = [testEmail, secondTestEmail].filter { !$0.isEmpty }
    let defaults = ProductivityConfiguration()
    // Every acceptance leg stays off unless its own variable turns it on. The
    // earlier profile enabled only mail, which left the calendar, contacts and
    // Safari legs uncomposed and therefore unrunnable — the acceptance profile
    // could not exercise the matrix it exists for.
    return AuraConfiguration(
      productivity: ProductivityConfiguration(
        safariProfileID: environment["AURA_SP011_SAFARI_PROFILE_ID"]
          ?? defaults.safariProfileID,
        safariExtensionID: environment["AURA_SP011_SAFARI_EXTENSION_ID"]
          ?? defaults.safariExtensionID,
        safariSharedContainerPath: environment["AURA_SP011_SAFARI_CONTAINER"]
          ?? defaults.safariSharedContainerPath,
        safariAllowedHosts: Self.hostList(environment["AURA_SP011_SAFARI_ALLOWED_HOSTS"]),
        mailAccountIDs: accounts,
        mailAllowedHosts: ["gmail.googleapis.com"],
        calendarReadEnabled: environment["AURA_SP011_ENABLE_CALENDAR"] == "1",
        contactsReadEnabled: environment["AURA_SP011_ENABLE_CONTACTS"] == "1",
        allowsTestAccountAuthorization: true,
        gmailOAuthClientID: oauthClientID
      )
    )
  }

  /// Split a comma-separated allowed-host list, dropping blanks so a trailing
  /// comma cannot introduce an empty host that would match nothing and read
  /// as a configured entry.
  private static func hostList(_ raw: String?) -> [String] {
    (raw ?? "")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// Bootstrap-time configuration: neutral defaults unless an explicit live
  /// acceptance profile is requested. SP-012 only supplies non-secret bridge
  /// coordinates through the process environment; the shared secret remains
  /// user-entered through AURA's SecureField and is stored in Keychain.
  public static var bootstrap: AuraConfiguration {
    let environment = ProcessInfo.processInfo.environment
    var configuration = environment["AURA_SP011_LIVE_ACCEPTANCE"] == "1"
      ? liveAcceptance : `default`
    if environment["AURA_SP012_LIVE_ACCEPTANCE"] == "1" {
      configuration.vscode = sp012LiveAcceptance(environment: environment).vscode
    }
    return configuration
  }

  /// Non-secret SP-012 bridge configuration used by the live acceptance
  /// launcher and by deterministic tests. The shared secret is intentionally
  /// absent; it is entered through the user-facing SecureField and stored only
  /// by `provisionVSCodeBridge`.
  public static func sp012LiveAcceptance(environment: [String: String]) -> AuraConfiguration {
    let bridgeDirectory = environment["AURA_SP012_BRIDGE_DIRECTORY"]
      ?? "\(NSHomeDirectory())/Library/Application Support/AURA/vscode-bridge"
    let statePath = environment["AURA_SP012_STATE_PATH"]
      ?? "\(bridgeDirectory)/vscode-state.json"
    let commandPath = environment["AURA_SP012_COMMAND_PATH"]
      ?? "\(bridgeDirectory)/vscode-command.json"
    let responsePath = environment["AURA_SP012_RESPONSE_PATH"]
      ?? "\(bridgeDirectory)/vscode-response.json"
    var configuration = AuraConfiguration.default
    configuration.vscode = VSCodeConfiguration(
      cliPath: environment["AURA_SP012_CODE_PATH"] ?? "/usr/local/bin/code",
      bridgeStatePath: statePath,
      bridgeCommandPath: commandPath,
      bridgeResponsePath: responsePath,
      extensionID: environment["AURA_SP012_EXTENSION_ID"] ?? "ai.aura.vscode-bridge")
    return configuration
  }

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

  private static func decoded<T: Decodable>(
    _ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, _ fallback: T
  ) throws -> T {
    try container.decodeIfPresent(T.self, forKey: key) ?? fallback
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = AuraConfiguration()
    self.init(
      app: try Self.decoded(container, .app, defaults.app),
      audio: try Self.decoded(container, .audio, defaults.audio),
      wake: try Self.decoded(container, .wake, defaults.wake),
      stt: try Self.decoded(container, .stt, defaults.stt),
      tts: try Self.decoded(container, .tts, defaults.tts),
      conversation: try Self.decoded(container, .conversation, defaults.conversation),
      policy: try Self.decoded(container, .policy, defaults.policy),
      automation: try Self.decoded(container, .automation, defaults.automation),
      shell: try Self.decoded(container, .shell, defaults.shell),
      vscode: try Self.decoded(container, .vscode, defaults.vscode),
      task: try Self.decoded(container, .task, defaults.task),
      codex: try Self.decoded(container, .codex, defaults.codex),
      claude: try Self.decoded(container, .claude, defaults.claude),
      copilot: try Self.decoded(container, .copilot, defaults.copilot),
      ollama: try Self.decoded(container, .ollama, defaults.ollama),
      worktree: try Self.decoded(container, .worktree, defaults.worktree),
      context: try Self.decoded(container, .context, defaults.context),
      screen: try Self.decoded(container, .screen, defaults.screen),
      computerUse: try Self.decoded(container, .computerUse, defaults.computerUse),
      privacy: try Self.decoded(container, .privacy, defaults.privacy),
      log: try Self.decoded(container, .log, defaults.log),
      security: try Self.decoded(container, .security, defaults.security),
      plugins: try Self.decoded(container, .plugins, defaults.plugins),
      intent: try Self.decoded(container, .intent, defaults.intent),
      // SP-009 added the `productivity` section and its coding key but never
      // decoded it here, so a configuration file that set a Safari profile,
      // extension ID, or shared container path was parsed and then discarded
      // — the bridge always ran on defaults and nothing said so. SP-010 needs
      // the section to be real, so it is decoded, merged, and validated like
      // every other one.
      productivity: try Self.decoded(container, .productivity, defaults.productivity))
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> AuraConfiguration {
    AuraConfiguration(
      app: mergedApp(), audio: mergedAudio(), stt: mergedSTT(), tts: mergedTTS(),
      conversation: mergedConversation(), policy: policy.mergedWithDefaults(),
      automation: mergedAutomation(), shell: mergedShell(), vscode: vscode.mergedWithDefaults(),
      task: mergedTask(), codex: codex.mergedWithDefaults(), claude: claude.mergedWithDefaults(),
      copilot: copilot.mergedWithDefaults(), ollama: ollama.mergedWithDefaults(),
      worktree: worktree.mergedWithDefaults(), context: context.mergedWithDefaults(),
      screen: screen.mergedWithDefaults(), computerUse: computerUse.mergedWithDefaults(),
      privacy: mergedPrivacy(), log: mergedLog(), security: security.mergedWithDefaults(),
      plugins: plugins.mergedWithDefaults(), intent: intent.mergedWithDefaults(),
      productivity: productivity.mergedWithDefaults())
  }

  private func mergedApp() -> AppConfiguration {
    let defaults = AppConfiguration()
    return AppConfiguration(
      bundleIdentifier: app.bundleIdentifier.isEmpty
        ? defaults.bundleIdentifier : app.bundleIdentifier,
      serviceName: app.serviceName.isEmpty ? defaults.serviceName : app.serviceName)
  }

  private func mergedAudio() -> AudioConfiguration {
    let defaults = AudioConfiguration()
    return AudioConfiguration(
      sampleRate: audio.sampleRate <= 0 ? defaults.sampleRate : audio.sampleRate,
      channelCount: audio.channelCount <= 0 ? defaults.channelCount : audio.channelCount,
      frameLength: audio.frameLength <= 0 ? defaults.frameLength : audio.frameLength,
      ringBufferSeconds: audio.ringBufferSeconds <= 0
        ? defaults.ringBufferSeconds : audio.ringBufferSeconds,
      captureBufferSize: audio.captureBufferSize <= 0
        ? defaults.captureBufferSize : audio.captureBufferSize,
      enableEchoCancellation: audio.enableEchoCancellation || defaults.enableEchoCancellation,
      enableAutomaticGainControl: audio.enableAutomaticGainControl
        || defaults.enableAutomaticGainControl)
  }

  private func mergedSTT() -> STTConfiguration {
    let defaults = STTConfiguration()
    return STTConfiguration(
      engineID: stt.engineID.isEmpty ? defaults.engineID : stt.engineID,
      locale: stt.locale.isEmpty ? defaults.locale : stt.locale,
      fallbackLocale: stt.fallbackLocale.isEmpty ? defaults.fallbackLocale : stt.fallbackLocale,
      partialBoundaryFrames: stt.partialBoundaryFrames <= 0
        ? defaults.partialBoundaryFrames : stt.partialBoundaryFrames,
      stabilizationDelayFrames: stt.stabilizationDelayFrames <= 0
        ? defaults.stabilizationDelayFrames : stt.stabilizationDelayFrames,
      enableCustomVocabulary: stt.enableCustomVocabulary || defaults.enableCustomVocabulary)
  }

  private func mergedTTS() -> TTSConfiguration {
    let defaults = TTSConfiguration()
    return TTSConfiguration(
      adapterChain: tts.adapterChain,
      defaultLocale: tts.defaultLocale.isEmpty ? defaults.defaultLocale : tts.defaultLocale,
      defaultRate: tts.defaultRate <= 0 ? defaults.defaultRate : tts.defaultRate,
      preferredSystemVoiceIdentifier: tts.preferredSystemVoiceIdentifier.isEmpty
        ? defaults.preferredSystemVoiceIdentifier : tts.preferredSystemVoiceIdentifier,
      enableBargeIn: tts.enableBargeIn, enableAntiTrigger: tts.enableAntiTrigger)
  }

  private func mergedConversation() -> ConversationConfiguration {
    let defaults = ConversationConfiguration()
    return ConversationConfiguration(
      listenTimeoutSeconds: conversation.listenTimeoutSeconds <= 0
        ? defaults.listenTimeoutSeconds : conversation.listenTimeoutSeconds,
      thinkTimeoutSeconds: conversation.thinkTimeoutSeconds <= 0
        ? defaults.thinkTimeoutSeconds : conversation.thinkTimeoutSeconds,
      speechTimeoutSeconds: conversation.speechTimeoutSeconds <= 0
        ? defaults.speechTimeoutSeconds : conversation.speechTimeoutSeconds,
      bargeInGraceMilliseconds: conversation.bargeInGraceMilliseconds <= 0
        ? defaults.bargeInGraceMilliseconds : conversation.bargeInGraceMilliseconds,
      silenceEndFrames: conversation.silenceEndFrames <= 0
        ? defaults.silenceEndFrames : conversation.silenceEndFrames,
      continuationWindowSeconds: conversation.continuationWindowSeconds <= 0
        ? defaults.continuationWindowSeconds : conversation.continuationWindowSeconds,
      deterministicStopCommands: conversation.deterministicStopCommands.isEmpty
        ? defaults.deterministicStopCommands : conversation.deterministicStopCommands,
      deterministicPauseResumeCommands: conversation.deterministicPauseResumeCommands.isEmpty
        ? defaults.deterministicPauseResumeCommands : conversation.deterministicPauseResumeCommands)
  }

  private func mergedAutomation() -> AutomationConfiguration {
    AutomationConfiguration(
      actionTimeoutSeconds: automation.actionTimeoutSeconds <= 0
        ? AutomationConfiguration().actionTimeoutSeconds : automation.actionTimeoutSeconds,
      observationTimeoutSeconds: automation.observationTimeoutSeconds <= 0
        ? AutomationConfiguration().observationTimeoutSeconds
        : automation.observationTimeoutSeconds,
      sensitiveBundleIdentifiers: automation.sensitiveBundleIdentifiers,
      allowedAutomationCapabilities: automation.allowedAutomationCapabilities)
  }

  private func mergedShell() -> ShellConfiguration {
    let defaults = ShellConfiguration()
    return ShellConfiguration(
      defaultTimeoutSeconds: shell.defaultTimeoutSeconds <= 0
        ? defaults.defaultTimeoutSeconds : shell.defaultTimeoutSeconds,
      maxOutputBytes: shell.maxOutputBytes <= 0 ? defaults.maxOutputBytes : shell.maxOutputBytes,
      maxOutputLines: shell.maxOutputLines <= 0 ? defaults.maxOutputLines : shell.maxOutputLines,
      allowedEnvironmentKeys: shell.allowedEnvironmentKeys.isEmpty
        ? defaults.allowedEnvironmentKeys : shell.allowedEnvironmentKeys,
      redactionPatterns: shell.redactionPatterns.isEmpty
        ? defaults.redactionPatterns : shell.redactionPatterns,
      allowedExecutablePaths: shell.allowedExecutablePaths.isEmpty
        ? defaults.allowedExecutablePaths : shell.allowedExecutablePaths,
      allowedWorkingDirectories: shell.allowedWorkingDirectories.isEmpty
        ? defaults.allowedWorkingDirectories : shell.allowedWorkingDirectories)
  }

  private func mergedTask() -> TaskConfiguration {
    let defaults = TaskConfiguration()
    return TaskConfiguration(
      defaultMaxRetries: task.defaultMaxRetries < 0
        ? defaults.defaultMaxRetries : task.defaultMaxRetries,
      defaultInactivityTimeoutSeconds: task.defaultInactivityTimeoutSeconds <= 0
        ? defaults.defaultInactivityTimeoutSeconds : task.defaultInactivityTimeoutSeconds,
      checkpointRetentionDays: task.checkpointRetentionDays <= 0
        ? defaults.checkpointRetentionDays : task.checkpointRetentionDays,
      maxConcurrentTasks: task.maxConcurrentTasks <= 0
        ? defaults.maxConcurrentTasks : task.maxConcurrentTasks,
      queueCapacity: task.queueCapacity <= 0 ? defaults.queueCapacity : task.queueCapacity)
  }

  private func mergedPrivacy() -> PrivacyConfiguration {
    let defaults = PrivacyConfiguration()
    return PrivacyConfiguration(
      ambientAudioRetentionSeconds: privacy.ambientAudioRetentionSeconds < 0
        ? defaults.ambientAudioRetentionSeconds : privacy.ambientAudioRetentionSeconds,
      screenshotRetentionDays: privacy.screenshotRetentionDays < 0
        ? defaults.screenshotRetentionDays : privacy.screenshotRetentionDays)
  }

  private func mergedLog() -> LoggingConfiguration {
    let defaults = LoggingConfiguration()
    return LoggingConfiguration(
      minimumLevel: log.minimumLevel.isEmpty ? defaults.minimumLevel : log.minimumLevel,
      destination: log.destination.isEmpty ? defaults.destination : log.destination)
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
    try productivity.validate()
  }
}
