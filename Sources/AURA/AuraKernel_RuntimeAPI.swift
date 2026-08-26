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

extension AuraKernel {
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
    // Detached on purpose. Every external probe inside it can block on
    // securityd, and `start()` is what the app's first render waits on — the
    // window must not be hostage to a Keychain round trip. The health surface
    // shows these components as still loading until the probe resolves them.
    Task.detached { [weak self] in
      await self?.probeExternalAvailability()
    }
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
    // Re-derive the productivity and VS Code capabilities before the turn is
    // routed.
    //
    // Their readiness is time-bounded: the Safari bridge is usable only while
    // the user's last page observation is fresh. A registry refreshed on
    // onboarding actions alone was therefore stale by the time any real
    // request arrived — the user clicked the extension button, asked AURA to
    // read the page, and the router refused with "no tool registered" against
    // a bridge that was working.
    //
    // VS Code readiness also depends on live extension health, so it is
    // refreshed here as part of the same pre-turn gate.
    await refreshProductivityAvailability()
    await refreshVSCodeAvailability()
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

  /// SP-012: provision the authenticated VS Code extension bridge's shared
  /// secret.
  ///
  /// The secret is the user-controlled symmetric key both halves must mirror:
  /// this stores it in the AURA Keychain, and the user enters the same value
  /// in the companion extension's `AURA Bridge: Enter Shared Secret` command,
  /// which stores it in VS Code's encrypted `SecretStorage`. The value is
  /// never logged or echoed here. Requires the runtime to be started so the
  /// kernel's retained secret store exists.
  ///
  /// - Parameters:
  ///   - sharedSecret: the symmetric HMAC secret (UTF-8), at least 16
  ///     characters.
  ///   - extensionID: the companion extension identifier; must match the
  ///     configured extension ID so the bridge binds the expected identity.
  func provisionVSCodeBridge(
    sharedSecret: String,
    extensionID: String
  ) async throws(AuraError) {
    guard started, let secretStore = vscodeBridgeSecretStore else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    guard extensionID == configuration.vscode.extensionID else {
      throw AuraError.permissionDenied(
        "VS Code bridge extension ID does not match the configured extension")
    }
    guard sharedSecret.utf8.count >= 16 else {
      throw AuraError.securityError("VS Code bridge shared secret must be at least 16 characters")
    }
    try await secretStore.provision(
      sharedSecret: Data(sharedSecret.utf8), forExtensionID: extensionID)
    await refreshVSCodeAvailability()
  }

  /// SP-012: revoke the authenticated VS Code extension bridge's shared secret.
  ///
  /// Deletes the Keychain item first and refreshes availability afterwards, so
  /// a failed deletion leaves the capability reported as connected rather than
  /// claiming a revocation that did not happen. After revocation every VS Code
  /// capability returns to `.disabled` until the user re-provisions.
  func revokeVSCodeBridge(extensionID: String) async throws(AuraError) {
    guard started, let secretStore = vscodeBridgeSecretStore else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    guard extensionID == configuration.vscode.extensionID else {
      throw AuraError.permissionDenied(
        "VS Code bridge extension ID does not match the configured extension")
    }
    try await secretStore.revoke(extensionID: extensionID)
    await refreshVSCodeAvailability()
  }

  /// SP-012: whether a shared secret has been provisioned for the configured
  /// VS Code extension ID. Used by a UI to enable a revoke control and to
  /// report provisioning state without handling the secret value. An empty or
  /// unconfigured extension ID is reported as not provisioned rather than as an
  /// error, matching how the bridge itself stays `.unauthorized`.
  func vscodeBridgeProvisioned() async throws(AuraError) -> Bool {
    guard let secretStore = vscodeBridgeSecretStore else {
      return false
    }
    let extensionID = configuration.vscode.extensionID
    guard !extensionID.isEmpty else {
      return false
    }
    return try await secretStore.retrieveSecret(forExtensionID: extensionID) != nil
  }

  /// SP-012: perform a read-only, policy-authorized editor-state round trip
  /// through the authenticated VS Code extension bridge. The returned model
  /// stays in-process; callers must not surface its private editor details in
  /// status text or evidence.
  func readVSCodeEditorState() async -> Result<VSCodeBridgeCommandResult, AuraError> {
    guard started, let vscodeAdapter else {
      return .failure(.invalidConfiguration("AURA runtime is not started"))
    }
    return await vscodeAdapter.executeBridge(
      .editor, actor: .user, correlationID: UUID().uuidString)
  }

  func triggerEmergencyStop() async {
    await emergencyStop?.trigger(source: .userInterface, reason: "User activated emergency stop")
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
  func evaluateDirectCapability(
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

  func taskPause(id: UUID) async throws(AuraError) {
    guard started, let taskEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.taskPause)
    try await taskEngine.pause(id: id)
  }

  /// Resume a paused task. The runner is the same `AgentBackendTaskRunner`
  /// the engine started with, so a resumed task re-runs through the same
  /// backend multiplexing that enqueued it.
  func taskResume(id: UUID) async throws(AuraError) {
    guard started, let taskEngine, let agentTaskRunner else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.taskResume)
    try await taskEngine.resume(id: id, runner: agentTaskRunner)
  }

  /// Manually re-run a failed task once. The runner is again the shared
  /// `AgentBackendTaskRunner`, and `AuraTaskEngine.retry` resets only the
  /// failed task to pending without re-arming its retry budget.
  func taskRetry(id: UUID) async throws(AuraError) {
    guard started, let taskEngine, let agentTaskRunner else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.taskRetry)
    try await taskEngine.retry(id: id, runner: agentTaskRunner)
  }

  /// SP-004's `filesystem.open_file`, `filesystem.open_folder`,
  /// `filesystem.reveal`, and `url.open`. Each evaluates policy through the
  /// same `PolicyEngine` as every routed capability, then delegates to
  /// `FileSystemURLOpener`, which refuses unsafe targets *before* any side
  /// effect and verifies the OS's real success signal afterwards.
  ///
  /// Deliberately reachable only by direct call. No bilingual NLU classifier
  /// or UI surface routes to these yet — that is SP-005's objective, and
  /// `OPEN-04` stays open until it lands.
  ///
  /// `PolicyTarget` carries the caller's raw path/host so a policy rule can
  /// scope on it. The adapter independently canonicalizes and re-validates,
  /// so a policy decision made on the raw string is never the only thing
  /// between an attacker-supplied target and LaunchServices.
  /// Build a bounded multi-step plan through `CapabilityPlanner` and execute
  /// it via `ToolRouter.routePlan` — the same policy → confirmation → adapter
  /// path every routed intent takes.
  ///
  /// The planner is the gate, not this method: an unknown capability, an
  /// unavailable one, a missing required argument, an over-budget plan, or a
  /// forward/self dependency is rejected before any step runs, and nothing
  /// here can widen that. Execution is *not* transactional — steps that
  /// already ran keep their effects, and the returned report carries each
  /// step's declared `rollbackStrategy` verbatim instead of pretending an undo
  /// happened.
  func executePlan(
    steps: [PlanStepRequest]
  ) async throws(AuraError) -> PlanExecutionReport {
    guard started, let intentDispatchCoordinator else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    let context = TurnContext(
      sessionID: sessionID, correlationID: UUID(), causationID: UUID(),
      activationSource: .text, actor: .user, authority: .userUtterance,
      sensitivity: .sensitive)
    return try await intentDispatchCoordinator.executePlan(steps: steps, context: context)
  }

  func openFile(path: String) async throws(AuraError) -> OpenOutcome {
    guard started, let fileSystemURLOpener else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.fileOpen, target: PolicyTarget(filePath: path))
    return try await fileSystemURLOpener.openFile(path: path)
  }

  func openFolder(path: String) async throws(AuraError) -> OpenOutcome {
    guard started, let fileSystemURLOpener else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.fileOpen, target: PolicyTarget(directoryPath: path))
    return try await fileSystemURLOpener.openFolder(path: path)
  }

  func revealInFinder(path: String) async throws(AuraError) -> OpenOutcome {
    guard started, let fileSystemURLOpener else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.fileReveal, target: PolicyTarget(filePath: path))
    return try await fileSystemURLOpener.reveal(path: path)
  }

  func openURL(_ raw: String) async throws(AuraError) -> OpenOutcome {
    guard started, let fileSystemURLOpener else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    // Host is extracted only so a policy rule can scope on it. A malformed or
    // scheme-less string yields `nil` here and is refused by the adapter's
    // own validation a moment later; parsing here never grants anything.
    let host = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))?.host
    try await evaluateDirectCapability(.urlOpen, target: PolicyTarget(networkHost: host))
    return try await fileSystemURLOpener.openURL(raw)
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
  func memoryRecordsSnapshot(
    includeSuperseded: Bool = false
  ) async throws(AuraError) -> [MemoryRecord] {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await memoryEngine.inspect(includeSuperseded: includeSuperseded)
  }

  func memoryConflictsSnapshot() async throws(AuraError) -> [MemoryConflict] {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await memoryEngine.conflicts()
  }

  func resolveMemoryConflict(
    id: UUID, resolution: MemoryConflictResolution
  ) async throws(AuraError) {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await memoryEngine.resolveConflict(id: id, resolution: resolution, actor: .user)
  }

  @discardableResult
  func enforceMemoryRetention() async throws(AuraError) -> [UUID] {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await memoryEngine.enforceRetention()
  }

  func preferenceProfileSnapshot() async throws(AuraError) -> UserPreferenceProfile? {
    guard started, let preferenceProfileStore else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await preferenceProfileStore.load()
  }

  @discardableResult
  func savePreferenceProfile(
    _ profile: UserPreferenceProfile
  ) async throws(AuraError) -> UserPreferenceProfile {
    guard started, let preferenceProfileStore else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await preferenceProfileStore.save(profile, actor: .user, sessionID: sessionID)
  }

  @discardableResult
  func clearPreferenceProfile() async throws(AuraError) -> MemoryDeletionReceipt? {
    guard started, let preferenceProfileStore else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await preferenceProfileStore.clear(actor: .user)
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
      recordID: id, newStatement: statement, reason: reason,
      evidenceReferences: ["user-correction:\(id.uuidString)"], actor: .user,
      sessionID: sessionID)
  }

  /// Permanently delete one non-audit memory record and return the engine's
  /// receipt. The receipt is the user's only proof the deletion happened —
  /// the audit event deliberately does not carry the deleted content — so it
  /// is returned rather than discarded.
  @discardableResult
  func deleteMemoryRecord(
    id: UUID, reason: String
  ) async throws(AuraError) -> MemoryDeletionReceipt {
    guard started, let memoryEngine else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return try await memoryEngine.deleteRecord(id: id, reason: reason, actor: .user)
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
}
