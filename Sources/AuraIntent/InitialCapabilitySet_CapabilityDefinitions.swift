import AuraCore
import Foundation

extension InitialCapabilitySet {
  public static func registerAll(in registry: CapabilityRegistry) async {
    for (manifest, availability) in manifests() {
      await registry.register(manifest, availability: availability)
    }
  }

  public static func manifests() -> [(CapabilityManifest, CapabilityAvailability)] {
    manifestEntries
  }

  private static let manifestEntries: [(CapabilityManifest, CapabilityAvailability)] = [
    (converse, .ready),
    (appActivate, .ready),
    (appTerminate, .ready),
    (shellExecuteTyped, .ready),
    (codingAgentRun, .ready),
    (appDiscover, .ready),
    (appHide, .ready),
    (taskStatus, .ready),
    (taskCancel, .ready),
    (capabilityHealth, .ready),
    (vscodeEditorState, .disabled(reason: vscodeDisabledReason)),
    (vscodeWorkspaceStatus, .disabled(reason: vscodeDisabledReason)),
    (vscodeDiagnostics, .disabled(reason: vscodeDisabledReason)),
    (vscodeRunTask, .disabled(reason: vscodeDisabledReason)),
    (vscodeCancelTask, .disabled(reason: vscodeDisabledReason)),
    (vscodeRunTests, .disabled(reason: vscodeDisabledReason)),
    (vscodeCancelTests, .disabled(reason: vscodeDisabledReason)),
    (vscodeTerminalSessions, .disabled(reason: vscodeDisabledReason)),
    (vscodeBridgeHealth, .disabled(reason: vscodeDisabledReason)),
    (
      computerUseRun,
      .disabled(
        reason:
          "Computer-use run is implemented (DeterministicComputerUsePlanner) but not yet wired "
          + "into the composition root; it requires an approved, live-validated beta app."
      )
    ),
    // SP-004. Backed by `AuraAutomation.FileSystemURLOpener` and reachable
    // through direct `AuraKernel` methods that apply the same `PolicyEngine`
    // gate as every routed capability — the identical non-NLU reachability
    // path `app.discover`/`app.hide`/`task.status`/`task.cancel` already use.
    // `.ready` therefore describes real, tested, reachable adapters. It does
    // *not* claim bilingual NLU or UI reachability, which is SP-005's
    // objective; `OPEN-04` stays open until that lands.
    (filesystemOpenFile, .ready),
    (filesystemOpenFolder, .ready),
    (filesystemReveal, .ready),
    (urlOpen, .ready),
    (
      browserRead,
      .disabled(
        reason:
          "Structured Safari Web Extension read bridge exists as a typed adapter but is not "
          + "packaged or wired into the composition root yet."
      )
    ),
    (
      mailRead,
      .disabled(
        reason:
          "Gmail read adapter contracts and least-privilege scope checks exist, but no user "
          + "account/token is configured and the provider transport is not wired yet."
      )
    ),
    (
      calendarRead,
      .disabled(
        reason:
          "EventKit read adapter exists, but calendar authorization and composition-root wiring "
          + "are user-controlled and not configured in this pass."
      )
    ),
    (
      contactsLookup,
      .disabled(
        reason:
          "Contacts candidate lookup adapter exists, but Contacts authorization and composition-"
          + "root wiring are user-controlled and not configured in this pass."
      )
    ),
  ]

  public static let converse = CapabilityManifest(
    id: "aura.converse", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Conversation", .turkish: "Sohbet"],
      descriptionByLocale: [
        .english: "Answer a question or hold a conversation with no side effects.",
        .turkish: "Bir soruyu yanıtlar veya yan etkisi olmayan bir sohbet yürütür.",
      ]),
    inputSchemaDescription: "utterance text; no side effects",
    outputSchemaDescription: "spoken/typed response text",
    owningAdapter: "DialogueEngine",
    requiredCapability: .intentConverse,
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 1, supportsCancellation: false, isRetryable: true),
    confirmationRule: "never required (observation tier)",
    verificationMethod: "none",
    rollbackStrategy: "not applicable — no side effects")

  public static let appActivate = CapabilityManifest(
    id: "app.activate", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Activate App", .turkish: "Uygulamayı Etkinleştir"],
      descriptionByLocale: [
        .english: "Bring an installed application to the foreground.",
        .turkish: "Kurulu bir uygulamayı ön plana getirir.",
      ]),
    inputSchemaDescription: "bundleIdentifier: String",
    outputSchemaDescription: "activated bundleIdentifier",
    owningAdapter: "AuraAutomation.activateApplication",
    requiredCapability: .appActivate,
    sideEffects: ["brings the target application to the foreground"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: false, isRetryable: true),
    confirmationRule: "reversible tier default (no mandatory confirmation)",
    verificationMethod: "AuraAutomation reports the activated bundle identifier",
    rollbackStrategy: "none required — reversible by re-activating the prior frontmost app")

  public static let appTerminate = CapabilityManifest(
    id: "app.quit", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Quit App", .turkish: "Uygulamayı Kapat"],
      descriptionByLocale: [
        .english: "Quit a running application; may discard unsaved state.",
        .turkish: "Çalışan bir uygulamayı kapatır; kaydedilmemiş durum kaybolabilir.",
      ]),
    inputSchemaDescription: "bundleIdentifier: String",
    outputSchemaDescription: "terminated bundleIdentifier",
    owningAdapter: "AuraAutomation.quitApplication",
    requiredCapability: .appTerminate,
    sideEffects: ["quits the target application; may discard unsaved state"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: false, isRetryable: true),
    confirmationRule: "mutation tier default (confirmation required unless granted)",
    verificationMethod: "AuraAutomation reports the terminated bundle identifier",
    rollbackStrategy: "none — relaunch is a distinct app.activate call, not an automatic rollback")

  public static let shellExecuteTyped = CapabilityManifest(
    id: "shell.execute_typed", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Run Shell Command", .turkish: "Kabuk Komutu Çalıştır"],
      descriptionByLocale: [
        .english: "Run a typed, allowlist-bounded shell command.",
        .turkish: "İzin listesiyle sınırlı, tipli bir kabuk komutu çalıştırır.",
      ]),
    inputSchemaDescription: "executable: String, arguments: [String]",
    outputSchemaDescription: "process exit code and captured stdout/stderr",
    owningAdapter: "AuraShell.execute",
    requiredCapability: .shellExec,
    sideEffects: ["arbitrary process side effects, bounded by AuraShell's own allowlist"],
    isIdempotent: false,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 30, supportsCancellation: true, isRetryable: false),
    confirmationRule: "mutation tier default; escalates to destructive/mandatory confirmation "
      + "on a destructive-pattern match",
    verificationMethod: "process exit code and captured stdout/stderr",
    rollbackStrategy: "none — arbitrary process effects are not automatically reversible")

  public static let codingAgentRun = CapabilityManifest(
    id: "agent.coding_run", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Run Coding Agent", .turkish: "Kodlama Ajanını Çalıştır"],
      descriptionByLocale: [
        .english: "Delegate a coding objective to a CLI coding-agent backend.",
        .turkish: "Bir kodlama hedefini bir CLI kodlama ajanı arka ucuna devreder.",
      ]),
    inputSchemaDescription: "backend: String, objective: String",
    outputSchemaDescription: "durable task ID for status polling",
    owningAdapter: "AgentBackendTaskRunner",
    requiredCapability: .agentRun,
    sideEffects: ["delegates to a coding-agent CLI run; may write files"],
    isIdempotent: false,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 1800, supportsCancellation: true, isRetryable: false),
    confirmationRule: "destructive tier default; backend adapter also evaluates its own policy",
    verificationMethod: "AuraTaskEngine status polling",
    rollbackStrategy: "backend-CLI-dependent; not guaranteed",
    enforcesPolicyInternally: true)

  public static let appDiscover = CapabilityManifest(
    id: "app.discover", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Discover Running Apps", .turkish: "Çalışan Uygulamaları Bul"],
      descriptionByLocale: [
        .english: "List currently running applications.",
        .turkish: "Şu anda çalışan uygulamaları listeler.",
      ]),
    inputSchemaDescription: "no arguments",
    outputSchemaDescription: "one ApplicationDiscoveredEvent per running application",
    owningAdapter: "AuraAutomation.discoverApplications",
    requiredCapability: .appDiscover,
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: false, isRetryable: true),
    confirmationRule: "never required (observation tier)",
    verificationMethod: "emitted ApplicationDiscoveredEvent count",
    rollbackStrategy: "not applicable — no side effects")

  public static let appHide = CapabilityManifest(
    id: "app.hide", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Hide App", .turkish: "Uygulamayı Gizle"],
      descriptionByLocale: [
        .english: "Hide a running application without quitting it.",
        .turkish: "Çalışan bir uygulamayı kapatmadan gizler.",
      ]),
    inputSchemaDescription: "bundleIdentifier: String",
    outputSchemaDescription: "hidden bundleIdentifier",
    owningAdapter: "AuraAutomation.hideApplication",
    requiredCapability: .appHide,
    sideEffects: ["hides the target application's windows"],
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 10, supportsCancellation: false, isRetryable: true),
    confirmationRule: "reversible tier default (no mandatory confirmation)",
    verificationMethod: "AuraAutomation reports the hidden bundle identifier",
    rollbackStrategy: "reversible via a subsequent app.activate call")

  public static let taskStatus = CapabilityManifest(
    id: "task.status", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Task Status", .turkish: "Görev Durumu"],
      descriptionByLocale: [
        .english: "Check the status of a previously started durable task.",
        .turkish: "Daha önce başlatılmış kalıcı bir görevin durumunu kontrol eder.",
      ]),
    inputSchemaDescription: "taskID: UUID",
    outputSchemaDescription: "TaskStatus snapshot, or absent if unknown",
    owningAdapter: "AuraTaskEngine.status",
    requiredCapability: .taskStatus,
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 5, supportsCancellation: false, isRetryable: true),
    confirmationRule: "never required (observation tier)",
    verificationMethod: "returned TaskStatus is non-nil for a known task ID",
    rollbackStrategy: "not applicable — no side effects")

  public static let taskCancel = CapabilityManifest(
    id: "task.cancel", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Cancel Task", .turkish: "Görevi İptal Et"],
      descriptionByLocale: [
        .english: "Cancel a queued or running durable task.",
        .turkish: "Sırada bekleyen veya çalışan kalıcı bir görevi iptal eder.",
      ]),
    inputSchemaDescription: "taskID: UUID",
    outputSchemaDescription: "cancellation acknowledgement",
    owningAdapter: "AuraTaskEngine.cancel",
    requiredCapability: .taskCancel,
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 5, supportsCancellation: false, isRetryable: false),
    confirmationRule: "reversible tier default (no mandatory confirmation)",
    verificationMethod: "AuraTaskEngine reports the task's post-cancel state",
    rollbackStrategy: "none — a cancelled task is not automatically resumed")

  public static let capabilityHealth = CapabilityManifest(
    id: "capability.health", version: "1.0.0",
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Capability Health", .turkish: "Yetenek Sağlığı"],
      descriptionByLocale: [
        .english: "Inspect the registered capability set and its availability.",
        .turkish: "Kayıtlı yetenek kümesini ve kullanılabilirliğini inceler.",
      ]),
    inputSchemaDescription: "no arguments",
    outputSchemaDescription: "one entry per registered capability with its availability",
    owningAdapter: "CapabilityRegistry.allManifests",
    requiredCapability: .capabilityHealthQuery,
    isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 1, supportsCancellation: false, isRetryable: true),
    confirmationRule: "never required (observation tier)",
    verificationMethod: "returned entry count matches the registry's own count",
    rollbackStrategy: "not applicable — no side effects")

  private static let vscodeDisabledReason =
    "Typed VS Code contracts exist, but the authenticated extension package, secret onboarding, "
    + "and live composition route are not provisioned in this pass."

  public static let vscodeEditorState = vscodeObservationManifest(
    id: "vscode.editor_state",
    title: "VS Code Editor State",
    action: "editor state",
    requiredCapability: .vscodeObserveState,
    output: "active file, selection, dirty/open editor state, and workspace folders")

  public static let vscodeWorkspaceStatus = vscodeObservationManifest(
    id: "vscode.workspace_status",
    title: "VS Code Workspace Status",
    action: "workspace status",
    requiredCapability: .vscodeWorkspaceStatus,
    output: "active workspace folders and repository-root candidates")

  public static let vscodeDiagnostics = vscodeObservationManifest(
    id: "vscode.diagnostics",
    title: "VS Code Diagnostics",
    action: "diagnostics",
    requiredCapability: .vscodeDiagnostics,
    output: "bounded diagnostics with file and severity metadata")

  public static let vscodeRunTask = vscodeCommandManifest(
    id: "vscode.run_task",
    title: "Run VS Code Task",
    action: "run task",
    requiredCapability: .vscodeRunTask,
    input: "named task and resolved workspace")

  public static let vscodeCancelTask = vscodeCommandManifest(
    id: "vscode.cancel_task",
    title: "Cancel VS Code Task",
    action: "cancel task",
    requiredCapability: .vscodeCancelTask,
    input: "task ID")

  public static let vscodeRunTests = vscodeCommandManifest(
    id: "vscode.run_tests",
    title: "Run VS Code Tests",
    action: "run tests",
    requiredCapability: .vscodeRunTests,
    input: "test target and resolved workspace")

  public static let vscodeCancelTests = vscodeCommandManifest(
    id: "vscode.cancel_tests",
    title: "Cancel VS Code Tests",
    action: "cancel tests",
    requiredCapability: .vscodeCancelTests,
    input: "test ID")

  public static let vscodeTerminalSessions = vscodeObservationManifest(
    id: "vscode.terminal_sessions",
    title: "VS Code Terminal Sessions",
    action: "terminal sessions",
    requiredCapability: .vscodeObserveState,
    output: "terminal session IDs and verified working directories")

  public static let vscodeBridgeHealth = vscodeObservationManifest(
    id: "vscode.bridge_health",
    title: "VS Code Bridge Health",
    action: "bridge health",
    requiredCapability: .vscodeBridgeHealth,
    output: "protocol, extension identity, freshness, and connection state")
}
