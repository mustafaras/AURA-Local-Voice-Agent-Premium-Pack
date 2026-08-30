import CryptoKit
import Foundation

extension Capability {
  public static let fileRead = Capability(domain: "file", action: "read", riskTier: .observation)
  public static let fileWrite = Capability(domain: "file", action: "write", riskTier: .mutation)
  public static let fileDelete = Capability(
    domain: "file", action: "delete", riskTier: .destructive)
  public static let shellExec = Capability(domain: "shell", action: "exec", riskTier: .mutation)
  public static let appActivate = Capability(
    domain: "app", action: "activate", riskTier: .reversible)
  public static let appTerminate = Capability(
    domain: "app", action: "terminate", riskTier: .mutation)
  public static let screenCapture = Capability(
    domain: "screen", action: "capture", riskTier: .observation)
  public static let screenReadText = Capability(
    domain: "screen", action: "readText", riskTier: .observation)
  public static let agentRun = Capability(domain: "agent", action: "run", riskTier: .destructive)
  public static let networkRequest = Capability(
    domain: "network", action: "request", riskTier: .destructive)
  public static let systemChangePrivilege = Capability(
    domain: "system", action: "changePrivilege", riskTier: .destructive)

  public static let vscodeOpen = Capability(domain: "vscode", action: "open", riskTier: .reversible)
  public static let vscodeInjectTerminal = Capability(
    domain: "vscode", action: "injectTerminal", riskTier: .mutation)
  public static let vscodeManageExtension = Capability(
    domain: "vscode", action: "manageExtension", riskTier: .mutation)
  public static let vscodeObserveState = Capability(
    domain: "vscode", action: "observeState", riskTier: .observation)
  public static let vscodeWorkspaceStatus = Capability(
    domain: "vscode", action: "workspaceStatus", riskTier: .observation)
  public static let vscodeDiagnostics = Capability(
    domain: "vscode", action: "diagnostics", riskTier: .observation)
  public static let vscodeRunTask = Capability(
    domain: "vscode", action: "runTask", riskTier: .reversible)
  public static let vscodeCancelTask = Capability(
    domain: "vscode", action: "cancelTask", riskTier: .reversible)
  public static let vscodeRunTests = Capability(
    domain: "vscode", action: "runTests", riskTier: .reversible)
  public static let vscodeCancelTests = Capability(
    domain: "vscode", action: "cancelTests", riskTier: .reversible)
  public static let vscodeBridgeHealth = Capability(
    domain: "vscode", action: "bridgeHealth", riskTier: .observation)

  public static let taskEnqueue = Capability(
    domain: "task", action: "enqueue", riskTier: .reversible)
  public static let taskCancel = Capability(
    domain: "task", action: "cancel", riskTier: .reversible)
  public static let taskPause = Capability(
    domain: "task", action: "pause", riskTier: .reversible)
  public static let taskResume = Capability(
    domain: "task", action: "resume", riskTier: .reversible)
  public static let taskRetry = Capability(
    domain: "task", action: "retry", riskTier: .reversible)
  public static let taskDelete = Capability(
    domain: "task", action: "delete", riskTier: .destructive)
  public static let taskList = Capability(
    domain: "task", action: "list", riskTier: .observation)
  public static let taskStatus = Capability(
    domain: "task", action: "status", riskTier: .observation)

  public static let appDiscover = Capability(
    domain: "app", action: "discover", riskTier: .observation)
  public static let appHide = Capability(domain: "app", action: "hide", riskTier: .reversible)

  public static let fileOpen = Capability(domain: "file", action: "open", riskTier: .reversible)
  public static let fileReveal = Capability(
    domain: "file", action: "reveal", riskTier: .reversible)
  public static let urlOpen = Capability(domain: "url", action: "open", riskTier: .reversible)

  /// Read the currently approved browser profile/tab through a structured
  /// browser integration. Page text remains external, non-authoritative data.
  public static let browserRead = Capability(
    domain: "browser", action: "read", riskTier: .observation)
  /// Read mail metadata and approved message content through a configured
  /// provider adapter. Reading is sensitive data access but not external
  /// communication; the adapter remains account- and scope-bound.
  public static let mailRead = Capability(
    domain: "mail", action: "read", riskTier: .observation)
  /// Read calendar events through an explicitly authorized provider or
  /// EventKit store.
  public static let calendarRead = Capability(
    domain: "calendar", action: "read", riskTier: .observation)
  /// Resolve only the contact candidates needed for the current request.
  public static let contactsLookup = Capability(
    domain: "contacts", action: "lookup", riskTier: .observation)
  /// Escalate an integration from read-only to compose/send or write access.
  /// This is deliberately destructive-tier and is never caller-supplied as a
  /// raw OAuth scope string.
  public static let oauthEscalate = Capability(
    domain: "oauth", action: "escalate", riskTier: .destructive)

  public static let capabilityHealthQuery = Capability(
    domain: "capability", action: "health", riskTier: .observation)

  /// Run the Codex CLI with a workspace-write sandbox (may modify files).
  public static let agentCodexRun = Capability(
    domain: "agent", action: "codexRun", riskTier: .destructive)
  /// Run the Codex CLI with a read-only sandbox (observation only).
  public static let agentCodexReadOnly = Capability(
    domain: "agent", action: "codexReadOnly", riskTier: .reversible)

  /// Run the Claude Code CLI with write-capable tools (Bash/Edit/Write).
  public static let agentClaudeRun = Capability(
    domain: "agent", action: "claudeRun", riskTier: .destructive)
  /// Run the Claude Code CLI with read-only tools only.
  public static let agentClaudeReadOnly = Capability(
    domain: "agent", action: "claudeReadOnly", riskTier: .reversible)

  /// Run the GitHub Copilot CLI with broad tool approval (`--allow-all-tools`).
  public static let agentCopilotRun = Capability(
    domain: "agent", action: "copilotRun", riskTier: .destructive)
  /// Run the GitHub Copilot CLI with no tools available (conversational only).
  public static let agentCopilotReadOnly = Capability(
    domain: "agent", action: "copilotReadOnly", riskTier: .reversible)

  /// Run inference against a genuinely local Ollama model (no `remote_host`
  /// on the tag entry) — prompt content never leaves the device.
  public static let agentOllamaLocalInference = Capability(
    domain: "agent", action: "ollamaLocalInference", riskTier: .reversible)
  /// Run inference against an Ollama `:cloud` model whose tag entry reports a
  /// `remote_host` — the prompt is proxied to Ollama's hosted backend, which
  /// is external communication / sensitive-data access under this tier.
  public static let agentOllamaCloudInference = Capability(
    domain: "agent", action: "ollamaCloudInference", riskTier: .destructive)

  /// Create an isolated `git worktree` for a multi-agent orchestration task.
  /// A real directory and branch are created on disk, so this is a mutation,
  /// not merely reversible — matching `Capability.fileWrite`'s tier.
  public static let agentWorktreeCreate = Capability(
    domain: "agent", action: "worktreeCreate", riskTier: .mutation)
  /// Remove a previously created orchestration worktree (`git worktree
  /// remove`, optionally `--force` over uncommitted changes).
  public static let agentWorktreeRemove = Capability(
    domain: "agent", action: "worktreeRemove", riskTier: .mutation)

  /// Read-only computer-use control loop observation (screen/accessibility
  /// state already gated by `Capability.screenCapture`/`.screenReadText`;
  /// this capability governs the control loop's own observation bookkeeping).
  public static let computerUseObserve = Capability(
    domain: "computerUse", action: "observe", riskTier: .observation)
  /// A reversible computer-use action step (e.g. navigating, toggling a
  /// control) that does not mutate persistent state or leave the app.
  public static let computerUseInteract = Capability(
    domain: "computerUse", action: "interact", riskTier: .reversible)
  /// A computer-use action step that mutates local state (e.g. filling or
  /// submitting a field) without external communication or deletion.
  public static let computerUseMutate = Capability(
    domain: "computerUse", action: "mutate", riskTier: .mutation)
  /// A computer-use action step whose semantic intent is one of the named
  /// destructive categories (send, publish, purchase, delete, deploy, accept
  /// legal terms, authenticate) — see
  /// `ComputerUseSemanticIntent.mandatoryConfirmationIntents`.
  public static let computerUseDestructiveAct = Capability(
    domain: "computerUse", action: "destructiveAct", riskTier: .destructive)

  /// Launching a bounded computer-use control-loop session against an
  /// approved application (the R4 product capability "run bounded
  /// objective"). Mutation tier because it drives a live UI; combined with
  /// `ComputerUseBetaAllowlist` and the mandatory-confirmation gates it
  /// still cannot act on unapproved apps or unbounded objectives.
  public static let computerUseRun = Capability(
    domain: "computerUse", action: "run", riskTier: .mutation)

  /// Deterministic mapping from a computer-use step's semantic intent to the
  /// capability it must be evaluated under, mirroring
  /// `ComputerUseSemanticIntent.riskTier` exactly so a step can never be
  /// evaluated at a tier lower than the one its own declared intent implies.
  public static func forComputerUse(intent: ComputerUseSemanticIntent) -> Capability {
    switch intent.riskTier {
    case .observation: return .computerUseObserve
    case .reversible: return .computerUseInteract
    case .mutation: return .computerUseMutate
    case .destructive: return .computerUseDestructiveAct
    case .network: return .computerUseDestructiveAct
    }
  }

  /// Store a secret value in the platform secure store (Keychain). Writing
  /// a new credential is sensitive-data access, matching `PermissionRiskTier
  /// .destructive`'s own doc comment ("...or sensitive-data access").
  public static let secretStore = Capability(
    domain: "secret", action: "store", riskTier: .destructive)
  /// Retrieve a previously stored secret value. Reading a credential back
  /// out is equally sensitive as writing it — never a lower tier.
  public static let secretRetrieve = Capability(
    domain: "secret", action: "retrieve", riskTier: .destructive)
  /// Remove a stored secret. Deleting a credential reference is reversible
  /// only in the sense that a new one can be stored again; it does not
  /// itself expose or mutate other data, so it is scoped one tier below
  /// store/retrieve.
  public static let secretDelete = Capability(
    domain: "secret", action: "delete", riskTier: .mutation)

  /// Accept a new plugin manifest into the registry after signature/hash
  /// verification. Installing new code is destructive-tier: it introduces a
  /// new authority surface the policy engine must subsequently gate.
  public static let pluginInstall = Capability(
    domain: "plugin", action: "install", riskTier: .destructive)
  /// Enable a previously installed, disabled plugin.
  public static let pluginEnable = Capability(
    domain: "plugin", action: "enable", riskTier: .mutation)
  /// Disable an enabled plugin. Reversible: re-enabling restores prior state.
  public static let pluginDisable = Capability(
    domain: "plugin", action: "disable", riskTier: .reversible)
  /// Quarantine a plugin, blocking it from obtaining grants or emitting
  /// events regardless of its enabled/disabled state. A protective action,
  /// not a destructive one — it only removes authority, never grants it.
  public static let pluginQuarantine = Capability(
    domain: "plugin", action: "quarantine", riskTier: .reversible)
  /// Permanently remove a plugin's registry entry and revoke its grants.
  public static let pluginUninstall = Capability(
    domain: "plugin", action: "uninstall", riskTier: .mutation)
  /// Replace an installed plugin with a newly verified version.
  public static let pluginUpdate = Capability(
    domain: "plugin", action: "update", riskTier: .destructive)
  /// Restore a previously verified, locally retained plugin version.
  public static let pluginRollback = Capability(
    domain: "plugin", action: "rollback", riskTier: .destructive)
  /// Cross the isolated plugin-runtime boundary for one declared action.
  public static let pluginExecute = Capability(
    domain: "plugin", action: "execute", riskTier: .mutation)

  /// A plain conversational turn with no tool dispatch. `.observation`
  /// tier — always allowed by default, never denied or confirmed.
  public static let intentConverse = Capability(
    domain: "intent", action: "converse", riskTier: .observation)

  // MARK: Lifecycle / updater / recovery capabilities

  public static let lifecycleLaunchAtLogin = Capability(
    domain: "lifecycle", action: "launchAtLogin", riskTier: .mutation)
  public static let lifecycleCheckUpdate = Capability(
    domain: "lifecycle", action: "checkUpdate", riskTier: .network)
  public static let lifecycleApproveUpdate = Capability(
    domain: "lifecycle", action: "approveUpdate", riskTier: .destructive)
  public static let lifecycleStageUpdate = Capability(
    domain: "lifecycle", action: "stageUpdate", riskTier: .destructive)
  public static let lifecycleRollback = Capability(
    domain: "lifecycle", action: "rollback", riskTier: .destructive)
  public static let lifecycleSafeMode = Capability(
    domain: "lifecycle", action: "safeMode", riskTier: .mutation)
  public static let lifecycleReset = Capability(
    domain: "lifecycle", action: "reset", riskTier: .destructive)
  public static let lifecycleSupportBundle = Capability(
    domain: "lifecycle", action: "supportBundle", riskTier: .observation)
  public static let lifecycleMigrationPreflight = Capability(
    domain: "lifecycle", action: "migrationPreflight", riskTier: .observation)
  public static let lifecycleUninstall = Capability(
    domain: "lifecycle", action: "uninstall", riskTier: .destructive)
  public static let lifecycleFactoryReset = Capability(
    domain: "lifecycle", action: "factoryReset", riskTier: .destructive)

  /// A shell command matched a conservative destructive-pattern denylist
  /// (`IntentSemanticCategory.shellDestructive`). Distinct from `.shellExec`
  /// so a grant scoped to ordinary shell execution can never silently cover
  /// a recognized-destructive command too.
  public static let shellExecDestructive = Capability(
    domain: "shell", action: "execDestructive", riskTier: .destructive)

  /// Deterministic mapping from a classified intent's semantic category to
  /// the capability `ToolRouter` evaluates, mirroring `Capability
  /// .forComputerUse(intent:)` exactly.
  ///
  /// `.codingAgentRun` maps to the generic destructive `.agentRun` metadata
  /// capability. The chosen CLI adapter still performs the authoritative
  /// backend-specific policy evaluation (`agentCodexRun`, `agentClaudeRun`, or
  /// `agentCopilotRun`) before execution; this generic mapping prevents
  /// context/planning metadata from incorrectly presenting the turn as plain
  /// conversation without adding a redundant router-side authorization.
  public static func forIntent(_ category: IntentSemanticCategory) -> Capability {
    switch category {
    case .converse: return .intentConverse
    case .appActivate: return .appActivate
    case .appTerminate: return .appTerminate
    case .shellExecute: return .shellExec
    case .shellDestructive: return .shellExecDestructive
    case .codingAgentRun: return .agentRun
    case .fileOpen: return .fileOpen
    case .fileReveal: return .fileReveal
    case .urlOpen: return .urlOpen
    // SP-010. Each maps to the observation-tier read capability that already
    // existed for it. No read category borrows a broader capability, and none
    // maps to `.oauthEscalate`, which therefore stays unreachable from any
    // classified utterance.
    case .browserRead: return .browserRead
    case .mailRead: return .mailRead
    case .calendarRead: return .calendarRead
    case .contactsLookup: return .contactsLookup
    case .unknown: return .intentConverse
    }
  }

  /// Convenience identifier used for pattern matching and event logging.
  public var identifier: String { "\(domain).\(action)" }
}
