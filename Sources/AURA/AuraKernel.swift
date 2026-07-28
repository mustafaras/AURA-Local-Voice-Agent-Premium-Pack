import AuraAgent
import AuraAudio
import AuraAutomation
import AuraComputerUse
import AuraContext
import AuraCore
import AuraIntent
import AuraMemory
import AuraPlugins
import AuraPolicy
import AuraSTT
import AuraScreen
import AuraSecurity
import AuraShell
import AuraStore
import AuraTasks
import AuraVSCode
import Dispatch
import Foundation

/// The composition root: constructs every already-real backend subsystem in
/// dependency order, wires `AuraIntent`'s decision layer between
/// `Conversation` and those subsystems, and starts the real audio-capture
/// pipeline. See `docs/decisions/ADR-022-composition-root-wiring.md`.
actor AuraKernel {
  private let configuration: AuraConfiguration
  private let store: AuraStore
  private let eventBus: AuraEventBus
  private let logger: AuraLogger
  private let confirmationPresenter: any AuraConfirmationPresenting

  private var policyEngine: PolicyEngine?
  private var taskEngine: AuraTaskEngine?
  private var agentTaskRunner: AgentBackendTaskRunner?
  private var audio: AuraAudio?
  private var wakeWordPipeline: WakeWordPipeline?
  private var sttPipeline: STTPipeline?
  private var intentDispatchCoordinator: IntentDispatchCoordinator?
  private var conversationEventBridge: ConversationEventBridge?
  private var audioSampleBridge: AudioSampleBridge?
  private var performanceSampler: PerformanceSampler?
  private var emergencyStop: EmergencyStopController?
  private var screenEngine: ScreenContextEngine?
  private var computerUseLoop: ComputerUseControlLoop?
  private var vscodeAdapter: VSCodeAdapter?
  private var pluginRegistry: PluginRegistry?
  private var ollamaAdapter: OllamaAdapter?
  private var worktreeManager: WorktreeManager?
  private var multiAgentOrchestrator: MultiAgentOrchestrator?
  private var secretScanner: SecretScanner?
  private var injectionClassifier: PromptInjectionClassifier?
  private var networkAllowlist: NetworkAllowlist?
  private var started = false
  private var sttStarted = false

  private var shutdownContinuation: CheckedContinuation<Void, Never>?
  private var sigintSource: DispatchSourceSignal?
  private var sigtermSource: DispatchSourceSignal?

  init(
    configuration: AuraConfiguration,
    store: AuraStore,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    confirmationPresenter: any AuraConfirmationPresenting = SafeDenyConfirmationPresenter()
  ) {
    self.configuration = configuration
    self.store = store
    self.eventBus = eventBus
    self.logger = logger
    self.confirmationPresenter = confirmationPresenter
  }

  /// Construct every subsystem, start the pipeline, and block until a
  /// shutdown signal (SIGINT/SIGTERM) is received.
  func run() async throws(AuraError) {
    try await start()
    installSignalHandlers()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      self.shutdownContinuation = continuation
    }
    await stop()
  }

  func start() async throws(AuraError) {
    guard !started else { return }
    try await construct()
    try await startPipeline()
    started = true
    await logger.info("AuraKernel running; push-to-talk ready", actor: .system)
  }

  func stop() async {
    guard started else { return }
    await shutdownPipeline()
    started = false
  }

  func startSpeechRecognition() async throws(AuraError) {
    guard started, let sttPipeline else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    guard !sttStarted else { return }
    do {
      try await sttPipeline.start()
      sttStarted = true
    } catch {
      throw AuraError.sttEngineError(
        "STT pipeline failed to start: \(error.localizedDescription)")
    }
  }

  func activatePushToTalk() async throws(AuraError) {
    guard sttStarted else {
      throw AuraError.permissionDenied("Speech recognition permission is required")
    }
    let envelope = EventEnvelope(
      correlationID: UUID(),
      causationID: UUID(),
      actor: .user,
      sensitivity: .sensitive,
      payload: WakeActivationEvent(isActive: true, privacyMode: false))
    await eventBus.emit(envelope)
  }

  func triggerEmergencyStop() async {
    await emergencyStop?.trigger(source: .ui, reason: "User activated emergency stop")
  }

  func resetEmergencyStop() async {
    await emergencyStop?.reset(actor: .user)
  }

  // MARK: - Construction (dependency order)

  private func construct() async throws(AuraError) {
    let bundleID = configuration.app.bundleIdentifier

    let policyEngine = try await PolicyEngine(
      configuration: configuration.policy, eventBus: eventBus, store: store)
    try await seedDefaultGrants(policyEngine)
    self.policyEngine = policyEngine

    let shell = AuraShell(configuration: configuration.shell)
    let automation = AuraAutomation(
      config: configuration.automation, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "automation"))

    let memory = MemoryEngine(store: store, eventBus: eventBus)
    let context = ContextEngine(
      store: store, memory: memory, eventBus: eventBus, configuration: configuration.context)
    let contextBuilder = ContextBuilder(
      engine: context, memory: memory, eventBus: eventBus,
      configuration: configuration.context)

    let taskEngine = await AuraTaskEngine(
      store: store, eventBus: eventBus, configuration: configuration.task)
    try await taskEngine.recoverState()
    self.taskEngine = taskEngine

    let sessionID = UUID()
    let codexAdapter = CodexAdapter(
      configuration: configuration.codex, policyEngine: policyEngine,
      approvalPresenter: confirmationPresenter, eventBus: eventBus)
    let claudeAdapter = ClaudeAdapter(
      configuration: configuration.claude, policyEngine: policyEngine,
      approvalPresenter: confirmationPresenter, eventBus: eventBus)
    let copilotAdapter = CopilotAdapter(
      configuration: configuration.copilot, policyEngine: policyEngine,
      approvalPresenter: confirmationPresenter, eventBus: eventBus)
    let agentTaskRunner = AgentBackendTaskRunner(
      codex: CodexTaskRunner(
        adapter: codexAdapter, sessionID: sessionID,
        defaultWorkingDirectory: configuration.intent.defaultCodingAgentWorkingDirectory),
      claude: ClaudeTaskRunner(
        adapter: claudeAdapter, sessionID: sessionID,
        defaultWorkingDirectory: configuration.intent.defaultCodingAgentWorkingDirectory),
      copilot: CopilotTaskRunner(
        adapter: copilotAdapter, sessionID: sessionID,
        defaultWorkingDirectory: configuration.intent.defaultCodingAgentWorkingDirectory)
    )
    self.agentTaskRunner = agentTaskRunner

    let emergencyStop = EmergencyStopController(eventBus: eventBus)
    self.emergencyStop = emergencyStop
    let secureFieldDetector = AccessibilitySecureFieldDetector()
    let screenEngine = ScreenContextEngine(
      windowSource: ScreenCaptureKitWindowSource(),
      textRecognizer: VisionTextRecognizer(),
      secureFieldDetector: secureFieldDetector,
      policyEngine: policyEngine,
      eventBus: eventBus,
      configuration: configuration.screen,
      assistantBundleIdentifier: bundleID,
      screenshotRetentionDays: configuration.privacy.screenshotRetentionDays)
    self.screenEngine = screenEngine
    computerUseLoop = ComputerUseControlLoop(
      screenEngine: screenEngine,
      policyEngine: policyEngine,
      actionExecutor: AXCGEventActionExecutor(emergencyStop: emergencyStop),
      modalDetector: AccessibilityModalDialogDetector(),
      secureFieldDetector: secureFieldDetector,
      emergencyStop: emergencyStop,
      eventBus: eventBus,
      configuration: configuration.computerUse)
    vscodeAdapter = VSCodeAdapter(
      configuration: configuration.vscode,
      shell: shell,
      bridge: VSCodeFileBridge(statePath: configuration.vscode.bridgeStatePath))
    secretScanner = SecretScanner()
    injectionClassifier = PromptInjectionClassifier(configuration: configuration.security)
    networkAllowlist = NetworkAllowlist(configuration: configuration.security)

    let verifier = PluginVerifier(
      trustRegistry: PluginTrustRegistry(configuration: configuration.plugins))
    let runtimeComponents = try? PluginRuntimeFactory.make(configuration: configuration.plugins)
    pluginRegistry = try await PluginRegistry(
      verifier: verifier,
      policyEngine: policyEngine,
      store: store,
      eventBus: eventBus,
      artifactStore: runtimeComponents?.artifactStore,
      runtimeHost: runtimeComponents?.runtimeHost,
      configuration: configuration.plugins)
    ollamaAdapter = try? OllamaAdapter(
      configuration: configuration.ollama,
      policyEngine: policyEngine,
      approvalPresenter: confirmationPresenter,
      eventBus: eventBus)
    let worktreeManager = WorktreeManager(
      configuration: configuration.worktree,
      policyEngine: policyEngine,
      eventBus: eventBus)
    self.worktreeManager = worktreeManager
    multiAgentOrchestrator = MultiAgentOrchestrator(
      worktreeManager: worktreeManager,
      policyEngine: policyEngine,
      validationShell: shell,
      eventBus: eventBus)

    let toolRouter = ToolRouter(
      policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
      agentTaskRunner: agentTaskRunner, registry: .defaultRegistry(),
      confirmationPresenter: confirmationPresenter, eventBus: eventBus,
      configuration: configuration.intent)
    let intentEngine = IntentEngine(
      classifier: RuleBasedUtteranceClassifier(), contextEngine: context,
      contextBuilder: contextBuilder, memoryEngine: memory,
      configuration: configuration.intent, eventBus: eventBus,
      sessionID: sessionID)

    let audio = AuraAudio(
      configuration: configuration.audio, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "audio"))
    self.audio = audio

    let vad = EnergyVAD(silenceFrames: configuration.wake.vadSilenceFrames)
    let wakeDetector = MarkerWakeWordDetector(
      phrase: configuration.wake.phrase,
      confidenceThreshold: configuration.wake.wakeConfidenceThreshold,
      energyThresholdDB: configuration.wake.vadEnergyThresholdDB)
    let wakeWordPipeline = WakeWordPipeline(
      configuration: configuration.wake, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "wake"), vad: vad,
      wakeDetector: wakeDetector)
    self.wakeWordPipeline = wakeWordPipeline

    let deterministicPhrases = configuration.conversation.deterministicStopCommands.union(
      configuration.conversation.deterministicPauseResumeCommands)
    let vocabulary = UserVocabulary(
      deterministicCommands: Dictionary(
        uniqueKeysWithValues: deterministicPhrases.map { ($0, $0) }))
    let sttEngine = Self.makeSTTEngine(
      configuration: configuration.stt, vocabulary: vocabulary)
    let sttPipeline = STTPipeline(
      engine: sttEngine, vocabulary: vocabulary, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "stt"))
    self.sttPipeline = sttPipeline

    let ttsEngine = await Self.makeTTSEngine(
      adapterChain: configuration.tts.adapterChain,
      logger: AuraLogger(subsystem: bundleID, category: "tts"))

    let conversation = Conversation(
      configuration: configuration.conversation, ttsConfiguration: configuration.tts,
      ttsEngine: ttsEngine, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "conversation"),
      monotonicClock: { CFAbsoluteTimeGetCurrent() })

    let performanceSampler = PerformanceSampler(
      logger: AuraLogger(subsystem: bundleID, category: "performance"))

    intentDispatchCoordinator = IntentDispatchCoordinator(
      intentEngine: intentEngine, toolRouter: toolRouter, conversation: conversation,
      eventBus: eventBus, sessionID: sessionID)
    conversationEventBridge = ConversationEventBridge(
      conversation: conversation, eventBus: eventBus)
    audioSampleBridge = AudioSampleBridge(
      audio: audio, wakeWordPipeline: wakeWordPipeline, sttPipeline: sttPipeline,
      eventBus: eventBus, enableWakeDetection: false)
    self.performanceSampler = performanceSampler
  }

  /// Seed the default grant table — see `docs/decisions/ADR-022-composition
  /// -root-wiring.md`'s grant-seeding table for the full rationale per row.
  /// `.shellExecDestructive` deliberately has no grant: it falls through to
  /// deny-by-default, plus `ToolRouter`'s own non-bypassable mandatory-
  /// confirmation guard.
  private func seedDefaultGrants(_ policyEngine: PolicyEngine) async throws(AuraError) {
    try await policyEngine.issueGrant(
      Grant(capability: .appActivate, patterns: [.any], confirmationRequirement: .none))
    try await policyEngine.issueGrant(
      Grant(
        capability: .appTerminate, patterns: [.any],
        confirmationRequirement: .forRiskTier(.mutation)))
    try await policyEngine.issueGrant(
      Grant(capability: .shellExec, patterns: [.any], confirmationRequirement: .always))
    try await policyEngine.issueGrant(
      Grant(capability: .agentCodexRun, patterns: [.any], confirmationRequirement: .always))
    try await policyEngine.issueGrant(
      Grant(capability: .agentClaudeRun, patterns: [.any], confirmationRequirement: .always))
    try await policyEngine.issueGrant(
      Grant(capability: .agentCopilotRun, patterns: [.any], confirmationRequirement: .always))
  }

  /// Build the configured TTS engine chain. The chain supports `chatterbox`
  /// (boundary-only prototype), `system` (macOS `AVSpeechSynthesizer`), and
  /// `mock` for tests. Higher-priority neural adapters (`dia`) are not yet
  /// implemented; when requested and unavailable, this factory falls back to
  /// the next configured adapter and ultimately to `system`.
  private static func makeTTSEngine(
    adapterChain: TTSAdapterChain, logger: AuraLogger
  ) async -> any TTSEngine {
    for adapterID in adapterChain.adapterIDs {
      switch adapterID {
      case "chatterbox":
        let engine = ChatterboxTTSEngine()
        do {
          let health = try await engine.start()
          if health.ready {
            await logger.info("TTS adapter ready: \(engine.engineID)", actor: .audio)
            return engine
          }
          await logger.info(
            "TTS adapter \(adapterID) not ready; trying next", actor: .audio)
        } catch {
          await logger.warning("TTS adapter \(adapterID) failed: \(error)", actor: .audio)
        }
      case "system":
        let engine = SystemTTSEngine()
        do {
          let health = try await engine.start()
          if health.ready {
            await logger.info("TTS adapter ready: \(engine.engineID)", actor: .audio)
            return engine
          }
        } catch {
          await logger.warning("TTS adapter \(adapterID) failed: \(error)", actor: .audio)
        }
      case "mock":
        let engine = MockTTSEngine()
        do {
          let health = try await engine.start()
          if health.ready { return engine }
        } catch {
          await logger.warning("TTS adapter \(adapterID) failed: \(error)", actor: .audio)
        }
      default:
        await logger.warning(
          "TTS adapter \(adapterID) not implemented; skipping", actor: .audio)
      }
    }
    // Fail-closed fallback: system TTS must always be available on macOS.
    await logger.warning(
      "All configured TTS adapters unavailable; falling back to system", actor: .audio)
    let fallback = SystemTTSEngine()
    _ = try? await fallback.start()
    return fallback
  }

  /// Build the configured STT engine. Supports `native-speech` for on-device
  /// `Speech.framework` streaming recognition, `mock-stt` for deterministic
  /// tests, and the legacy placeholder as a final fallback. The locale and
  /// vocabulary are taken from `STTConfiguration`.
  private static func makeSTTEngine(
    configuration: STTConfiguration,
    vocabulary: UserVocabulary
  ) -> any STTEngine {
    switch configuration.engineID {
    case "native-speech":
      return SystemSTTEngine(
        locale: Locale(identifier: configuration.locale),
        vocabulary: vocabulary,
        enableCustomVocabulary: configuration.enableCustomVocabulary)
    case "mock-stt":
      return DeterministicMockSTTEngine(
        engineID: "mock-stt",
        locale: Locale(identifier: configuration.locale),
        script: [
          DeterministicMockSTTEngine.MockSegment(text: "hello", expectedFrameCount: 1)
        ])
    default:
      return DeterministicMockSTTEngine(
        engineID: "fallback-mock-stt",
        locale: Locale(identifier: configuration.locale),
        script: [
          DeterministicMockSTTEngine.MockSegment(text: "hello", expectedFrameCount: 1)
        ])
    }
  }

  // MARK: - Start / stop (subscribe-before-publish ordering)

  /// Every event-bus subscriber must be registered before `audio.start()`
  /// — `AuraEventBus` does not replay history to a late subscriber.
  private func startPipeline() async throws(AuraError) {
    guard let taskEngine, let agentTaskRunner, let wakeWordPipeline, let sttPipeline,
      let intentDispatchCoordinator, let conversationEventBridge, let audioSampleBridge,
      let audio, let performanceSampler
    else {
      throw AuraError.invalidConfiguration("AuraKernel.startPipeline called before construct()")
    }

    await taskEngine.start(runner: agentTaskRunner)
    await performanceSampler.start(on: eventBus)
    await wakeWordPipeline.start()
    do {
      try await sttPipeline.start()
      sttStarted = true
    } catch {
      sttStarted = false
      await logger.warning(
        "Speech recognition unavailable until onboarding completes: \(error.localizedDescription)",
        actor: .system)
    }
    await intentDispatchCoordinator.start()
    await conversationEventBridge.start()
    await audioSampleBridge.start()
    try await audio.start()
  }

  private func shutdownPipeline() async {
    await audio?.stop()
    await wakeWordPipeline?.stop()
    await sttPipeline?.stop()
    sttStarted = false
    await taskEngine?.shutdown()
    await logger.info("AuraKernel shutdown complete", actor: .system)
  }

  // MARK: - Signal handling

  private func installSignalHandlers() {
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    intSource.setEventHandler { [weak self] in
      Task { await self?.triggerShutdown() }
    }
    intSource.resume()
    sigintSource = intSource

    let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    termSource.setEventHandler { [weak self] in
      Task { await self?.triggerShutdown() }
    }
    termSource.resume()
    sigtermSource = termSource
  }

  private func triggerShutdown() {
    shutdownContinuation?.resume()
    shutdownContinuation = nil
  }
}
