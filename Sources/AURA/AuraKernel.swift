import AuraAgent
import AuraAudio
import AuraAutomation
import AuraContext
import AuraCore
import AuraIntent
import AuraMemory
import AuraPolicy
import AuraSTT
import AuraShell
import AuraStore
import AuraTasks
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

  private var shutdownContinuation: CheckedContinuation<Void, Never>?
  private var sigintSource: DispatchSourceSignal?
  private var sigtermSource: DispatchSourceSignal?

  init(
    configuration: AuraConfiguration, store: AuraStore, eventBus: AuraEventBus, logger: AuraLogger
  ) {
    self.configuration = configuration
    self.store = store
    self.eventBus = eventBus
    self.logger = logger
  }

  /// Construct every subsystem, start the pipeline, and block until a
  /// shutdown signal (SIGINT/SIGTERM) is received.
  func run() async throws(AuraError) {
    try await construct()
    try await startPipeline()
    installSignalHandlers()
    await logger.info(
      "AuraKernel running; wake pipeline armed", actor: .system)
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      self.shutdownContinuation = continuation
    }
    await shutdownPipeline()
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

    let taskEngine = await AuraTaskEngine(
      store: store, eventBus: eventBus, configuration: configuration.task)
    try await taskEngine.recoverState()
    self.taskEngine = taskEngine

    let sessionID = UUID()
    let codexAdapter = CodexAdapter(
      configuration: configuration.codex, policyEngine: policyEngine, eventBus: eventBus)
    let claudeAdapter = ClaudeAdapter(
      configuration: configuration.claude, policyEngine: policyEngine, eventBus: eventBus)
    let copilotAdapter = CopilotAdapter(
      configuration: configuration.copilot, policyEngine: policyEngine, eventBus: eventBus)
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

    let toolRouter = ToolRouter(
      policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
      agentTaskRunner: agentTaskRunner, registry: .defaultRegistry(),
      confirmationPresenter: IntentAlwaysDenyConfirmationPresenter(), eventBus: eventBus,
      configuration: configuration.intent)
    let intentEngine = IntentEngine(
      classifier: RuleBasedUtteranceClassifier(), contextEngine: context,
      configuration: configuration.intent, eventBus: eventBus)

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
    let sttPipeline = STTPipeline(
      engine: Self.placeholderSTTEngine(), vocabulary: vocabulary, eventBus: eventBus,
      logger: AuraLogger(subsystem: bundleID, category: "stt"))
    self.sttPipeline = sttPipeline

    let conversation = Conversation(
      configuration: configuration.conversation, ttsConfiguration: configuration.tts,
      ttsEngine: MockTTSEngine(), eventBus: eventBus,
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
      eventBus: eventBus)
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

  /// No real STT engine exists yet — `Sources/AuraSTT` has only
  /// `DeterministicMockSTTEngine`. A single generic placeholder segment
  /// lets `STTPipeline.start()` succeed (it requires a non-empty script);
  /// it only ever fires after a real wake-word activation, which itself
  /// requires the synthetic marker tone `MarkerWakeWordDetector` listens
  /// for — an ordinary spoken launch never triggers it. This is not an
  /// auto-playing demo; it is the honest, already-documented consequence of
  /// "no real STT integration yet" (`ledger/CURRENT_STATE.md`), made
  /// unavoidable to face once the pipeline is actually wired together. Real
  /// STT integration is explicit future work.
  private static func placeholderSTTEngine() -> any STTEngine {
    DeterministicMockSTTEngine(
      script: [
        DeterministicMockSTTEngine.MockSegment(text: "hello", expectedFrameCount: 1)
      ])
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
    try await sttPipeline.start()
    await intentDispatchCoordinator.start()
    await conversationEventBridge.start()
    await audioSampleBridge.start()
    try await audio.start()
  }

  private func shutdownPipeline() async {
    await audio?.stop()
    await wakeWordPipeline?.stop()
    await sttPipeline?.stop()
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
