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

  enum CodingKeys: String, CodingKey {
    case app, audio, wake, stt, tts, conversation, policy, automation, shell, vscode, task
    case codex, claude, copilot, ollama, worktree, context, screen, computerUse, privacy, log
    case security, plugins, intent
  }

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

}
