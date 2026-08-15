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
  let configuration: AuraConfiguration
  let store: AuraStore
  let eventBus: AuraEventBus
  let logger: AuraLogger
  let confirmationPresenter: any AuraConfirmationPresenting
  let sessionID = UUID()

  var runtimeHealthRegistry: RuntimeHealthRegistry?
  var policyEngine: PolicyEngine?
  var taskEngine: AuraTaskEngine?
  var memoryEngine: MemoryEngine?
  var automation: AuraAutomation?
  var capabilityRegistry: CapabilityRegistry?
  var agentTaskRunner: AgentBackendTaskRunner?
  var agentBackendHealthRegistry: AgentBackendHealthRegistry?
  var audio: AuraAudio?
  var wakeWordPipeline: WakeWordPipeline?
  var sttPipeline: STTPipeline?
  var intentDispatchCoordinator: IntentDispatchCoordinator?
  var conversationEventBridge: ConversationEventBridge?
  var audioSampleBridge: AudioSampleBridge?
  var performanceSampler: PerformanceSampler?
  var configurationEngine: ConfigurationEngine?
  var emergencyStop: EmergencyStopController?
  var screenEngine: ScreenContextEngine?
  var computerUseLoop: ComputerUseControlLoop?
  var computerUseAllowlist: ComputerUseBetaAllowlist?
  var vscodeAdapter: VSCodeAdapter?
  var pluginRegistry: PluginRegistry?
  var ollamaAdapter: OllamaAdapter?
  var worktreeManager: WorktreeManager?
  var codingTaskCoordinator: CodingTaskCoordinator?
  var voiceResourceGovernor: VoiceResourceGovernor?
  var multiAgentOrchestrator: MultiAgentOrchestrator?
  var secretScanner: SecretScanner?
  var injectionClassifier: PromptInjectionClassifier?
  var networkAllowlist: NetworkAllowlist?
  var started = false
  var sttStarted = false
  var audioStarted = false
  var conversation: Conversation?

  var shutdownContinuation: CheckedContinuation<Void, Never>?
  var sigintSource: DispatchSourceSignal?
  var sigtermSource: DispatchSourceSignal?

  init(
    configuration: AuraConfiguration,
    store: AuraStore,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    confirmationPresenter: any AuraConfirmationPresenting? = nil
  ) {
    self.configuration = configuration
    self.store = store
    self.eventBus = eventBus
    self.logger = logger
    // For unattended text-only evidence runs (AURA_TEXT_DEMO_SCRIPT), use an
    // auto-allow confirmation presenter so the typed-input path can exercise
    // side-effecting intents without a GUI. Production default remains safe-deny.
    let textDemoPath = ProcessInfo.processInfo.environment["AURA_TEXT_DEMO_SCRIPT"]
    if let presenter = confirmationPresenter {
      self.confirmationPresenter = presenter
    } else if textDemoPath != nil {
      self.confirmationPresenter = AutoAllowConfirmationPresenter()
    } else {
      self.confirmationPresenter = SafeDenyConfirmationPresenter()
    }
  }

}
