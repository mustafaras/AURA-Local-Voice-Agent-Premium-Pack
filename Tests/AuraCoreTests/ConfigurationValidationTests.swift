import AuraCore
import Foundation
import Testing

/// Deterministic branch-coverage tests for the `AuraCore` configuration value
/// types. These cover the `validate()` guards, `mergedWithDefaults()` fallbacks,
/// and Codable round-trips that were added across the second-pass tracks but
/// never measured, and that dropped the canonical wrapper's branch coverage
/// below the unchanged 70% ratchet. No production behavior changes; no
/// gate/scope/threshold is weakened.
@Suite("AuraCore configuration validation")
struct ConfigurationValidationTests {

  private func assertInvalid(
    _ body: () throws -> Void
  ) {
    do {
      try body()
      Issue.record("expected validation to throw")
    } catch let error as AuraError {
      guard case .invalidConfiguration = error else {
        Issue.record("unexpected AuraError case")
        return
      }
    } catch {
      Issue.record("unexpected error")
    }
  }

  // MARK: - AppConfiguration

  @Test func appConfigurationValidateAndDecode() throws {
    try AppConfiguration().validate()
    var config = AppConfiguration(bundleIdentifier: "", serviceName: "x")
    assertInvalid { try config.validate() }
    config = AppConfiguration(bundleIdentifier: "ai.aura.local", serviceName: "")
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(AppConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.bundleIdentifier == "ai.aura.local")
    #expect(decoded.serviceName == "AuraCore")
  }

  // MARK: - AudioConfiguration

  @Test func audioConfigurationValidateAndDecode() throws {
    try AudioConfiguration().validate()
    var config = AudioConfiguration(sampleRate: 0)
    assertInvalid { try config.validate() }
    config = AudioConfiguration(channelCount: 0)
    assertInvalid { try config.validate() }
    config = AudioConfiguration(frameLength: 0)
    assertInvalid { try config.validate() }
    config = AudioConfiguration(ringBufferSeconds: 0)
    assertInvalid { try config.validate() }
    config = AudioConfiguration(captureBufferSize: 0)
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(AudioConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.sampleRate == 16_000)
    #expect(decoded.channelCount == 1)
  }

  // MARK: - AutomationConfiguration

  @Test func automationConfigurationValidateAndDecode() throws {
    try AutomationConfiguration().validate()
    var config = AutomationConfiguration(actionTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = AutomationConfiguration(observationTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = AutomationConfiguration(allowedAutomationCapabilities: [])
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(AutomationConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.actionTimeoutSeconds == 10.0)
    #expect(decoded.sensitiveBundleIdentifiers.contains("com.apple.keychainaccess"))
  }

  // MARK: - ShellConfiguration

  @Test func shellConfigurationValidateAndDecode() throws {
    try ShellConfiguration().validate()
    var config = ShellConfiguration(defaultTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = ShellConfiguration(maxOutputBytes: 0)
    assertInvalid { try config.validate() }
    config = ShellConfiguration(maxOutputLines: 0)
    assertInvalid { try config.validate() }
    config = ShellConfiguration(redactionPatterns: [""])
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(ShellConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.maxOutputLines == 10_000)
    #expect(decoded.allowedEnvironmentKeys.contains("HOME"))
  }

  // MARK: - PrivacyConfiguration

  @Test func privacyConfigurationValidateAndDecode() throws {
    try PrivacyConfiguration().validate()
    var config = PrivacyConfiguration(ambientAudioRetentionSeconds: -1)
    assertInvalid { try config.validate() }
    config = PrivacyConfiguration(screenshotRetentionDays: -1)
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(PrivacyConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.ambientAudioRetentionSeconds == 0)
    #expect(decoded.screenshotRetentionDays == 7)
  }

  // MARK: - LoggingConfiguration

  @Test func loggingConfigurationValidateAndDecode() throws {
    try LoggingConfiguration().validate()
    var config = LoggingConfiguration(minimumLevel: "bogus")
    assertInvalid { try config.validate() }
    config = LoggingConfiguration(minimumLevel: "info", destination: "")
    assertInvalid { try config.validate() }
    try LoggingConfiguration(minimumLevel: "DEBUG").validate()

    let decoded = try JSONDecoder().decode(LoggingConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.minimumLevel == "info")
    #expect(decoded.destination == "stderr")
  }

  // MARK: - TaskConfiguration

  @Test func taskConfigurationValidateAndDecode() throws {
    try TaskConfiguration().validate()
    var config = TaskConfiguration(defaultMaxRetries: -1)
    assertInvalid { try config.validate() }
    config = TaskConfiguration(defaultInactivityTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = TaskConfiguration(checkpointRetentionDays: 0)
    assertInvalid { try config.validate() }
    config = TaskConfiguration(maxConcurrentTasks: 0)
    assertInvalid { try config.validate() }
    config = TaskConfiguration(queueCapacity: 0)
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(TaskConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.maxConcurrentTasks == 3)
    #expect(decoded.queueCapacity == 100)
  }

  // MARK: - ConversationConfiguration

  @Test func conversationConfigurationValidateAndDecode() throws {
    try ConversationConfiguration().validate()
    var config = ConversationConfiguration(listenTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = ConversationConfiguration(thinkTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = ConversationConfiguration(speechTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = ConversationConfiguration(bargeInGraceMilliseconds: 0)
    assertInvalid { try config.validate() }
    config = ConversationConfiguration(silenceEndFrames: 0)
    assertInvalid { try config.validate() }
    config = ConversationConfiguration(continuationWindowSeconds: 0)
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(ConversationConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.deterministicStopCommands.contains("dur"))
    #expect(decoded.deterministicPauseResumeCommands.contains("devam et"))
  }

  // MARK: - TTSConfiguration / TTSAdapterChain

  @Test func ttsAdapterChainValidate() throws {
    try TTSAdapterChain().validate()
    try TTSAdapterChain(adapterIDs: ["chatterbox"]).validate()
    var chain = TTSAdapterChain(adapterIDs: [])
    assertInvalid { try chain.validate() }
    chain = TTSAdapterChain(adapterIDs: ["   "])
    assertInvalid { try chain.validate() }
  }

  @Test func ttsConfigurationValidateAndDecode() throws {
    try TTSConfiguration().validate()
    var config = TTSConfiguration(adapterChain: TTSAdapterChain(adapterIDs: []))
    assertInvalid { try config.validate() }
    config = TTSConfiguration(defaultLocale: "   ")
    assertInvalid { try config.validate() }
    config = TTSConfiguration(defaultRate: 0)
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(TTSConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.defaultLocale == "tr-TR")
    #expect(decoded.defaultRate == 0.92)
    #expect(decoded.adapterChain.adapterIDs == ["chatterbox", "system"])
  }

  // MARK: - STTConfiguration

  @Test func sttConfigurationValidateAndDecode() throws {
    try STTConfiguration().validate()
    var config = STTConfiguration(engineID: " ")
    assertInvalid { try config.validate() }
    config = STTConfiguration(locale: " ")
    assertInvalid { try config.validate() }
    config = STTConfiguration(fallbackLocale: " ")
    assertInvalid { try config.validate() }
    config = STTConfiguration(partialBoundaryFrames: 0)
    assertInvalid { try config.validate() }
    config = STTConfiguration(stabilizationDelayFrames: 0)
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(STTConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.engineID == "native-speech")
    #expect(decoded.fallbackLocale == "en-US")
  }

  // MARK: - SecurityConfiguration

  @Test func securityConfigurationValidateMergeAndDecode() throws {
    try SecurityConfiguration().validate()
    var config = SecurityConfiguration(secretKeychainServiceName: "")
    assertInvalid { try config.validate() }
    config = SecurityConfiguration(injectionBlockSeverityThreshold: 0)
    assertInvalid { try config.validate() }

    let merged = SecurityConfiguration(
      secretKeychainServiceName: "", injectionBlockSeverityThreshold: 0).mergedWithDefaults()
    #expect(merged.secretKeychainServiceName == "ai.aura.local.secrets")
    #expect(merged.injectionBlockSeverityThreshold == 3)

    let decoded = try JSONDecoder().decode(SecurityConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.secretKeychainServiceName == "ai.aura.local.secrets")
  }

  // MARK: - ScreenContextConfiguration

  @Test func screenContextConfigurationValidateAndDecode() throws {
    try ScreenContextConfiguration().validate()
    var config = ScreenContextConfiguration(freshnessSeconds: 0)
    assertInvalid { try config.validate() }
    config = ScreenContextConfiguration(maxCaptureDimension: 0)
    assertInvalid { try config.validate() }
    config = ScreenContextConfiguration(
      userDefinedRedactionRegions: [UserDefinedRedactionRegion(originX: 0, originY: 0, width: 0, height: 1)])
    assertInvalid { try config.validate() }
    config = ScreenContextConfiguration(
      userDefinedRedactionRegions: [UserDefinedRedactionRegion(originX: -0.1, originY: 0, width: 1, height: 1)])
    assertInvalid { try config.validate() }

    let decoded = try JSONDecoder().decode(ScreenContextConfiguration.self, from: Data("{}".utf8))
    #expect(decoded.enabled == false)
    #expect(decoded.retainRawFrames == false)
    #expect(decoded.ocrRedactionEnabled == true)
  }

  // MARK: - ComputerUseConfiguration

  @Test func computerUseConfigurationValidateMergeAndDecode() throws {
    try ComputerUseConfiguration().validate()
    var config = ComputerUseConfiguration(maxIterations: 0)
    assertInvalid { try config.validate() }
    config = ComputerUseConfiguration(maxStepsPerPlan: 0)
    assertInvalid { try config.validate() }
    config = ComputerUseConfiguration(noProgressIterationThreshold: 0)
    assertInvalid { try config.validate() }
    config = ComputerUseConfiguration(minActionIntervalSeconds: -1)
    assertInvalid { try config.validate() }

    let merged = ComputerUseConfiguration(maxIterations: 0, minActionIntervalSeconds: -1)
      .mergedWithDefaults()
    #expect(merged.maxIterations == 25)
    #expect(merged.minActionIntervalSeconds == 0.2)
  }

  // MARK: - CodexConfiguration

  @Test func codexConfigurationValidateMergeAndDecode() throws {
    try CodexConfiguration().validate()
    var config = CodexConfiguration(executablePath: "")
    assertInvalid { try config.validate() }
    config = CodexConfiguration(defaultTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = CodexConfiguration(defaultTimeoutSeconds: 20, maxTimeoutSeconds: 10)
    assertInvalid { try config.validate() }
    config = CodexConfiguration(maxOutputBytes: 0)
    assertInvalid { try config.validate() }
    config = CodexConfiguration(maxOutputLines: 0)
    assertInvalid { try config.validate() }
    config = CodexConfiguration(maxFileWritesPerRun: 0)
    assertInvalid { try config.validate() }
    config = CodexConfiguration(allowedWorkingDirectories: [])
    assertInvalid { try config.validate() }
    config = CodexConfiguration(maxTokensPerRun: 0)
    assertInvalid { try config.validate() }
    config = CodexConfiguration(maxEstimatedCostUSD: 0)
    assertInvalid { try config.validate() }
    config = CodexConfiguration(costPerTokenUSD: -1)
    assertInvalid { try config.validate() }

    let merged = CodexConfiguration(executablePath: "", maxTokensPerRun: 0).mergedWithDefaults()
    #expect(merged.executablePath == "/opt/homebrew/bin/codex")
  }

  // MARK: - CopilotConfiguration

  @Test func copilotConfigurationValidateMergeAndDecode() throws {
    try CopilotConfiguration().validate()
    var config = CopilotConfiguration(executablePath: "")
    assertInvalid { try config.validate() }
    config = CopilotConfiguration(defaultTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = CopilotConfiguration(defaultTimeoutSeconds: 20, maxTimeoutSeconds: 10)
    assertInvalid { try config.validate() }
    config = CopilotConfiguration(maxOutputBytes: 0)
    assertInvalid { try config.validate() }
    config = CopilotConfiguration(maxOutputLines: 0)
    assertInvalid { try config.validate() }
    config = CopilotConfiguration(maxAICredits: 0)
    assertInvalid { try config.validate() }
    config = CopilotConfiguration(maxFileWritesPerRun: 0)
    assertInvalid { try config.validate() }
    config = CopilotConfiguration(allowedWorkingDirectories: [])
    assertInvalid { try config.validate() }

    let merged = CopilotConfiguration(executablePath: "", maxAICredits: 0).mergedWithDefaults()
    #expect(merged.executablePath == "/opt/homebrew/bin/copilot")
  }

  // MARK: - ClaudeConfiguration

  @Test func claudeConfigurationValidateMergeAndDecode() throws {
    try ClaudeConfiguration().validate()
    var config = ClaudeConfiguration(executablePath: "")
    assertInvalid { try config.validate() }
    config = ClaudeConfiguration(defaultTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = ClaudeConfiguration(defaultTimeoutSeconds: 20, maxTimeoutSeconds: 10)
    assertInvalid { try config.validate() }
    config = ClaudeConfiguration(maxOutputBytes: 0)
    assertInvalid { try config.validate() }
    config = ClaudeConfiguration(maxOutputLines: 0)
    assertInvalid { try config.validate() }
    config = ClaudeConfiguration(maxEstimatedCostUSD: 0)
    assertInvalid { try config.validate() }
    config = ClaudeConfiguration(readOnlyTools: [])
    assertInvalid { try config.validate() }
    config = ClaudeConfiguration(workspaceWriteTools: [])
    assertInvalid { try config.validate() }
    config = ClaudeConfiguration(allowedWorkingDirectories: [])
    assertInvalid { try config.validate() }

    let merged = ClaudeConfiguration(executablePath: "", maxEstimatedCostUSD: 0).mergedWithDefaults()
    #expect(merged.executablePath == "/opt/homebrew/bin/claude")
    #expect(merged.settingSources.contains("user"))
  }

  // MARK: - OllamaConfiguration

  @Test func ollamaConfigurationValidateMergeAndDecode() throws {
    try OllamaConfiguration().validate()
    var config = OllamaConfiguration(baseURL: "")
    assertInvalid { try config.validate() }
    config = OllamaConfiguration(baseURL: "http://example.com")
    assertInvalid { try config.validate() }
    config = OllamaConfiguration(requestTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = OllamaConfiguration(healthCheckTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = OllamaConfiguration(maxResidentModelBytes: 0)
    assertInvalid { try config.validate() }
    config = OllamaConfiguration(estimatedResidentMemoryRatio: 0)
    assertInvalid { try config.validate() }
    config = OllamaConfiguration(estimatedResidentMemoryRatio: 1.5)
    assertInvalid { try config.validate() }
    config = OllamaConfiguration(keepAliveSeconds: -1)
    assertInvalid { try config.validate() }

    let merged = OllamaConfiguration(baseURL: "").mergedWithDefaults()
    #expect(merged.baseURL == "http://127.0.0.1:11434")
  }

  // MARK: - WorktreeConfiguration

  @Test func worktreeConfigurationValidateMergeAndRoot() throws {
    try WorktreeConfiguration().validate()
    var config = WorktreeConfiguration(gitExecutablePath: "")
    assertInvalid { try config.validate() }
    config = WorktreeConfiguration(defaultTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = WorktreeConfiguration(branchPrefix: "")
    assertInvalid { try config.validate() }
    config = WorktreeConfiguration(worktreeDirectoryName: "")
    assertInvalid { try config.validate() }
    config = WorktreeConfiguration(allowedWorkingDirectories: [])
    assertInvalid { try config.validate() }

    let w = WorktreeConfiguration(worktreeDirectoryName: ".aura-wt")
    #expect(w.worktreeRoot(for: "/repo").hasSuffix("/repo/.aura-wt"))
    let shell = w.derivedShellConfiguration()
    #expect(shell.allowedExecutablePaths == ["/usr/bin/git"])
    let merged = WorktreeConfiguration(gitExecutablePath: "", defaultTimeoutSeconds: 0)
      .mergedWithDefaults()
    #expect(merged.gitExecutablePath == "/usr/bin/git")
    #expect(merged.defaultTimeoutSeconds == 60.0)
  }

  // MARK: - VSCodeConfiguration

  @Test func vscodeConfigurationValidateMergeAndDecode() throws {
    try VSCodeConfiguration().validate()
    var config = VSCodeConfiguration(cliPath: "")
    assertInvalid { try config.validate() }
    config = VSCodeConfiguration(cliTimeoutSeconds: 0)
    assertInvalid { try config.validate() }
    config = VSCodeConfiguration(bridgeMaxStalenessSeconds: -1)
    assertInvalid { try config.validate() }
    config = VSCodeConfiguration(allowedTerminalShells: [])
    assertInvalid { try config.validate() }
    config = VSCodeConfiguration(bridgeCommandPath: "")
    assertInvalid { try config.validate() }
    config = VSCodeConfiguration(bridgeResponsePath: "")
    assertInvalid { try config.validate() }

    let merged = VSCodeConfiguration(cliPath: "", cliTimeoutSeconds: 0).mergedWithDefaults()
    #expect(merged.cliPath == "/usr/local/bin/code")
    #expect(merged.cliTimeoutSeconds == 10.0)
  }

  // MARK: - IntentEngineConfiguration

  @Test func intentEngineConfigurationValidateMergeAndDecode() throws {
    try IntentEngineConfiguration().validate()
    var config = IntentEngineConfiguration(minimumClassificationConfidence: -0.1)
    assertInvalid { try config.validate() }
    config = IntentEngineConfiguration(minimumClassificationConfidence: 1.1)
    assertInvalid { try config.validate() }
    config = IntentEngineConfiguration(defaultCodingAgentBackend: "")
    assertInvalid { try config.validate() }
    config = IntentEngineConfiguration(defaultCodingAgentWorkingDirectory: "")
    assertInvalid { try config.validate() }
    config = IntentEngineConfiguration(clarificationExpirySeconds: 0)
    assertInvalid { try config.validate() }
    config = IntentEngineConfiguration(destructiveShellPatterns: [""])
    assertInvalid { try config.validate() }

    let merged = IntentEngineConfiguration(minimumClassificationConfidence: 2.0).mergedWithDefaults()
    #expect(merged.minimumClassificationConfidence == 0.6)
  }

  // MARK: - WakeWordConfiguration

  @Test func wakeWordConfigurationValidate() throws {
    try WakeWordConfiguration().validate()
    var config = WakeWordConfiguration(phrase: "   ")
    assertInvalid { try config.validate() }
    config = WakeWordConfiguration(vadEnergyThresholdDB: 1)
    assertInvalid { try config.validate() }
    config = WakeWordConfiguration(vadSilenceFrames: 0)
    assertInvalid { try config.validate() }
    config = WakeWordConfiguration(wakeConfidenceThreshold: 1.5)
    assertInvalid { try config.validate() }
    config = WakeWordConfiguration(wakeDebounceSeconds: -1)
    assertInvalid { try config.validate() }
    config = WakeWordConfiguration(speakerVerificationThreshold: 2)
    assertInvalid { try config.validate() }
    try WakeWordConfiguration(wakeConfidenceThreshold: 0, speakerVerificationThreshold: 0).validate()
  }

  // MARK: - PluginConfiguration

  @Test func pluginConfigurationValidateMergeAndDecode() throws {
    try PluginConfiguration().validate()
    var config = PluginConfiguration(registryStoreKey: "")
    assertInvalid { try config.validate() }
    config = PluginConfiguration(helperExecutablePath: "/bin/x", helperSHA256Hex: "")
    assertInvalid { try config.validate() }
    config = PluginConfiguration(
      helperExecutablePath: "/bin/x",
      helperSHA256Hex: "not-a-valid-hex-hash-that-is-too-short")
    assertInvalid { try config.validate() }
    config = PluginConfiguration(
      trustedVendorPublicKeysBase64: ["": "AAAA"])
    assertInvalid { try config.validate() }
    config = PluginConfiguration(
      trustedVendorPublicKeysBase64: ["vendor": "not-base64"])
    assertInvalid { try config.validate() }
    config = PluginConfiguration(
      trustedVendorPublicKeysByKeyIDBase64: ["novendorhash": "AAAA"])
    assertInvalid { try config.validate() }

    let merged = PluginConfiguration(registryStoreKey: "").mergedWithDefaults()
    #expect(merged.registryStoreKey == "aura.plugins.registry")
  }

  // MARK: - PreferenceQuietHours

  @Test func preferenceQuietHoursValidate() throws {
    try PreferenceQuietHours(startHour: 22, endHour: 6).validate()
    var qh = PreferenceQuietHours(startHour: 24, endHour: 6)
    do {
      try qh.validate()
      Issue.record("expected memoryError for startHour 24")
    } catch let error {
      guard case AuraError.memoryError = error else {
        Issue.record("unexpected AuraError: \(error)")
        return
      }
    }
    qh = PreferenceQuietHours(startHour: 22, endHour: 24)
    do {
      try qh.validate()
      Issue.record("expected memoryError for endHour 24")
    } catch let error {
      guard case AuraError.memoryError = error else {
        Issue.record("unexpected AuraError: \(error)")
        return
      }
    }
  }
}
