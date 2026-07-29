import AppKit
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
      guard permissions.speechReady else {
        status = .restricted
        statusDetail = "Grant microphone and Speech Recognition access first"
        return
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
      permissions = PermissionCoordinator.snapshot()
      if permissions.speechReady {
        try await kernel.startSpeechRecognition()
        status = .idle
        statusDetail = "Ready — use Push to Talk"
      } else {
        status = .restricted
        statusDetail = "Complete voice permission onboarding"
      }
    } catch {
      setError("AURA failed to start: \(error.localizedDescription)")
    }
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
