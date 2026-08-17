import AuraAgent
import AuraAudio
import AuraAutomation
import AuraComputerUse
import AuraConfig
import AuraContext
import AuraCore
import AuraIntent
import AuraMemory
import AuraPlugins
import AuraPolicy
import AuraProductivity
import AuraSTT
import AuraScreen
import AuraSecurity
import AuraShell
import AuraStore
import AuraTasks
import AuraVSCode
import Dispatch
import Foundation

struct AuraKernelFoundation {
  let runtimeHealthRegistry: RuntimeHealthRegistry
  let voiceResourceGovernor: VoiceResourceGovernor
  let policyEngine: PolicyEngine
  let shell: AuraShell
  let automation: AuraAutomation
  let memory: MemoryEngine
  let context: ContextEngine
  let contextBuilder: ContextBuilder
  let taskEngine: AuraTaskEngine
}

struct AuraKernelAgents {
  let taskRunner: AgentBackendTaskRunner
  let healthRegistry: AgentBackendHealthRegistry
}

private struct AuraKernelIntent {
  let intentEngine: IntentEngine
  let toolRouter: ToolRouter
}

extension AuraKernel {
  // MARK: - Construction (dependency order)

  func construct() async throws(AuraError) {
    let foundation = try await constructFoundation()
    let agents = await constructAgentSubsystems(foundation)

    await constructSafetySubsystems(foundation)

    let extensions = try await constructExtensions(foundation, agents)

    let intent = await constructIntentSubsystems(foundation, agents, extensions)

    await constructAudioSubsystems(foundation)

    await constructConversationSubsystems(foundation, intent)
  }

  private func constructFoundation() async throws(AuraError) -> AuraKernelFoundation {
    let bundleID = configuration.app.bundleIdentifier
    let runtime = RuntimeHealthRegistry(eventBus: eventBus)
    self.runtimeHealthRegistry = runtime
    await runtime.recordReady("configuration", detail: "configuration loaded")

    let governor = VoiceResourceGovernor()
    await governor.start()
    self.voiceResourceGovernor = governor
    await runtime.recordReady(
      "voice-resources",
      detail:
        "bounded local voice reservations active for "
        + "\(await governor.physicalMemoryMB()) MB physical memory")
    configurationEngine = try await ConfigurationEngine.load(
      store: AuraStoreConfigurationStateStore(store: store))

    let policy = try await PolicyEngine(
      configuration: configuration.policy, eventBus: eventBus, store: store)
    try await seedDefaultGrants(policy)
    self.policyEngine = policy
    await runtime.recordReady("policy", detail: "deny-by-default policy ready")

    let shell = AuraShell(configuration: configuration.shell)
    let automation = AuraAutomation(
      config: configuration.automation, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "automation"))
    self.automation = automation
    // SP-004. Constructed with the default validator, which applies every
    // path/URL rule but imposes no approved-root restriction — the roots are a
    // caller-supplied narrowing, and no configuration surface defines them
    // yet. Policy remains the gate: each direct-call method evaluates
    // `.fileOpen`/`.fileReveal`/`.urlOpen` through the same `PolicyEngine`.
    self.fileSystemURLOpener = FileSystemURLOpener(validator: .production)
    await runtime.recordReady("shell", detail: "typed shell constructed")
    await runtime.recordReady("automation", detail: "structured automation constructed")
    await runtime.recordReady(
      "filesystem-url-open", detail: "typed filesystem/URL open adapter constructed")

    let memory = MemoryEngine(store: store, eventBus: eventBus)
    self.memoryEngine = memory
    let context = ContextEngine(
      store: store, memory: memory, eventBus: eventBus, configuration: configuration.context)
    let contextBuilder = ContextBuilder(
      engine: context, memory: memory, eventBus: eventBus,
      configuration: configuration.context)
    await runtime.recordReady("memory", detail: "memory engine constructed")
    await runtime.recordReady("context", detail: "context engine constructed")

    let taskEngine = await AuraTaskEngine(
      store: store, eventBus: eventBus, configuration: configuration.task)
    try await taskEngine.recoverState()
    self.taskEngine = taskEngine
    await runtime.recordReady("tasks", detail: "durable task engine ready")
    return AuraKernelFoundation(
      runtimeHealthRegistry: runtime,
      voiceResourceGovernor: governor,
      policyEngine: policy,
      shell: shell,
      automation: automation,
      memory: memory,
      context: context,
      contextBuilder: contextBuilder,
      taskEngine: taskEngine)
  }

  private func constructAgentSubsystems(
    _ foundation: AuraKernelFoundation
  ) async -> AuraKernelAgents {
    let codex = CodexAdapter(
      configuration: configuration.codex, policyEngine: foundation.policyEngine,
      approvalPresenter: confirmationPresenter, eventBus: eventBus)
    let claude = ClaudeAdapter(
      configuration: configuration.claude, policyEngine: foundation.policyEngine,
      approvalPresenter: confirmationPresenter, eventBus: eventBus)
    let copilot = CopilotAdapter(
      configuration: configuration.copilot, policyEngine: foundation.policyEngine,
      approvalPresenter: confirmationPresenter, eventBus: eventBus)
    let runner = AgentBackendTaskRunner(
      codex: CodexTaskRunner(
        adapter: codex, sessionID: sessionID,
        defaultWorkingDirectory: configuration.intent.defaultCodingAgentWorkingDirectory),
      claude: ClaudeTaskRunner(
        adapter: claude, sessionID: sessionID,
        defaultWorkingDirectory: configuration.intent.defaultCodingAgentWorkingDirectory),
      copilot: CopilotTaskRunner(
        adapter: copilot, sessionID: sessionID,
        defaultWorkingDirectory: configuration.intent.defaultCodingAgentWorkingDirectory))
    self.agentTaskRunner = runner

    let probeRunner = AuraShellAgentBackendCommandRunner(
      shells: [
        .codex: AuraShell(configuration: configuration.codex.derivedShellConfiguration()),
        .claude: AuraShell(configuration: configuration.claude.derivedShellConfiguration()),
        .copilot: AuraShell(configuration: configuration.copilot.derivedShellConfiguration()),
      ])
    let healthRegistry = AgentBackendHealthRegistry(
      probe: CLIAgentBackendHealthProbe(
        executablePaths: [
          .codex: configuration.codex.executablePath,
          .claude: configuration.claude.executablePath,
          .copilot: configuration.copilot.executablePath,
        ],
        runner: probeRunner))
    self.agentBackendHealthRegistry = healthRegistry
    let backendHealth = await healthRegistry.refreshAll(
      workspacePath: configuration.intent.defaultCodingAgentWorkingDirectory)
    for health in backendHealth {
      await foundation.runtimeHealthRegistry.record(
        componentID: "agent.backend." + health.backend.rawValue,
        status: Self.runtimeStatus(for: health.state),
        detail: health.detail)
    }
    await foundation.runtimeHealthRegistry.record(
      componentID: "agent-adapters",
      status: backendHealth.allSatisfy { $0.state == AgentBackendHealthState.ready }
        ? .ready : .degraded,
      detail: "adapters constructed; per-backend live version/auth/model evidence remains explicit")
    return AuraKernelAgents(taskRunner: runner, healthRegistry: healthRegistry)
  }

  private static func runtimeStatus(for state: AgentBackendHealthState) -> RuntimeHealthStatus {
    switch state {
    case .ready: .ready
    case .degraded: .degraded
    case .unavailable: .dependencyMissing
    case .unauthorized: .permissionBlocked
    case .versionMismatch: .unsupported
    }
  }

  private func constructSafetySubsystems(
    _ foundation: AuraKernelFoundation
  ) async {
    let emergencyStop = EmergencyStopController(eventBus: eventBus)
    self.emergencyStop = emergencyStop
    let secureFieldDetector = AccessibilitySecureFieldDetector()
    let screen = ScreenContextEngine(
      windowSource: ScreenCaptureKitWindowSource(), textRecognizer: VisionTextRecognizer(),
      secureFieldDetector: secureFieldDetector, policyEngine: foundation.policyEngine,
      eventBus: eventBus, configuration: configuration.screen,
      assistantBundleIdentifier: configuration.app.bundleIdentifier,
      screenshotRetentionDays: configuration.privacy.screenshotRetentionDays)
    self.screenEngine = screen
    await foundation.runtimeHealthRegistry.record(
      componentID: "screen",
      status: configuration.screen.enabled ? .loading : .disabledByConfiguration,
      detail: configuration.screen.enabled
        ? "screen context awaiting capture" : "screen capture disabled by configuration")
    computerUseLoop = ComputerUseControlLoop(
      screenEngine: screen, policyEngine: foundation.policyEngine,
      actionExecutor: AXCGEventActionExecutor(
        emergencyStop: emergencyStop, secureFieldDetector: secureFieldDetector),
      modalDetector: AccessibilityModalDialogDetector(), secureFieldDetector: secureFieldDetector,
      emergencyStop: emergencyStop, eventBus: eventBus, configuration: configuration.computerUse)
    // Exactly the apps with direct live evidence; see the declaration for the
    // evidence ID and the rule for adding an entry.
    self.computerUseAllowlist = ComputerUseBetaAllowlist.liveValidatedProduction
    await foundation.runtimeHealthRegistry.recordReady(
      "computer-use", detail: "bounded computer-use loop constructed")
    vscodeAdapter = VSCodeAdapter(
      configuration: configuration.vscode, shell: foundation.shell,
      bridge: VSCodeFileBridge(statePath: configuration.vscode.bridgeStatePath),
      policyEngine: foundation.policyEngine)
    secretScanner = SecretScanner()
    injectionClassifier = PromptInjectionClassifier(configuration: configuration.security)
    networkAllowlist = NetworkAllowlist(configuration: configuration.security)
    await foundation.runtimeHealthRegistry.recordReady(
      "security", detail: "secret scanner and prompt-injection controls constructed")
    await foundation.runtimeHealthRegistry.recordReady(
      "network", detail: "network allowlist constructed")
    await foundation.runtimeHealthRegistry.recordReady(
      "vscode", detail: "VS Code adapter constructed")

    // SP-009: construct the Safari read bridge. The capability stays disabled
    // until the live package and trust path are verified; availability is
    // reported truthfully through `safariBridgeRuntime?.availability()`.
    do {
      let profile = try BrowserProfileScope(profileID: configuration.productivity.safariProfileID)
      let sharedContainer = URL(
        fileURLWithPath: configuration.productivity.safariSharedContainerPath)
      let secretStore = SafariBridgeSecretStore(
        secretStore: KeychainSecretStore(
          serviceName: configuration.productivity.safariSecretServiceName),
        serviceName: configuration.productivity.safariSecretServiceName)
      let bridge = SafariBridgeRuntime(
        profile: profile,
        extensionID: configuration.productivity.safariExtensionID,
        sharedContainerURL: sharedContainer,
        secretStore: secretStore,
        networkPolicy: ProductivityNetworkPolicy(
          allowlist: NetworkAllowlist(
            allowedHosts: Set(configuration.productivity.safariAllowedHosts))))
      self.safariBridgeRuntime = bridge
      let availability = await bridge.availability()
      let status: RuntimeHealthStatus
      let detail: String
      switch availability {
      case .ready:
        status = .ready
        detail = "Safari read bridge authenticated and ready"
      case .degraded(let reason):
        status = .degraded
        detail = "Safari read bridge degraded: \(reason)"
      case .disabled(let reason):
        status = .disabledByConfiguration
        detail = "Safari read bridge disabled: \(reason)"
      }
      await foundation.runtimeHealthRegistry.record(
        componentID: "safari-bridge", status: status, detail: detail)
    } catch {
      self.safariBridgeRuntime = nil
      await foundation.runtimeHealthRegistry.record(
        componentID: "safari-bridge", status: .configurationInvalid,
        detail: "Safari read bridge could not be constructed: \(error.localizedDescription)")
    }
  }

  private func constructIntentSubsystems(
    _ foundation: AuraKernelFoundation,
    _ agents: AuraKernelAgents,
    _ extensions: AuraKernelExtensions
  ) async -> AuraKernelIntent {
    let dialogue = DialogueEngine(
      reasoningBackend: extensions.ollamaAdapter,
      runtimeHealthRegistry: foundation.runtimeHealthRegistry)
    let capabilityRegistry = CapabilityRegistry()
    await InitialCapabilitySet.registerAll(in: capabilityRegistry)
    self.capabilityRegistry = capabilityRegistry
    await foundation.runtimeHealthRegistry.recordReady(
      "capabilityRegistry",
      detail: "\(InitialCapabilitySet.manifests().count) capabilities registered")
    let router = ToolRouter(
      policyEngine: foundation.policyEngine, automation: foundation.automation,
      shell: foundation.shell,
      taskEngine: foundation.taskEngine,
      agentTaskRunner: agents.taskRunner,
      capabilityRegistry: capabilityRegistry, confirmationPresenter: confirmationPresenter,
      eventBus: eventBus, configuration: configuration.intent, dialogueEngine: dialogue,
      codingTaskCoordinator: codingTaskCoordinator)
    let intentEngine = IntentEngine(
      classifier: RuleBasedUtteranceClassifier(), contextEngine: foundation.context,
      contextBuilder: foundation.contextBuilder, memoryEngine: foundation.memory,
      structuredNLUBackend: extensions.ollamaAdapter, capabilityRegistry: capabilityRegistry,
      configuration: configuration.intent,
      eventBus: eventBus, sessionID: sessionID)
    return AuraKernelIntent(intentEngine: intentEngine, toolRouter: router)
  }

  private func constructAudioSubsystems(
    _ foundation: AuraKernelFoundation
  ) async {
    let bundleID = configuration.app.bundleIdentifier
    let audio = AuraAudio(
      configuration: configuration.audio, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "audio"))
    self.audio = audio
    let wakeWordPipeline = WakeWordPipeline(
      configuration: configuration.wake, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "wake"),
      vad: EnergyVAD(silenceFrames: configuration.wake.vadSilenceFrames),
      wakeDetector: DisabledWakeWordDetector(), sessionID: sessionID)
    self.wakeWordPipeline = wakeWordPipeline
    await foundation.runtimeHealthRegistry.record(
      componentID: "wake-word", status: .unsupported,
      detail: "trained acoustic wake-word model is not bundled; Push to Talk is supported")
    let phrases = configuration.conversation.deterministicStopCommands.union(
      configuration.conversation.deterministicPauseResumeCommands)
    let vocabulary = UserVocabulary(
      deterministicCommands: Dictionary(uniqueKeysWithValues: phrases.map { ($0, $0) }))
    let stt = STTPipeline(
      engine: Self.makeSTTEngine(
        configuration: configuration.stt, vocabulary: vocabulary,
        governor: foundation.voiceResourceGovernor),
      vocabulary: vocabulary, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "stt"), sessionID: sessionID)
    self.sttPipeline = stt
    await foundation.runtimeHealthRegistry.record(
      componentID: "stt", status: .loading,
      detail: "awaiting explicit speech permission and start")
  }

  private func constructConversationSubsystems(
    _ foundation: AuraKernelFoundation,
    _ intent: AuraKernelIntent
  ) async {
    let bundleID = configuration.app.bundleIdentifier
    let tts = await Self.makeTTSEngine(
      adapterChain: configuration.tts.adapterChain,
      preferredSystemVoiceIdentifier: configuration.tts.preferredSystemVoiceIdentifier,
      logger: AuraLogger(subsystem: bundleID, category: "tts"),
      governor: foundation.voiceResourceGovernor)
    let health = tts.health()
    await foundation.runtimeHealthRegistry.record(
      componentID: "tts", status: health.ready ? .ready : .degraded,
      detail: "\(tts.engineID): \(health.detail)")
    let conversation = Conversation(
      configuration: configuration.conversation, ttsConfiguration: configuration.tts,
      ttsEngine: tts, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "conversation"),
      monotonicClock: { CFAbsoluteTimeGetCurrent() }, sessionID: sessionID)
    self.conversation = conversation
    let audio = self.audio!
    let wake = self.wakeWordPipeline!
    let stt = self.sttPipeline!
    self.performanceSampler = PerformanceSampler(
      logger: AuraLogger(subsystem: bundleID, category: "performance"))
    intentDispatchCoordinator = IntentDispatchCoordinator(
      intentEngine: intent.intentEngine, toolRouter: intent.toolRouter,
      conversation: conversation, eventBus: eventBus, sessionID: sessionID)
    conversationEventBridge = ConversationEventBridge(
      conversation: conversation, eventBus: eventBus, sessionID: sessionID)
    audioSampleBridge = AudioSampleBridge(
      audio: audio, wakeWordPipeline: wake, sttPipeline: stt, eventBus: eventBus,
      enableWakeDetection: false,
      pushToTalkFinalizer: PushToTalkSessionFinalizer(
        vad: EnergyVAD(silenceFrames: configuration.conversation.silenceEndFrames),
        eventBus: eventBus,
        maxDurationSeconds: min(
          7, max(1, configuration.conversation.listenTimeoutSeconds - 2))))
    await foundation.runtimeHealthRegistry.record(
      componentID: "audio", status: .loading,
      detail: "awaiting explicit speech permission and start")
    await foundation.runtimeHealthRegistry.recordReady(
      "conversation", detail: "turn state machine constructed")
    await foundation.runtimeHealthRegistry.recordReady(
      "intent", detail: "intent dispatch constructed")
  }

  /// Seed the default grant table — see `docs/decisions/ADR-022-composition
  /// -root-wiring.md`'s grant-seeding table for the full rationale per row.
  /// `.shellExecDestructive` deliberately has no grant: it falls through to
  /// deny-by-default, plus `ToolRouter`'s own non-bypassable mandatory-
  /// confirmation guard.
}
