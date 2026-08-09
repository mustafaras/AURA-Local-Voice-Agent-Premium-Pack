import AppKit
import AuraAgent
import AuraConfig
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation

enum AuraAppStatus: String, Sendable {
  case starting
  case restricted
  case idle
  case listening
  case thinking
  case speaking
  case stopped
  case error

  var title: String {
    rawValue.capitalized
  }

  var symbolName: String {
    switch self {
    case .starting: "hourglass"
    case .restricted: "lock.trianglebadge.exclamationmark"
    case .idle: "waveform"
    case .listening: "mic.fill"
    case .thinking: "brain"
    case .speaking: "speaker.wave.2.fill"
    case .stopped: "hand.raised.fill"
    case .error: "exclamationmark.triangle.fill"
    }
  }
}

struct AuraTaskSummary: Identifiable, Sendable {
  let id: UUID
  var title: String
  var state: String
}

@MainActor
final class AuraAppModel: ObservableObject {
  @Published private(set) var status: AuraAppStatus = .starting
  @Published private(set) var statusDetail = "Starting local services"
  @Published private(set) var permissions = PermissionCoordinator.snapshot()
  @Published private(set) var pendingConfirmation: PolicyConfirmationChallenge?
  @Published private(set) var tasks: [AuraTaskSummary] = []
  @Published private(set) var emergencyStopActive = false
  @Published private(set) var runtimeWarnings: [String] = [
    "Acoustic wake-word model unavailable; use Push to Talk."
  ]
  @Published private(set) var runtimeHealth: [RuntimeHealth] = []
  @Published var textInput = ""
  @Published private(set) var effectiveConfiguration: [EffectiveConfigurationEntry] = []
  @Published private(set) var configurationAuditCount = 0
  @Published private(set) var localRecommendationsEnabled = false
  @Published private(set) var taskStatuses: [TaskStatus] = []
  @Published private(set) var capabilityRows: [AuraCapabilityRow] = []
  @Published private(set) var backendHealth: [AgentBackendHealth] = []
  @Published private(set) var memoryRows: [AuraMemoryRow] = []
  @Published private(set) var conversationMessages: [AuraConversationMessage] = []
  @Published private(set) var partialTranscript = ""
  @Published private(set) var lastPlanSummary: String?
  @Published private(set) var lastOperationMessage = ""
  @Published var productUIState = AuraProductUIState()
  @Published var memoryCorrectionTarget: AuraMemoryRow? = nil

  private let confirmationPresenter = UIConfirmationPresenter()
  private let emergencyShortcutMonitor = EmergencyShortcutMonitor()
  private var confirmationContinuation: CheckedContinuation<Bool, Never>?
  private var kernel: AuraKernel?
  private var eventBus: AuraEventBus?
  private var bootTask: Task<Void, Never>?

  init() {
    if let rawLanguage = UserDefaults.standard.string(forKey: "aura.ui.language"),
      let savedLanguage = AuraUILanguage(rawValue: rawLanguage)
    {
      productUIState.language = savedLanguage
    }
    if let data = UserDefaults.standard.data(forKey: "aura.ui.state"),
      let savedState = try? JSONDecoder().decode(AuraProductUIState.self, from: data)
    {
      productUIState.selectedTab = savedState.selectedTab
      productUIState.onboarding = savedState.onboarding
    }
    bootTask = Task { [weak self] in
      guard let self else { return }
      self.emergencyShortcutMonitor.start { [weak self] in
        self?.triggerEmergencyStop()
      }
      await self.configureConfirmationPresenter()
      await self.bootstrap()
    }
  }

  func requestVoicePermissions() {
    Task {
      statusDetail = "Waiting for voice permissions"
      permissions = await PermissionCoordinator.requestVoicePermissions()
      if permissions.speechReady {
        do {
          guard let kernel else {
            setError("AURA runtime is not started; voice permission setup cannot continue")
            return
          }
          try await kernel.startSpeechRecognition()
          status = .idle
          statusDetail = "Ready — use Push to Talk"
        } catch {
          setError("Speech recognition could not start: \(error.localizedDescription)")
        }
      } else {
        status = .restricted
        statusDetail = "Voice permissions are required for speech input"
      }
    }
  }

  func refreshPermissions() {
    permissions = PermissionCoordinator.snapshot()
  }

  func requestAccessibilityPermission() {
    permissions = PermissionCoordinator.requestAccessibilityPermission()
  }

  func requestScreenRecordingPermission() {
    permissions = PermissionCoordinator.requestScreenRecordingPermission()
  }

  func pushToTalk() {
    Task {
      if !permissions.speechReady {
        // Proactively trigger the real OS permission prompt here instead of
        // only setting a passive status label — a user pressing Push to Talk
        // expects that action itself to request access, the same way it
        // would on iOS/Android, rather than needing to discover a separate
        // menu control first.
        statusDetail = "Waiting for voice permissions"
        permissions = await PermissionCoordinator.requestVoicePermissions()
        guard permissions.speechReady else {
          status = .restricted
          statusDetail = "Grant microphone and Speech Recognition access first"
          return
        }
        do {
          guard let kernel else {
            setError("AURA runtime is not started; Push to Talk cannot start")
            return
          }
          try await kernel.startSpeechRecognition()
        } catch {
          setError("Speech recognition could not start: \(error.localizedDescription)")
          return
        }
      }
      do {
        try await kernel?.activatePushToTalk()
        status = .listening
        statusDetail = "Listening on device"
      } catch {
        setError(error.localizedDescription)
      }
    }
  }

  func submitText() {
    let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    textInput = ""
    appendConversation(.init(role: .user, text: text))
    Task {
      do {
        try await kernel?.submitText(text)
        status = .thinking
        statusDetail = "Processing typed request"
      } catch {
        setError(error.localizedDescription)
      }
    }
  }

  func triggerEmergencyStop() {
    Task {
      await kernel?.triggerEmergencyStop()
      emergencyStopActive = true
      status = .stopped
      statusDetail = "Generated input is disabled until explicitly re-armed"
    }
  }

  func resetEmergencyStop() {
    Task {
      await kernel?.resetEmergencyStop()
      emergencyStopActive = false
      status = permissions.speechReady ? .idle : .restricted
      statusDetail =
        permissions.speechReady ? "Ready — use Push to Talk" : "Voice permissions required"
    }
  }

  func resolveConfirmation(accepted: Bool) {
    confirmationContinuation?.resume(returning: accepted)
    confirmationContinuation = nil
    pendingConfirmation = nil
    productUIState.reduce(.hideConfirmation)
  }

  func selectTab(_ tab: AuraProductTab) {
    productUIState.reduce(.selectTab(tab))
    persistProductUIState()
  }

  func setUILanguage(_ language: AuraUILanguage) {
    productUIState.reduce(.setLanguage(language))
    UserDefaults.standard.set(language.rawValue, forKey: "aura.ui.language")
    persistProductUIState()
    refreshProductSnapshots()
  }

  func beginOnboarding() {
    productUIState.reduce(.beginOnboarding)
    persistProductUIState()
  }

  func closeOnboarding() {
    productUIState.reduce(.closeOnboarding)
    persistProductUIState()
  }

  func advanceOnboarding() {
    productUIState.reduce(.advanceOnboarding)
    persistProductUIState()
  }

  func skipOptionalOnboardingStep() {
    productUIState.reduce(.skipOptionalOnboardingStep)
    persistProductUIState()
  }

  func onboardingPrimaryAction() {
    switch productUIState.onboarding.stage {
    case .privacy, .health, .voiceTest, .ttsTest, .localModel, .integrations,
      .safeCommand, .launchAtLogin:
      advanceOnboarding()
    case .voicePermissions:
      Task {
        permissions = await PermissionCoordinator.requestVoicePermissions()
        guard permissions.speechReady else {
          status = .restricted
          statusDetail = "Voice permissions are required before continuing"
          return
        }
        do {
          guard let kernel else {
            setError("AURA runtime is not started; voice onboarding cannot continue")
            return
          }
          try await kernel.startSpeechRecognition()
          status = .idle
          statusDetail = "Ready — use Push to Talk"
          advanceOnboarding()
        } catch {
          setError("Speech recognition could not start: \(error.localizedDescription)")
        }
      }
    case .wakeWord:
      lastOperationMessage = "Wake word is optional and no acoustic model is installed."
      skipOptionalOnboardingStep()
    case .privilegedAccess:
      requestAccessibilityPermission()
      requestScreenRecordingPermission()
      refreshPermissions()
      if permissions.accessibility == .granted && permissions.screenRecording == .granted {
        advanceOnboarding()
      } else {
        lastOperationMessage =
          "Accessibility and Screen Recording remain optional; grant them in macOS Settings, then continue."
      }
    case .emergencyStop:
      if emergencyStopActive {
        resetEmergencyStop()
        advanceOnboarding()
      } else {
        triggerEmergencyStop()
        lastOperationMessage = "Emergency stop is active. Press Continue to re-arm and proceed."
      }
    case .complete:
      closeOnboarding()
    }
  }

  func refreshProductSnapshots() {
    Task { [weak self] in
      guard let self else { return }
      await refreshRuntimeHealth()
      guard let kernel else { return }
      do {
        taskStatuses = try await kernel.taskStatuses()
        let capabilitySnapshot = try await kernel.capabilityHealthSnapshot()
        capabilityRows = capabilitySnapshot.map { manifest, availability in
          let language: DialogueLanguage = productUIState.language == .turkish ? .turkish : .english
          let state: String
          let detail: String
          let isEnabled: Bool
          switch availability {
          case .ready:
            state = AuraCopy.text("capabilities.ready", language: productUIState.language)
            detail = "Ready"
            isEnabled = true
          case .degraded(let reason):
            state = AuraCopy.text("capabilities.degraded", language: productUIState.language)
            detail = reason
            isEnabled = false
          case .disabled(let reason):
            state = AuraCopy.text("capabilities.disabled", language: productUIState.language)
            detail = reason
            isEnabled = false
          case .none:
            state = AuraCopy.text("capabilities.disabled", language: productUIState.language)
            detail = "No availability evidence is registered"
            isEnabled = false
          }
          return AuraCapabilityRow(
            id: manifest.qualifiedID,
            title: manifest.presentation.title(for: language),
            description: manifest.presentation.descriptionByLocale[language] ?? "",
            locality: manifest.locality.rawValue,
            state: state,
            detail: detail,
            riskAndConfirmation: manifest.confirmationRule,
            qualifiedID: manifest.qualifiedID,
            isEnabled: isEnabled)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        backendHealth = await kernel.refreshAgentBackendHealth()
        let records = try await kernel.memoryRecordsSnapshot()
        memoryRows = records.map { record in
          AuraMemoryRow(
            id: record.id,
            memoryClass: record.memoryClass.rawValue,
            subject: record.subject,
            statement: record.statement,
            purpose: record.purpose,
            provenance: String(describing: record.provenance),
            confidence: record.confidence,
            sensitivity: record.sensitivity.rawValue,
            createdAt: record.createdAt,
            canMutate: record.memoryClass != .auditSecurity)
        }
      } catch {
        setError("Product status refresh failed: \(error.localizedDescription)")
      }
    }
  }

  func cancelTask(_ id: UUID) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.taskCancel(id: id)
        lastOperationMessage = "Task cancellation requested."
        refreshProductSnapshots()
      } catch {
        setError("Task cancellation failed: \(error.localizedDescription)")
      }
    }
  }

  func deleteMemory(_ id: UUID) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        try await kernel.deleteMemoryRecord(
          id: id, reason: "user requested from R9 Memory Center")
        lastOperationMessage = "Memory record deleted; the deletion itself remains audited."
        refreshProductSnapshots()
      } catch {
        setError("Memory deletion failed: \(error.localizedDescription)")
      }
    }
  }

  func beginMemoryCorrection(_ record: AuraMemoryRow) {
    memoryCorrectionTarget = record
  }

  func correctMemory(_ id: UUID, statement: String) {
    Task {
      do {
        guard let kernel else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        _ = try await kernel.correctMemoryRecord(
          id: id, newStatement: statement, reason: "user correction from R9 Memory Center")
        lastOperationMessage = "Correction appended and linked to the previous memory record."
        refreshProductSnapshots()
      } catch {
        setError("Memory correction failed: \(error.localizedDescription)")
      }
    }
  }

  func exportMemory() {
    Task {
      do {
        guard let data = try await kernel?.memoryExportData() else {
          throw AuraError.invalidConfiguration("AURA runtime is not started")
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "aura-memory-\(Self.exportDateFormatter.string(from: Date())).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try data.write(to: url, options: .atomic)
        lastOperationMessage = "Non-audit memory export saved."
      } catch {
        setError("Memory export failed: \(error.localizedDescription)")
      }
    }
  }

  func openMicrophoneSettings() {
    PermissionCoordinator.openPrivacySettings(anchor: "Microphone")
  }

  func openSpeechSettings() {
    PermissionCoordinator.openPrivacySettings(anchor: "SpeechRecognition")
  }

  func openAccessibilitySettings() {
    PermissionCoordinator.openPrivacySettings(anchor: "Accessibility")
  }

  func openScreenRecordingSettings() {
    PermissionCoordinator.openPrivacySettings(anchor: "ScreenCapture")
  }

  func refreshConfigurationInspection() {
    Task {
      guard let kernel else { return }
      if let inspection = await kernel.configurationInspection() {
        effectiveConfiguration = inspection.entries
        localRecommendationsEnabled =
          inspection.entries.first(where: {
            $0.key == "privacy.localRecommendationsEnabled"
          })?.value == .boolean(true)
      }
      configurationAuditCount = await kernel.configurationAuditRecords().count
    }
  }

  func setLocalRecommendationsEnabled(_ enabled: Bool) {
    Task {
      do {
        try await kernel?.setLocalRecommendationsEnabled(enabled)
        refreshConfigurationInspection()
      } catch {
        setError("Configuration change failed: \(error.localizedDescription)")
      }
    }
  }

  func quit() {
    resolveConfirmation(accepted: false)
    emergencyShortcutMonitor.stop()
    Task {
      await kernel?.stop()
      NSApplication.shared.terminate(nil)
    }
  }

  private func configureConfirmationPresenter() async {
    await confirmationPresenter.setHandler { [weak self] challenge in
      guard let self else { return false }
      return await self.awaitConfirmation(challenge)
    }
  }

  private func bootstrap() async {
    do {
      let configuration = AuraConfiguration.default
      try configuration.validate()
      let logger = AuraLogger(
        subsystem: configuration.app.bundleIdentifier,
        category: "bootstrap",
        minimumLevel: .info)
      let storeURL = try ApplicationSupportBootstrap.databaseURL()
      let store = try await AuraStore(path: storeURL.path)
      let eventBus = AuraEventBus(logger: logger)
      self.eventBus = eventBus
      await subscribeToStatus(on: eventBus)
      let kernel = AuraKernel(
        configuration: configuration,
        store: store,
        eventBus: eventBus,
        logger: logger,
        confirmationPresenter: confirmationPresenter)
      self.kernel = kernel
      try await kernel.start()
      await refreshRuntimeHealth()
      refreshProductSnapshots()
      refreshConfigurationInspection()
      permissions = PermissionCoordinator.snapshot()
      if permissions.speechReady {
        try await kernel.startSpeechRecognition()
        status = .idle
        statusDetail = "Ready — use Push to Talk"
      } else {
        status = .restricted
        statusDetail = "Complete voice permission onboarding"
      }
      await runTextDemoIfRequested(logger: logger)
    } catch {
      setError("AURA failed to start: \(error.localizedDescription)")
    }
  }

  /// Debug-only, opt-in text-turn driver for sessions with no GUI/Accessibility
  /// control. Inert unless `AURA_TEXT_DEMO_SCRIPT` names a readable file of one
  /// utterance per line; submits each line through the exact same production
  /// `submitText()` path a user's typed menu-bar input uses, waiting for the
  /// conversation to return to `.idle` (bounded) between turns. Never enabled
  /// by default and does not change any production dialogue/policy behavior.
  private func runTextDemoIfRequested(logger: AuraLogger) async {
    guard let scriptPath = ProcessInfo.processInfo.environment["AURA_TEXT_DEMO_SCRIPT"],
      let contents = try? String(contentsOfFile: scriptPath, encoding: .utf8)
    else { return }
    let lines = contents.split(separator: "\n").map(String.init)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    for line in lines {
      await logger.info("TEXT_DEMO turn: \(line)", actor: .system)
      textInput = line
      submitText()
      var leftIdleWaited = 0.0
      while status == .idle, leftIdleWaited < 5 {
        try? await Task.sleep(nanoseconds: 100_000_000)
        leftIdleWaited += 0.1
      }
      var waited = 0.0
      while status != .idle, waited < 45 {
        try? await Task.sleep(nanoseconds: 500_000_000)
        waited += 0.5
      }
      await logger.info("TEXT_DEMO turn complete after \(waited)s, final status \(status.rawValue)", actor: .system)
    }
    await logger.info("TEXT_DEMO script complete", actor: .system)
  }

  private func subscribeToStatus(on eventBus: AuraEventBus) async {
    await eventBus.subscribe(ConversationStateEvent.self) { [weak self] envelope in
      await self?.applyConversationState(envelope.payload)
    }
    await eventBus.subscribe(TaskEnqueuedEvent.self) { [weak self] envelope in
      await self?.recordTask(envelope.payload)
    }
    await eventBus.subscribe(TaskStateChangedEvent.self) { [weak self] envelope in
      await self?.updateTask(envelope.payload)
    }
    await eventBus.subscribe(TaskProgressEvent.self) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.refreshProductSnapshots()
      }
    }
    await eventBus.subscribe(STTPartialEvent.self) { [weak self] envelope in
      await self?.applyPartialTranscript(envelope.payload)
    }
    await eventBus.subscribe(TurnCompletedEvent.self) { [weak self] envelope in
      await self?.applyCompletedTurn(envelope.payload)
    }
    await eventBus.subscribe(ResponsePlanEvent.self) { [weak self] envelope in
      await self?.applyResponsePlan(envelope.payload)
    }
    await eventBus.subscribe(ToolResultEvent.self) { [weak self] envelope in
      await self?.applyToolResult(envelope.payload)
    }
    await eventBus.subscribe(IntentBlockedEvent.self) { [weak self] envelope in
      await self?.applyIntentBlocked(envelope.payload)
    }
    await eventBus.subscribe(EmergencyStopTriggeredEvent.self) { [weak self] _ in
      await self?.setEmergencyStopActive()
    }
    await eventBus.subscribe(RuntimeHealthChangedEvent.self) { [weak self] envelope in
      await self?.applyRuntimeHealth(envelope.payload.health)
    }
  }

  private func refreshRuntimeHealth() async {
    guard let kernel else { return }
    let health = await kernel.runtimeHealthSnapshot()
    applyRuntimeHealth(health)
  }

  private func applyRuntimeHealth(_ health: [RuntimeHealth]) {
    runtimeHealth = health.sorted { $0.componentID < $1.componentID }
    updateRuntimeWarnings()
  }

  private func applyRuntimeHealth(_ health: RuntimeHealth) {
    if let index = runtimeHealth.firstIndex(where: { $0.componentID == health.componentID }) {
      runtimeHealth[index] = health
    } else {
      runtimeHealth.append(health)
      runtimeHealth.sort { $0.componentID < $1.componentID }
    }
    updateRuntimeWarnings()
  }

  private func updateRuntimeWarnings() {
    let degraded = runtimeHealth
      .filter { $0.status != .ready }
      .map { "\($0.componentID): \($0.detail)" }
    runtimeWarnings = ["Acoustic wake-word model unavailable; use Push to Talk."] + degraded
  }

  private func awaitConfirmation(_ challenge: PolicyConfirmationChallenge) async -> Bool {
    if confirmationContinuation != nil {
      resolveConfirmation(accepted: false)
    }
    pendingConfirmation = challenge
    statusDetail =
      "Confirmation required: \(challenge.requestedAction.domain).\(challenge.requestedAction.action)"
    let requestID = challenge.requestID
    let timeout = max(0, challenge.expiresAt.timeIntervalSinceNow)
    return await withCheckedContinuation { continuation in
      confirmationContinuation = continuation
      Task { [weak self] in
        try? await Task.sleep(for: .seconds(timeout))
        guard let self, self.pendingConfirmation?.requestID == requestID else { return }
        self.resolveConfirmation(accepted: false)
      }
    }
  }

  private func applyConversationState(_ event: ConversationStateEvent) {
    switch event.state {
    case .idle: status = .idle
    case .listening: status = .listening
    case .thinking: status = .thinking
    case .speaking: status = .speaking
    case .interrupted: status = .idle
    case .timeout: status = .restricted
    case .error: status = .error
    }
    statusDetail = event.reason.isEmpty ? status.title : event.reason
  }

  private func recordTask(_ event: TaskEnqueuedEvent) {
    tasks.insert(
      AuraTaskSummary(id: event.taskID, title: event.objective, state: "Queued"),
      at: 0)
    tasks = Array(tasks.prefix(5))
    refreshProductSnapshots()
  }

  private func updateTask(_ event: TaskStateChangedEvent) {
    guard let index = tasks.firstIndex(where: { $0.id == event.taskID }) else { return }
    tasks[index].state = event.newState.rawValue
    refreshProductSnapshots()
  }

  private func applyPartialTranscript(_ event: STTPartialEvent) {
    partialTranscript = event.text
  }

  private func applyCompletedTurn(_ event: TurnCompletedEvent) {
    partialTranscript = ""
    guard !event.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    appendConversation(.init(role: .user, text: event.text))
  }

  private func applyResponsePlan(_ event: ResponsePlanEvent) {
    lastPlanSummary = event.summary
    guard !event.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    appendConversation(.init(role: .assistant, text: event.summary))
  }

  private func applyToolResult(_ event: ToolResultEvent) {
    lastOperationMessage = event.summary
    appendConversation(
      .init(role: .system, text: event.summary, isDegraded: !event.succeeded, sourceSummary: event.toolID))
  }

  private func applyIntentBlocked(_ event: IntentBlockedEvent) {
    lastOperationMessage = event.reason
    appendConversation(
      .init(role: .system, text: "Blocked: \(event.reason)", isDegraded: true, sourceSummary: "Policy"))
  }

  private func appendConversation(_ message: AuraConversationMessage) {
    guard !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    if conversationMessages.last?.role == message.role,
      conversationMessages.last?.text == message.text
    {
      return
    }
    conversationMessages.append(message)
    conversationMessages = Array(conversationMessages.suffix(40))
  }

  private func persistProductUIState() {
    guard let data = try? JSONEncoder().encode(productUIState) else { return }
    UserDefaults.standard.set(data, forKey: "aura.ui.state")
  }

  private func setEmergencyStopActive() {
    emergencyStopActive = true
    status = .stopped
    statusDetail = "Emergency stop active"
  }

  private func setError(_ message: String) {
    status = .error
    statusDetail = message
    lastOperationMessage = message
  }

  private static let exportDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd"
    return formatter
  }()
}
