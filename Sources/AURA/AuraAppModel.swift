import AppKit
import AuraConfig
import AuraCore
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

  private let confirmationPresenter = UIConfirmationPresenter()
  private let emergencyShortcutMonitor = EmergencyShortcutMonitor()
  private var confirmationContinuation: CheckedContinuation<Bool, Never>?
  private var kernel: AuraKernel?
  private var eventBus: AuraEventBus?
  private var bootTask: Task<Void, Never>?

  init() {
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
          try await kernel?.startSpeechRecognition()
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
          try await kernel?.startSpeechRecognition()
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
  }

  private func updateTask(_ event: TaskStateChangedEvent) {
    guard let index = tasks.firstIndex(where: { $0.id == event.taskID }) else { return }
    tasks[index].state = event.newState.rawValue
  }

  private func setEmergencyStopActive() {
    emergencyStopActive = true
    status = .stopped
    statusDetail = "Emergency stop active"
  }

  private func setError(_ message: String) {
    status = .error
    statusDetail = message
  }
}
