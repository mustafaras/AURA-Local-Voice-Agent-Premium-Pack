import AuraAgent
import AuraAudio
import AuraAutomation
import AuraComputerUse
import AuraConfig
import AuraContext
import AuraCore
import AuraIntent
import AuraLifecycle
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
  var preferenceProfileStore: UserPreferenceProfileStore?
  var automation: AuraAutomation?
  /// SP-004's typed adapter behind `filesystem.open_file`,
  /// `filesystem.open_folder`, `filesystem.reveal`, and `url.open`. Reachable
  /// through the direct-call methods in `AuraKernel_RuntimeAPI`, which apply
  /// the same `PolicyEngine` gate every routed capability uses. No NLU or UI
  /// reachability is claimed for these four — that is SP-005's objective.
  var fileSystemURLOpener: FileSystemURLOpener?
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
  /// SP-012: the Keychain-backed symmetric secret store for the authenticated
  /// VS Code extension bridge. Retained so the kernel can provision and revoke
  /// the shared secret through a user-controlled path without exposing the
  /// value. Rebuilt after construction because `constructVSCodeAdapter`
  /// derives the bridge's authenticator from it.
  var vscodeBridgeSecretStore: VSCodeBridgeSecretStore?
  var pluginRegistry: PluginRegistry?
  var ollamaAdapter: OllamaAdapter?
  var worktreeManager: WorktreeManager?
  var codingTaskCoordinator: CodingTaskCoordinator?
  var voiceResourceGovernor: VoiceResourceGovernor?
  var multiAgentOrchestrator: MultiAgentOrchestrator?
  var secretScanner: SecretScanner?
  var injectionClassifier: PromptInjectionClassifier?
  var networkAllowlist: NetworkAllowlist?
  /// SP-009's Safari read bridge. Constructed in the composition root but the
  /// `browser.read` capability stays disabled until the live package and trust
  /// path are verified; `safariBridgeRuntime?.availability()` reports the
  /// truthful state.
  var safariBridgeRuntime: SafariBridgeRuntime?
  /// SP-010's read-first productivity composition: onboarding plus the
  /// browser, mail, calendar, and contacts adapters. The four capabilities'
  /// registry availability is recomputed from this runtime rather than
  /// declared, so the health surface cannot claim a state the composition
  /// does not actually have.
  var productivityRuntime: ProductivityRuntime?
  var lifecycleController: LaunchAtLoginController?
  var updateEngine: UpdateEngine?
  var safeModeController: SafeModeController?
  var resetController: ResetController?
  var lifecycleObserver: LifecycleObserver?
  var supportBundleExporter: SupportBundleExporter?
  var telemetryAggregator: TelemetryAggregator?
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
