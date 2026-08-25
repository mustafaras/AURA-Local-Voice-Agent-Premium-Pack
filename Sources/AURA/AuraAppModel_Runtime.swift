import AppKit
import AuraAgent
import AuraConfig
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation

enum ConfirmationResolution: String, Sendable {
  case requested
  case accepted
  case denied
  case expired
  case dismissed
  case superseded
  case cancelled
}

extension AuraAppModel {
  func bootstrap() async {
    do {
      let configuration = AuraConfiguration.bootstrap
      try configuration.validate()
      let logger = AuraLogger(
        subsystem: configuration.app.bundleIdentifier,
        category: "bootstrap",
        minimumLevel: .info)
      let storeURL = try ApplicationSupportBootstrap.databaseURL()
      let store = try await AuraStore(path: storeURL.path)
      let eventBus = AuraEventBus(logger: logger, tracePersistence: store)
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
      if let profile = try await kernel.preferenceProfileSnapshot() {
        memoryPreferenceProfile = profile
        hasSavedMemoryPreference = true
        if profile.preferredLanguage.lowercased().hasPrefix("tr") {
          productUIState.language = .turkish
        } else if profile.preferredLanguage.lowercased().hasPrefix("en") {
          productUIState.language = .english
        }
        UserDefaults.standard.set(productUIState.language.rawValue, forKey: "aura.ui.language")
        persistProductUIState()
      }
      refreshVSCodeBridgeProvisioning()
      await refreshRuntimeHealth()
      refreshProductSnapshots()
      refreshConfigurationInspection()
      permissions = PermissionCoordinator.snapshot()
      // For text-only evidence runs (AURA_TEXT_DEMO_SCRIPT), bypass the voice
      // permission gate so the typed-input path can drive the conversation.
      let textDemoPath = ProcessInfo.processInfo.environment["AURA_TEXT_DEMO_SCRIPT"]
      if permissions.speechReady || textDemoPath != nil {
        if permissions.speechReady {
          try await kernel.startSpeechRecognition()
        }
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
  func runTextDemoIfRequested(logger: AuraLogger) async {
    guard let scriptPath = ProcessInfo.processInfo.environment["AURA_TEXT_DEMO_SCRIPT"],
      let contents = try? String(contentsOfFile: scriptPath, encoding: .utf8)
    else { return }
    let lines = contents.split(separator: "\n").map(String.init)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    for line in lines {
      await logger.info("TEXT_DEMO turn started [inputPresent=\(!line.isEmpty)]", actor: .system)
      textInput = line
      submitText()
      var leftIdleWaited = 0.0
      while status == .idle, leftIdleWaited < 5 {
        try? await Task.sleep(nanoseconds: 100_000_000)
        leftIdleWaited += 0.1
      }
      var waited = 0.0
      // SP-006: mutation-tier intents (quit, shell) route through the
      // structured-NLU model first (19.8–36.1 s/turn) before the policy
      // challenge surfaces, so the per-turn budget must exceed the worst
      // observed model latency plus the confirmation window. 45 s was too
      // short — a `quit Calculator` turn was still `thinking` (confirmation
      // pending) when the driver gave up at exactly 45.0 s.
      while status != .idle, waited < 120 {
        try? await Task.sleep(nanoseconds: 500_000_000)
        waited += 0.5
      }
      await logger.info(
        "TEXT_DEMO turn complete after \(waited)s, final status \(status.rawValue)", actor: .system)
    }
    await logger.info("TEXT_DEMO script complete", actor: .system)
  }

  func subscribeToStatus(on eventBus: AuraEventBus) async {
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
      await self?.applyResponsePlan(
        envelope.payload, correlationID: envelope.correlationID, causationID: envelope.causationID)
    }
    await eventBus.subscribe(ToolResultEvent.self) { [weak self] envelope in
      await self?.applyToolResult(
        envelope.payload, eventID: envelope.id, correlationID: envelope.correlationID,
        causationID: envelope.causationID)
    }
    await eventBus.subscribe(IntentBlockedEvent.self) { [weak self] envelope in
      await self?.applyIntentBlocked(
        envelope.payload, eventID: envelope.id, correlationID: envelope.correlationID,
        causationID: envelope.causationID)
    }
    await eventBus.subscribe(EmergencyStopTriggeredEvent.self) { [weak self] _ in
      await self?.setEmergencyStopActive()
    }
    await eventBus.subscribe(RuntimeHealthChangedEvent.self) { [weak self] envelope in
      await self?.applyRuntimeHealth(envelope.payload.health)
    }
  }

  func refreshRuntimeHealth() async {
    guard let kernel else { return }
    let health = await kernel.runtimeHealthSnapshot()
    applyRuntimeHealth(health)
  }

  func applyRuntimeHealth(_ health: [RuntimeHealth]) {
    runtimeHealth = health.sorted { $0.componentID < $1.componentID }
    updateRuntimeWarnings()
  }

  func applyRuntimeHealth(_ health: RuntimeHealth) {
    if let index = runtimeHealth.firstIndex(where: { $0.componentID == health.componentID }) {
      runtimeHealth[index] = health
    } else {
      runtimeHealth.append(health)
      runtimeHealth.sort { $0.componentID < $1.componentID }
    }
    updateRuntimeWarnings()
  }

  func updateRuntimeWarnings() {
    let degraded =
      runtimeHealth
      .filter { $0.status != .ready }
      .map { "\($0.componentID): \($0.detail)" }
    runtimeWarnings = ["Acoustic wake-word model unavailable; use Push to Talk."] + degraded
  }

  func awaitConfirmation(_ challenge: PolicyConfirmationChallenge) async -> Bool {
    if confirmationContinuation != nil {
      resolveConfirmation(accepted: false, outcome: .superseded)
    }
    pendingConfirmation = challenge
    recordConfirmationTrace(challenge, outcome: .requested)
    statusDetail =
      "Confirmation required: \(challenge.requestedAction.domain)."
      + "\(challenge.requestedAction.action)"
    let requestID = challenge.requestID
    let timeout = max(0, challenge.expiresAt.timeIntervalSinceNow)
    return await withCheckedContinuation { continuation in
      confirmationContinuation = continuation
      Task { [weak self] in
        try? await Task.sleep(for: .seconds(timeout))
        guard let self, self.pendingConfirmation?.requestID == requestID else { return }
        self.resolveConfirmation(accepted: false, outcome: .expired)
      }
    }
  }

  func applyConversationState(_ event: ConversationStateEvent) {
    switch event.state {
    case .idle: status = .idle
    case .listening: status = .listening
    case .thinking: status = .thinking
    case .speaking: status = .speaking
    case .interrupted: status = .idle
    case .timeout: status = .restricted
    case .error: status = .error
    }
    statusDetail = event.reason.isEmpty ? status.title(for: .english) : event.reason
  }

  func recordTask(_ event: TaskEnqueuedEvent) {
    tasks.insert(
      AuraTaskSummary(id: event.taskID, title: event.objective, state: "Queued"),
      at: 0)
    tasks = Array(tasks.prefix(5))
    refreshProductSnapshots()
  }

  func updateTask(_ event: TaskStateChangedEvent) {
    guard let index = tasks.firstIndex(where: { $0.id == event.taskID }) else { return }
    tasks[index].state = event.newState.rawValue
    refreshProductSnapshots()
  }

  func applyPartialTranscript(_ event: STTPartialEvent) {
    partialTranscript = event.text
  }

  func applyCompletedTurn(_ event: TurnCompletedEvent) {
    partialTranscript = ""
    guard !event.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    appendConversation(.init(role: .user, text: event.text))
  }

  func applyResponsePlan(
    _ event: ResponsePlanEvent, correlationID: UUID? = nil, causationID: UUID? = nil
  ) {
    lastPlanSummary = event.summary
    guard !event.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    appendConversation(
      .init(
        role: .assistant,
        text: event.summary,
        traceSummary: traceSummary(correlationID: correlationID, causationID: causationID)))
  }

  func applyToolResult(
    _ event: ToolResultEvent, eventID: UUID? = nil, correlationID: UUID? = nil,
    causationID: UUID? = nil
  ) {
    lastOperationMessage = event.summary
    appendConversation(
      .init(
        role: .system, text: event.summary, isDegraded: !event.succeeded,
        sourceSummary: event.toolID,
        traceSummary: traceSummary(correlationID: correlationID, causationID: causationID)))
    if let eventID, let correlationID, let causationID {
      recordTrace(
        RedactedTraceRecord(
          id: eventID, correlationID: correlationID, causationID: causationID,
          phase: "tool", eventType: ToolResultEvent.eventType, requestID: event.intentID,
          actionIdentifier: event.toolID, outcome: event.succeeded ? "verified" : "failed"))
    }
  }

  func applyIntentBlocked(
    _ event: IntentBlockedEvent, eventID: UUID? = nil, correlationID: UUID? = nil,
    causationID: UUID? = nil
  ) {
    lastOperationMessage = event.reason
    appendConversation(
      .init(
        role: .system, text: "Blocked: \(event.reason)", isDegraded: true,
        sourceSummary: "Policy",
        traceSummary: traceSummary(correlationID: correlationID, causationID: causationID)))
    if let eventID, let correlationID, let causationID {
      recordTrace(
        RedactedTraceRecord(
          id: eventID, correlationID: correlationID, causationID: causationID,
          phase: "policy", eventType: IntentBlockedEvent.eventType, requestID: event.intentID,
          outcome: event.reason))
    }
  }

  func traceSummary(correlationID: UUID?, causationID: UUID?) -> String? {
    guard let correlationID, let causationID else { return nil }
    return AuraTraceDisplay.summary(correlationID: correlationID, causationID: causationID)
  }

  func recordConfirmationTrace(
    _ challenge: PolicyConfirmationChallenge, outcome: ConfirmationResolution
  ) {
    let correlationID = challenge.turnContext?.correlationID ?? challenge.requestID
    let causationID = challenge.turnContext?.causationID ?? challenge.requestID
    recordTrace(
      RedactedTraceRecord(
        correlationID: correlationID,
        causationID: causationID,
        phase: "confirmation",
        eventType: "confirmation.\(outcome.rawValue)",
        requestID: challenge.requestID,
        actionIdentifier: challenge.requestedAction.identifier,
        outcome: outcome.rawValue))
  }

  func recordTrace(_ record: RedactedTraceRecord) {
    Task { [weak self] in
      await self?.eventBus?.recordTrace(record)
    }
  }

  func appendConversation(_ message: AuraConversationMessage) {
    guard !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    if conversationMessages.last?.role == message.role,
      conversationMessages.last?.text == message.text
    {
      return
    }
    conversationMessages.append(message)
    conversationMessages = Array(conversationMessages.suffix(40))
  }

  func persistProductUIState() {
    guard let data = try? JSONEncoder().encode(productUIState) else { return }
    UserDefaults.standard.set(data, forKey: "aura.ui.state")
  }

  func setEmergencyStopActive() {
    emergencyStopActive = true
    status = .stopped
    statusDetail = "Emergency stop active"
  }

  func setError(_ message: String) {
    status = .error
    statusDetail = message
    lastOperationMessage = message
  }

  static let exportDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd"
    return formatter
  }()
}
