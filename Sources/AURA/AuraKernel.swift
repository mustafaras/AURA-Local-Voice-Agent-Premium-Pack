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
  private let sessionID = UUID()

  private var runtimeHealthRegistry: RuntimeHealthRegistry?
  private var policyEngine: PolicyEngine?
  private var taskEngine: AuraTaskEngine?
  private var memoryEngine: MemoryEngine?
  private var automation: AuraAutomation?
  private var capabilityRegistry: CapabilityRegistry?
  private var agentTaskRunner: AgentBackendTaskRunner?
  private var agentBackendHealthRegistry: AgentBackendHealthRegistry?
  private var audio: AuraAudio?
  private var wakeWordPipeline: WakeWordPipeline?
  private var sttPipeline: STTPipeline?
  private var intentDispatchCoordinator: IntentDispatchCoordinator?
  private var conversationEventBridge: ConversationEventBridge?
  private var audioSampleBridge: AudioSampleBridge?
  private var performanceSampler: PerformanceSampler?
  private var configurationEngine: ConfigurationEngine?
  private var emergencyStop: EmergencyStopController?
  private var screenEngine: ScreenContextEngine?
  private var computerUseLoop: ComputerUseControlLoop?
  private var computerUseAllowlist: ComputerUseBetaAllowlist?
  private var vscodeAdapter: VSCodeAdapter?
  private var pluginRegistry: PluginRegistry?
  private var ollamaAdapter: OllamaAdapter?
  private var worktreeManager: WorktreeManager?
  private var codingTaskCoordinator: CodingTaskCoordinator?
  private var voiceResourceGovernor: VoiceResourceGovernor?
  private var multiAgentOrchestrator: MultiAgentOrchestrator?
  private var secretScanner: SecretScanner?
  private var injectionClassifier: PromptInjectionClassifier?
  private var networkAllowlist: NetworkAllowlist?
  private var started = false
  private var sttStarted = false
  private var audioStarted = false
  private var conversation: Conversation?

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
    guard started, let sttPipeline, let audio else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    if !sttStarted {
      do {
        try await sttPipeline.start()
        sttStarted = true
        await runtimeHealthRegistry?.recordReady("stt", detail: "speech recognition started")
      } catch {
        await runtimeHealthRegistry?.record(
          componentID: "stt", status: .failed,
          detail: "speech recognition failed to start: \(error.localizedDescription)")
        throw AuraError.sttEngineError(
          "STT pipeline failed to start: \(error.localizedDescription)")
      }
    }
    if !audioStarted {
      do {
        try await audio.start()
        audioStarted = true
        await runtimeHealthRegistry?.recordReady("audio", detail: "audio capture started")
      } catch {
        await runtimeHealthRegistry?.record(
          componentID: "audio", status: .failed,
          detail: "audio capture failed to start: \(error.localizedDescription)")
        throw error
      }
    }
  }

  func activatePushToTalk() async throws(AuraError) {
    guard sttStarted else {
      throw AuraError.permissionDenied("Speech recognition permission is required")
    }
    let context = TurnContext(
      sessionID: sessionID,
      activationSource: .pushToTalk,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .sensitive,
      timingOrigin: ProcessInfo.processInfo.systemUptime)
    let envelope = EventEnvelope(
      correlationID: context.correlationID,
      causationID: UUID(),
      actor: .user,
      sensitivity: .sensitive,
      payload: WakeActivationEvent(
        isActive: true, privacyMode: false, turnContext: context)
    )
    await eventBus.emit(envelope)
  }

  func submitText(_ text: String) async throws(AuraError) {
    guard started, let conversation else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    let context = TurnContext(
      sessionID: sessionID,
      activationSource: .text,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .sensitive,
      language: configuration.tts.defaultLocale,
      timingOrigin: ProcessInfo.processInfo.systemUptime)
    await conversation.submitTextTurn(text, context: context)
  }

  func triggerEmergencyStop() async {
    await emergencyStop?.trigger(source: .ui, reason: "User activated emergency stop")
  }

  func resetEmergencyStop() async {
    await emergencyStop?.reset(actor: .user)
  }

  func runtimeHealthSnapshot() async -> [RuntimeHealth] {
    await runtimeHealthRegistry?.snapshot() ?? []
  }

  func agentBackendHealthSnapshot() async -> [AgentBackendHealth] {
    await agentBackendHealthRegistry?.snapshot() ?? []
  }

  func refreshAgentBackendHealth(workspacePath: String? = nil) async -> [AgentBackendHealth] {
    await agentBackendHealthRegistry?.refreshAll(workspacePath: workspacePath) ?? []
  }

  func codingTaskPreflight(
    _ request: CodingTaskRequest
  ) async throws(AuraError) -> CodingTaskPreflight {
    guard started, let codingTaskCoordinator else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await codingTaskCoordinator.preflight(request)
  }

  func enqueueCodingTask(
    _ request: CodingTaskRequest
  ) async throws(AuraError) -> TaskStatus {
    guard started, let codingTaskCoordinator else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await codingTaskCoordinator.enqueue(request, actor: .user, sessionID: sessionID)
  }

  /// R3's `app.discover`, `app.hide`, `task.status`, `task.cancel`, and
  /// `capability.health` capabilities are reachable through these direct
  /// methods rather than the bilingual NLU classifier — the same
  /// reachability path `runtimeHealthSnapshot()`/`configurationInspection()`
  /// already use. Each still evaluates policy through the exact same
  /// `PolicyEngine` every `ToolRouter`-routed capability uses; only the
  /// dispatch path (direct call vs. classified intent) differs.
  private func evaluateDirectCapability(
    _ capability: Capability, target: PolicyTarget = .empty
  ) async throws(AuraError) {
    guard let policyEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    let request = PolicyEvaluationRequest(
      capability: capability, actor: .user, target: target, sessionID: sessionID,
      correlationID: UUID(), causationID: UUID())
    switch await policyEngine.evaluate(request) {
    case .allow:
      return
    case .deny(let reason, _):
      throw AuraError.permissionDenied(reason)
    case .confirm:
      // No confirmation presenter is wired for this direct-call path yet;
      // fail closed rather than silently proceed or silently auto-confirm.
      throw AuraError.permissionDenied(
        "\(capability.domain).\(capability.action) requires confirmation, "
          + "which this call path does not yet support")
    }
  }

  func discoverApplications() async throws(AuraError) {
    guard started, let automation else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.appDiscover)
    await automation.discoverApplications()
  }

  func hideApplication(bundleIdentifier: String) async throws(AuraError) {
    guard started, let automation else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.appHide, target: PolicyTarget(appID: bundleIdentifier))
    try await automation.hideApplication(bundleIdentifier: bundleIdentifier)
  }

  func taskStatus(id: UUID) async throws(AuraError) -> TaskStatus? {
    guard started, let taskEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.taskStatus)
    return await taskEngine.status(id: id)
  }

  /// R9's task-center projection. It uses the same policy gate as the
  /// single-task status capability and returns immutable snapshots only.
  func taskStatuses() async throws(AuraError) -> [TaskStatus] {
    guard started, let taskEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.taskStatus)
    return await taskEngine.allStatuses().sorted { $0.updatedAt > $1.updatedAt }
  }

  func taskCancel(id: UUID) async throws(AuraError) {
    guard started, let taskEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.taskCancel)
    try await taskEngine.cancel(id: id)
  }

  func capabilityHealthSnapshot() async throws(AuraError) -> [(
    CapabilityManifest, CapabilityAvailability?
  )] {
    guard started, let capabilityRegistry else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.capabilityHealthQuery)
    let manifests = await capabilityRegistry.allManifests()
    var result: [(CapabilityManifest, CapabilityAvailability?)] = []
    for manifest in manifests {
      result.append(
        (manifest, await capabilityRegistry.availability(qualifiedID: manifest.qualifiedID)))
    }
    return result
  }

  /// R9's user-inspectable memory projection. Audit/security records remain
  /// excluded by `MemoryEngine.inspect` and are never copied into the UI.
  func memoryRecordsSnapshot() async throws(AuraError) -> [MemoryRecord] {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await memoryEngine.inspect(includeSuperseded: false)
  }

  func correctMemoryRecord(
    id: UUID, newStatement: String, reason: String
  ) async throws(AuraError) -> MemoryRecord {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    let statement = newStatement.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !statement.isEmpty else {
      throw AuraError.memoryError("memory correction cannot be empty")
    }
    return try await memoryEngine.correct(
      recordID: id, newStatement: statement, reason: reason, actor: .user,
      sessionID: sessionID)
  }

  func deleteMemoryRecord(id: UUID, reason: String) async throws(AuraError) {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    _ = try await memoryEngine.deleteRecord(id: id, reason: reason, actor: .user)
  }

  func memoryExportData() async throws(AuraError) -> Data {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    let bundle = try await memoryEngine.export()
    let document = AuraMemoryExportDocument(
      generatedAt: Date(), records: bundle.records, conflicts: bundle.conflicts)
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      return try encoder.encode(document)
    } catch {
      throw AuraError.memoryError(
        "memory export could not be encoded: \(error.localizedDescription)")
    }
  }

  /// R4's `computerUse.run` capability: launch one bounded computer-use
  /// control-loop session against an approved, live-validated beta app.
  /// Policy is evaluated through the exact same `PolicyEngine` every other
  /// capability uses; the beta allowlist is the structural gate that keeps
  /// computer use from becoming a universal shortcut around missing adapters
  /// (unapproved apps are refused before any observation or action).
  func computerUseRun(
    appBundleIdentifier: String,
    objective: String
  ) async throws(AuraError) -> ComputerUseLoopOutcome {
    guard started, let computerUseLoop, let computerUseAllowlist, let screenEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(
      .computerUseRun, target: PolicyTarget(appID: appBundleIdentifier))
    guard computerUseAllowlist.isApproved(appBundleIdentifier) else {
      throw AuraError.permissionDenied(
        "computer-use target \(appBundleIdentifier) is not on the approved beta allowlist")
    }
    // Resolve an approved window for the target app. Computer use is
    // always app/window scoped; a session cannot start without a real
    // approved window belonging to the allowlisted application.
    let windows = try await screenEngine.listApprovedWindows()
    guard
      let window = windows.first(where: {
        $0.applicationBundleIdentifier == appBundleIdentifier
      })
    else {
      throw AuraError.computerUseError(
        "no approved window found for \(appBundleIdentifier)")
    }
    let target = ComputerUseSessionTarget(
      windowID: window.windowID,
      appBundleIdentifier: appBundleIdentifier,
      appName: window.applicationName)
    let planner = DeterministicComputerUsePlanner(allowlist: computerUseAllowlist)
    return await computerUseLoop.run(target: target, objective: objective, planner: planner)
  }

  func configurationInspection() async -> ConfigurationInspection? {
    await configurationEngine?.inspect()
  }

  func configurationAuditRecords() async -> [ConfigurationAuditRecord] {
    await configurationEngine?.auditRecords() ?? []
  }

  func setLocalRecommendationsEnabled(_ enabled: Bool) async throws(AuraError) {
    guard let configurationEngine else {
      throw AuraError.invalidConfiguration("configuration governance is not started")
    }
    let result = try await configurationEngine.apply(
      ConfigurationPatch(
        layer: .userSettings,
        values: ["privacy.localRecommendationsEnabled": .boolean(enabled)],
        source: "AURA Settings"),
      actor: .user)
    guard result.accepted else {
      throw AuraError.invalidConfiguration(result.warnings.joined(separator: "; "))
    }
  }

  // MARK: - Construction (dependency order)

  private func construct() async throws(AuraError) {
    let bundleID = configuration.app.bundleIdentifier
    let runtimeHealthRegistry = RuntimeHealthRegistry(eventBus: eventBus)
    self.runtimeHealthRegistry = runtimeHealthRegistry
    await runtimeHealthRegistry.recordReady("configuration", detail: "configuration loaded")
    let voiceResourceGovernor = VoiceResourceGovernor()
    await voiceResourceGovernor.start()
    self.voiceResourceGovernor = voiceResourceGovernor
    await runtimeHealthRegistry.recordReady(
      "voice-resources",
      detail:
        "bounded local voice reservations active for \(await voiceResourceGovernor.physicalMemoryMB()) MB physical memory"
    )
    configurationEngine = try await ConfigurationEngine.load(
      store: AuraStoreConfigurationStateStore(store: store))

    let policyEngine = try await PolicyEngine(
      configuration: configuration.policy, eventBus: eventBus, store: store)
    try await seedDefaultGrants(policyEngine)
    self.policyEngine = policyEngine
    await runtimeHealthRegistry.recordReady("policy", detail: "deny-by-default policy ready")

    let shell = AuraShell(configuration: configuration.shell)
    let automation = AuraAutomation(
      config: configuration.automation, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "automation"))
    self.automation = automation
    await runtimeHealthRegistry.recordReady("shell", detail: "typed shell constructed")
    await runtimeHealthRegistry.recordReady(
      "automation", detail: "structured automation constructed")

    let memory = MemoryEngine(store: store, eventBus: eventBus)
    self.memoryEngine = memory
    let context = ContextEngine(
      store: store, memory: memory, eventBus: eventBus, configuration: configuration.context)
    let contextBuilder = ContextBuilder(
      engine: context, memory: memory, eventBus: eventBus,
      configuration: configuration.context)
    await runtimeHealthRegistry.recordReady("memory", detail: "memory engine constructed")
    await runtimeHealthRegistry.recordReady("context", detail: "context engine constructed")

    let taskEngine = await AuraTaskEngine(
      store: store, eventBus: eventBus, configuration: configuration.task)
    try await taskEngine.recoverState()
    self.taskEngine = taskEngine
    await runtimeHealthRegistry.recordReady("tasks", detail: "durable task engine ready")

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
    let backendProbeRunner = AuraShellAgentBackendCommandRunner(
      shells: [
        .codex: AuraShell(configuration: configuration.codex.derivedShellConfiguration()),
        .claude: AuraShell(configuration: configuration.claude.derivedShellConfiguration()),
        .copilot: AuraShell(configuration: configuration.copilot.derivedShellConfiguration()),
      ])
    let agentHealthRegistry = AgentBackendHealthRegistry(
      probe: CLIAgentBackendHealthProbe(
        executablePaths: [
          .codex: configuration.codex.executablePath,
          .claude: configuration.claude.executablePath,
          .copilot: configuration.copilot.executablePath,
        ],
        runner: backendProbeRunner))
    self.agentBackendHealthRegistry = agentHealthRegistry
    let backendHealth = await agentHealthRegistry.refreshAll(
      workspacePath: configuration.intent.defaultCodingAgentWorkingDirectory)
    for health in backendHealth {
      let status: RuntimeHealthStatus
      switch health.state {
      case .ready:
        status = .ready
      case .degraded:
        status = .degraded
      case .unavailable:
        status = .dependencyMissing
      case .unauthorized:
        status = .permissionBlocked
      case .versionMismatch:
        status = .unsupported
      }
      await runtimeHealthRegistry.record(
        componentID: "agent.backend." + health.backend.rawValue,
        status: status,
        detail: health.detail)
    }
    let adapterHealthStatus: RuntimeHealthStatus =
      backendHealth.allSatisfy { $0.state == AgentBackendHealthState.ready }
      ? .ready
      : .degraded
    await runtimeHealthRegistry.record(
      componentID: "agent-adapters",
      status: adapterHealthStatus,
      detail: "adapters constructed; per-backend live version/auth/model evidence remains explicit")

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
    await runtimeHealthRegistry.record(
      componentID: "screen",
      status: configuration.screen.enabled ? .loading : .disabledByConfiguration,
      detail: configuration.screen.enabled
        ? "screen context awaiting capture" : "screen capture disabled by configuration")
    computerUseLoop = ComputerUseControlLoop(
      screenEngine: screenEngine,
      policyEngine: policyEngine,
      actionExecutor: AXCGEventActionExecutor(emergencyStop: emergencyStop),
      modalDetector: AccessibilityModalDialogDetector(),
      secureFieldDetector: secureFieldDetector,
      emergencyStop: emergencyStop,
      eventBus: eventBus,
      configuration: configuration.computerUse)
    // R4 beta allowlist: starts with the deliberately small curated set,
    // all `.disabled`; an app becomes reachable only after explicit live
    // validation (see `ComputerUseBetaAllowlist.validating`). Computer use
    // is therefore never a universal shortcut around missing adapters.
    self.computerUseAllowlist = ComputerUseBetaAllowlist.initial
    await runtimeHealthRegistry.recordReady(
      "computer-use", detail: "bounded computer-use loop constructed")
    vscodeAdapter = VSCodeAdapter(
      configuration: configuration.vscode,
      shell: shell,
      bridge: VSCodeFileBridge(statePath: configuration.vscode.bridgeStatePath),
      policyEngine: policyEngine)
    secretScanner = SecretScanner()
    injectionClassifier = PromptInjectionClassifier(configuration: configuration.security)
    networkAllowlist = NetworkAllowlist(configuration: configuration.security)
    await runtimeHealthRegistry.recordReady(
      "security", detail: "secret scanner and prompt-injection controls constructed")
    await runtimeHealthRegistry.recordReady("network", detail: "network allowlist constructed")
    await runtimeHealthRegistry.recordReady("vscode", detail: "VS Code adapter constructed")

    let verifier = PluginVerifier(
      trustRegistry: PluginTrustRegistry(configuration: configuration.plugins))
    let runtimeComponents: PluginRuntimeComponents?
    let pluginHealthDetail: String?
    do {
      runtimeComponents = try PluginRuntimeFactory.make(configuration: configuration.plugins)
      pluginHealthDetail = nil
    } catch {
      runtimeComponents = nil
      pluginHealthDetail = "plugin runtime unavailable: \(error.localizedDescription)"
    }
    if let pluginHealthDetail {
      await runtimeHealthRegistry.record(
        componentID: "plugins", status: .degraded,
        detail: "\(pluginHealthDetail); registry remains fail-closed")
    } else {
      await runtimeHealthRegistry.recordReady(
        "plugins", detail: "verified plugin runtime constructed")
    }
    pluginRegistry = try await PluginRegistry(
      verifier: verifier,
      policyEngine: policyEngine,
      store: store,
      eventBus: eventBus,
      artifactStore: runtimeComponents?.artifactStore,
      runtimeHost: runtimeComponents?.runtimeHost,
      configuration: configuration.plugins)
    let ollamaHealth: (RuntimeHealthStatus, String)
    do {
      ollamaAdapter = try OllamaAdapter(
        configuration: configuration.ollama,
        policyEngine: policyEngine,
        approvalPresenter: confirmationPresenter,
        eventBus: eventBus)
      ollamaHealth = (.ready, "adapter constructed")
    } catch {
      ollamaAdapter = nil
      ollamaHealth = (.degraded, "local model adapter unavailable: \(error.localizedDescription)")
    }
    await runtimeHealthRegistry.record(
      componentID: "ollama",
      status: ollamaHealth.0,
      detail: ollamaHealth.1)
    let worktreeManager = WorktreeManager(
      configuration: configuration.worktree,
      policyEngine: policyEngine,
      eventBus: eventBus)
    self.worktreeManager = worktreeManager
    await runtimeHealthRegistry.recordReady(
      "worktrees", detail: "isolated worktree manager constructed")
    self.codingTaskCoordinator = CodingTaskCoordinator(
      taskEngine: taskEngine,
      backendRunner: agentTaskRunner,
      healthRegistry: agentHealthRegistry,
      worktreeManager: worktreeManager)
    await runtimeHealthRegistry.recordReady(
      "coding-tasks",
      detail: "workspace/backend/worktree/durable-task coordinator constructed")
    multiAgentOrchestrator = MultiAgentOrchestrator(
      worktreeManager: worktreeManager,
      policyEngine: policyEngine,
      validationShell: shell,
      eventBus: eventBus)
    await runtimeHealthRegistry.recordReady(
      "multi-agent", detail: "bounded multi-agent orchestrator constructed")

    let dialogueBackend: (any DialogueReasoningBackend)? = ollamaAdapter
    let structuredNLUBackend: (any StructuredNLUBackend)? = ollamaAdapter
    let dialogueEngine = DialogueEngine(
      reasoningBackend: dialogueBackend,
      runtimeHealthRegistry: runtimeHealthRegistry)
    let capabilityRegistry = CapabilityRegistry()
    await InitialCapabilitySet.registerAll(in: capabilityRegistry)
    self.capabilityRegistry = capabilityRegistry
    await runtimeHealthRegistry.recordReady(
      "capabilityRegistry",
      detail: "\(InitialCapabilitySet.manifests().count) capabilities registered")
    let toolRouter = ToolRouter(
      policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
      agentTaskRunner: agentTaskRunner, capabilityRegistry: capabilityRegistry,
      confirmationPresenter: confirmationPresenter, eventBus: eventBus,
      configuration: configuration.intent, dialogueEngine: dialogueEngine,
      codingTaskCoordinator: codingTaskCoordinator)
    let intentEngine = IntentEngine(
      classifier: RuleBasedUtteranceClassifier(), contextEngine: context,
      contextBuilder: contextBuilder, memoryEngine: memory,
      structuredNLUBackend: structuredNLUBackend,
      configuration: configuration.intent, eventBus: eventBus,
      sessionID: sessionID)

    let audio = AuraAudio(
      configuration: configuration.audio, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "audio"))
    self.audio = audio

    let vad = EnergyVAD(silenceFrames: configuration.wake.vadSilenceFrames)
    let wakeDetector = DisabledWakeWordDetector()
    let wakeWordPipeline = WakeWordPipeline(
      configuration: configuration.wake, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "wake"), vad: vad,
      wakeDetector: wakeDetector, sessionID: sessionID)
    self.wakeWordPipeline = wakeWordPipeline
    await runtimeHealthRegistry.record(
      componentID: "wake-word", status: .unsupported,
      detail: "trained acoustic wake-word model is not bundled; Push to Talk is supported")

    let deterministicPhrases = configuration.conversation.deterministicStopCommands.union(
      configuration.conversation.deterministicPauseResumeCommands)
    let vocabulary = UserVocabulary(
      deterministicCommands: Dictionary(
        uniqueKeysWithValues: deterministicPhrases.map { ($0, $0) }))
    let sttEngine = Self.makeSTTEngine(
      configuration: configuration.stt, vocabulary: vocabulary,
      governor: voiceResourceGovernor)
    let sttPipeline = STTPipeline(
      engine: sttEngine, vocabulary: vocabulary, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "stt"), sessionID: sessionID)
    self.sttPipeline = sttPipeline
    await runtimeHealthRegistry.record(
      componentID: "stt",
      status: .loading,
      detail: "awaiting explicit speech permission and start")

    let ttsEngine = await Self.makeTTSEngine(
      adapterChain: configuration.tts.adapterChain,
      preferredSystemVoiceIdentifier: configuration.tts.preferredSystemVoiceIdentifier,
      logger: AuraLogger(subsystem: bundleID, category: "tts"),
      governor: voiceResourceGovernor)
    let ttsHealth = ttsEngine.health()
    await runtimeHealthRegistry.record(
      componentID: "tts",
      status: ttsHealth.ready ? .ready : .degraded,
      detail: "\(ttsEngine.engineID): \(ttsHealth.detail)")

    let conversation = Conversation(
      configuration: configuration.conversation, ttsConfiguration: configuration.tts,
      ttsEngine: ttsEngine, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "conversation"),
      monotonicClock: { CFAbsoluteTimeGetCurrent() }, sessionID: sessionID)
    self.conversation = conversation

    let performanceSampler = PerformanceSampler(
      logger: AuraLogger(subsystem: bundleID, category: "performance"))

    intentDispatchCoordinator = IntentDispatchCoordinator(
      intentEngine: intentEngine, toolRouter: toolRouter, conversation: conversation,
      eventBus: eventBus, sessionID: sessionID)
    conversationEventBridge = ConversationEventBridge(
      conversation: conversation, eventBus: eventBus, sessionID: sessionID)
    audioSampleBridge = AudioSampleBridge(
      audio: audio, wakeWordPipeline: wakeWordPipeline, sttPipeline: sttPipeline,
      eventBus: eventBus, enableWakeDetection: false,
      pushToTalkFinalizer: PushToTalkSessionFinalizer(
        vad: EnergyVAD(silenceFrames: configuration.conversation.silenceEndFrames),
        eventBus: eventBus,
        maxDurationSeconds: min(
          7, max(1, configuration.conversation.listenTimeoutSeconds - 2))))
    self.performanceSampler = performanceSampler
    await runtimeHealthRegistry.record(
      componentID: "audio", status: .loading,
      detail: "awaiting explicit speech permission and start")
    await runtimeHealthRegistry.recordReady(
      "conversation", detail: "turn state machine constructed")
    await runtimeHealthRegistry.recordReady("intent", detail: "intent dispatch constructed")
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
    // .reversible tier, no side effects, and OllamaPolicyAdapter only maps a
    // model to this capability when its /api/tags entry reports no
    // remote_host (isLocal), so the prompt never leaves the device — see
    // ADR-036. Matches .appActivate's .none confirmation for a similarly
    // reversible, non-destructive capability. Cloud-proxied inference keeps
    // its .destructive tier and remains deny-by-default; no grant is added
    // for it here.
    try await policyEngine.issueGrant(
      Grant(
        capability: .agentOllamaLocalInference, patterns: [.any],
        confirmationRequirement: .none))
  }

  /// Build the configured TTS engine chain. Chatterbox V3 runs in a separate,
  /// local helper and owns a female system fallback, so warm-up or runtime
  /// failure never leaves the conversation voiceless.
  private static func makeTTSEngine(
    adapterChain: TTSAdapterChain,
    preferredSystemVoiceIdentifier: String,
    logger: AuraLogger,
    governor: VoiceResourceGovernor? = nil
  ) async -> any TTSEngine {
    for adapterID in adapterChain.adapterIDs {
      switch adapterID {
      case "chatterbox":
        let helperScriptPath = Bundle.main.resourceURL?
          .appendingPathComponent("Chatterbox/chatterbox_helper.py")
          .path
        let fallback = SystemTTSEngine(
          preferredVoiceIdentifier: preferredSystemVoiceIdentifier)
        let engine = ChatterboxTTSEngine(
          configuration: .installed(helperScriptPath: helperScriptPath),
          fallback: fallback,
          resourceGovernor: governor)
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
        let engine = SystemTTSEngine(
          preferredVoiceIdentifier: preferredSystemVoiceIdentifier)
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
    let fallback = SystemTTSEngine(
      preferredVoiceIdentifier: preferredSystemVoiceIdentifier)
    do {
      _ = try await fallback.start()
    } catch {
      await logger.error("System TTS fallback failed: \(error)", actor: .audio)
    }
    return fallback
  }

  /// Build the configured STT engine. Supports `native-speech` for on-device
  /// `Speech.framework` streaming recognition, `mock-stt` for deterministic
  /// tests, and the legacy placeholder as a final fallback. The locale and
  /// vocabulary are taken from `STTConfiguration`.
  private static func makeSTTEngine(
    configuration: STTConfiguration,
    vocabulary: UserVocabulary,
    governor: VoiceResourceGovernor? = nil
  ) -> any STTEngine {
    switch configuration.engineID {
    case "native-speech":
      return STTRouter(
        candidates: [
          SystemSTTEngine(
            locale: Locale(identifier: configuration.locale),
            vocabulary: vocabulary,
            enableCustomVocabulary: configuration.enableCustomVocabulary),
          SystemSTTEngine(
            engineID: "native-speech-fallback",
            locale: Locale(identifier: configuration.fallbackLocale),
            vocabulary: vocabulary,
            enableCustomVocabulary: configuration.enableCustomVocabulary),
        ],
        governor: governor)
    case "native-speech-single":
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
    guard let taskEngine, let agentTaskRunner, let wakeWordPipeline,
      let intentDispatchCoordinator, let conversationEventBridge, let audioSampleBridge,
      let performanceSampler
    else {
      throw AuraError.invalidConfiguration("AuraKernel.startPipeline called before construct()")
    }

    await taskEngine.start(runner: agentTaskRunner)
    await performanceSampler.start(on: eventBus)
    await voiceResourceGovernor?.start()
    await wakeWordPipeline.start()
    await intentDispatchCoordinator.start()
    await conversationEventBridge.start()
    await audioSampleBridge.start()
  }

  private func shutdownPipeline() async {
    if audioStarted {
      await audio?.stop()
      audioStarted = false
    }
    await audioSampleBridge?.stop()
    await wakeWordPipeline?.stop()
    if sttStarted {
      await sttPipeline?.stop()
      sttStarted = false
    }
    await voiceResourceGovernor?.stop()
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
