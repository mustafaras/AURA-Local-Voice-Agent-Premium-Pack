import AuraAgent
import AuraCore
import AuraStore
import Foundation
import SwiftUI
import Testing

@testable import AURA

@Suite("R9 product UI state")
struct R9ProductUIStateTests {
  @Test("tab, language, confirmation, and onboarding actions reduce deterministically")
  func reducerCoversProductState() {
    var state = AuraProductUIState()

    state.reduce(.selectTab(.privacy))
    state.reduce(.setLanguage(.turkish))
    state.reduce(.showConfirmation)
    state.reduce(.beginOnboarding)

    #expect(state.selectedTab == .privacy)
    #expect(state.language == .turkish)
    #expect(state.confirmationNeedsFocus)
    #expect(state.onboarding.isPresented)
    #expect(state.onboarding.stage == .privacy)

    state.reduce(.advanceOnboarding)
    #expect(state.onboarding.stage == .health)
    state.onboarding.stage = .wakeWord
    state.reduce(.skipOptionalOnboardingStep)
    #expect(state.onboarding.stage == .privilegedAccess)

    state.reduce(.hideConfirmation)
    state.reduce(.closeOnboarding)
    #expect(!state.confirmationNeedsFocus)
    #expect(!state.onboarding.isPresented)
  }

  @Test("localization covers every product tab and onboarding stage")
  func localizationHasNoMissingProductCopy() {
    for tab in AuraProductTab.allCases {
      #expect(AuraCopy.text(tab.copyKey, language: .english) != tab.copyKey)
      #expect(AuraCopy.text(tab.copyKey, language: .turkish) != tab.copyKey)
    }
    for stage in AuraOnboardingStage.allCases {
      #expect(AuraCopy.text(stage.copyKey, language: .english) != stage.copyKey)
      #expect(AuraCopy.text(stage.copyKey, language: .turkish) != stage.copyKey)
    }
  }

  @Test("status pill title and detail localize to Turkish")
  @MainActor
  func statusPillLocalizesToTurkish() {
    let model = AuraAppModel(startRuntime: false)
    // Status title differs by language and is never empty.
    for status in [AuraAppStatus.idle, .listening, .thinking, .restricted, .error] {
      #expect(status.title(for: .english) != status.title(for: .turkish))
      #expect(!status.title(for: .turkish).isEmpty)
    }
    // A known English internal statusDetail renders as Turkish.
    model.productUIState.language = .turkish
    model.statusDetail = "Ready — use Push to Talk"
    #expect(model.displayStatusDetail == "Hazır — Bas Konuş'u kullanın")
    // In English the internal detail is shown unchanged.
    model.productUIState.language = .english
    #expect(model.displayStatusDetail == "Ready — use Push to Talk")
    // Unknown detail falls through unchanged.
    model.productUIState.language = .turkish
    model.statusDetail = "custom runtime note"
    #expect(model.displayStatusDetail == "custom runtime note")
    model.bootTask?.cancel()
  }

  @Test("capability disabled/degraded reason prose localizes to Turkish")
  @MainActor
  func disabledReasonLocalizesToTurkish() {
    let model = AuraAppModel(startRuntime: false)
    model.productUIState.language = .turkish
    // A known disabled reason renders as Turkish.
    #expect(
      model.localizedReason("VS Code bridge not authenticated: no extension")
        == "VS Code köprüsü kimliği doğrulanmadı: no extension")
    #expect(
      model.localizedReason("Contacts reading is turned off in configuration.")
        == "Contacts okuma yapılandırmada kapatıldı.")
    // In English the reason is shown unchanged.
    model.productUIState.language = .english
    #expect(
      model.localizedReason("VS Code bridge not authenticated: no extension")
        == "VS Code bridge not authenticated: no extension")
    // Unknown reason falls through unchanged in Turkish too.
    model.productUIState.language = .turkish
    #expect(model.localizedReason("custom reason") == "custom reason")
    model.bootTask?.cancel()
  }

  @Test("non-audit memory export document remains Codable")
  func memoryExportDocumentRoundTrips() throws {
    let record = MemoryRecord(
      memoryClass: .userPreference,
      subject: "language",
      statement: "Türkçe",
      provenance: .userStated,
      confidence: 1,
      sensitivity: .internalLevel,
      retention: .indefinite,
      purpose: "user preference")
    let document = AuraMemoryExportDocument(
      generatedAt: Date(timeIntervalSince1970: 1), records: [record], conflicts: [])
    let data = try JSONEncoder().encode(document)
    let decoded = try JSONDecoder().decode(AuraMemoryExportDocument.self, from: data)

    #expect(decoded.records == [record])
    #expect(decoded.conflicts.isEmpty)
  }

  @Test("AppModel projects runtime events and constructs every product surface")
  @MainActor
  func appModelProjectionAndViews() async throws {
    let model = AuraAppModel(startRuntime: false)
    let savedLanguage = UserDefaults.standard.object(forKey: "aura.ui.language")
    let savedState = UserDefaults.standard.object(forKey: "aura.ui.state")
    defer {
      if let savedLanguage {
        UserDefaults.standard.set(savedLanguage, forKey: "aura.ui.language")
      } else {
        UserDefaults.standard.removeObject(forKey: "aura.ui.language")
      }
      if let savedState {
        UserDefaults.standard.set(savedState, forKey: "aura.ui.state")
      } else {
        UserDefaults.standard.removeObject(forKey: "aura.ui.state")
      }
    }
    let taskID = UUID()
    let now = Date(timeIntervalSince1970: 10)
    let record = MemoryRecord(
      memoryClass: .userPreference,
      subject: "language",
      statement: "Türkçe",
      provenance: .userStated,
      confidence: 1,
      sensitivity: .internalLevel,
      createdAt: now,
      retention: .indefinite,
      purpose: "user preference")
    let row = makeMemoryRow(from: record)
    applyProjectionEvents(to: model, taskID: taskID, now: now, row: row)
    model.status = .idle
    model.emergencyStopActive = false
    model.runtimeWarnings = []
    constructProductSurfaces(model: model, row: row, now: now)
    model.bootTask?.cancel()
    #expect(model.status == .idle)
    #expect(model.lastOperationMessage == "diagnostic")
    #expect(model.conversationMessages.count >= 3)

    let traceCorrelationID = UUID()
    let traceCausationID = UUID()
    model.applyToolResult(
      ToolResultEvent(
        intentID: UUID(), toolID: "app.terminate", succeeded: true, summary: "verified"),
      eventID: UUID(), correlationID: traceCorrelationID, causationID: traceCausationID)
    #expect(
      model.conversationMessages.contains { message in
        message.traceSummary
          == AuraTraceDisplay.summary(
            correlationID: traceCorrelationID, causationID: traceCausationID)
      })
  }

  @Test("confirmation lifecycle persists redacted terminal outcomes")
  @MainActor
  func confirmationLifecyclePersistsRedactedTrace() async throws {
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("aura-trace-(UUID().uuidString).sqlite").path
    defer { try? FileManager.default.removeItem(atPath: path) }

    let store = try await AuraStore(path: path)
    let model = AuraAppModel(startRuntime: false)
    model.eventBus = AuraEventBus(
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "trace"),
      tracePersistence: store)
    let context = TurnContext(
      sessionID: UUID(), correlationID: UUID(), causationID: UUID(),
      activationSource: .text, actor: .user, authority: .userUtterance,
      sensitivity: .internalLevel)
    let challenge = PolicyConfirmationChallenge(
      requestID: UUID(), sessionID: context.sessionID, nonce: "test-nonce",
      issuedAt: Date(), requestedAction: .shellExec, targetSummary: "test",
      riskTier: .reversible, expiresAt: Date().addingTimeInterval(60),
      expectedHash: "test-hash", turnContext: context)

    let deniedTask = Task { @MainActor in await model.awaitConfirmation(challenge) }
    while model.pendingConfirmation == nil { await Task.yield() }
    model.resolveConfirmation(accepted: false, outcome: .denied)
    #expect(await deniedTask.value == false)

    let expiringChallenge = PolicyConfirmationChallenge(
      requestID: UUID(), sessionID: context.sessionID, nonce: "expiry-nonce",
      issuedAt: Date(), requestedAction: .shellExec, targetSummary: "test",
      riskTier: .reversible, expiresAt: Date().addingTimeInterval(0.02),
      expectedHash: "expiry-hash", turnContext: context)
    #expect(await model.awaitConfirmation(expiringChallenge) == false)

    var rows = try await store.database.query(
      sql: "SELECT * FROM redacted_trace_records ORDER BY rowid;", arguments: [])
    for _ in 0..<50 where rows.count < 4 {
      try await Task.sleep(for: .milliseconds(10))
      rows = try await store.database.query(
        sql: "SELECT * FROM redacted_trace_records ORDER BY rowid;", arguments: [])
    }
    #expect(rows.count == 4)
    #expect(
      rows.map { $0["outcome"]?.textValue }
        == ["requested", "denied", "requested", "expired"])
    #expect(rows.allSatisfy { $0["payload_json"] == nil })
  }

  @Test("window close dismisses a pending confirmation and persists only redacted trace")
  @MainActor
  func windowCloseDismissalPersistsRedactedTrace() async throws {
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("aura-window-dismiss-(UUID().uuidString).sqlite").path
    defer { try? FileManager.default.removeItem(atPath: path) }

    let store = try await AuraStore(path: path)
    let model = AuraAppModel(startRuntime: false)
    model.eventBus = AuraEventBus(
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "trace"),
      tracePersistence: store)
    let context = TurnContext(
      sessionID: UUID(), correlationID: UUID(), causationID: UUID(),
      activationSource: .text, actor: .user, authority: .userUtterance,
      sensitivity: .internalLevel)
    let challenge = PolicyConfirmationChallenge(
      requestID: UUID(), sessionID: context.sessionID, nonce: "dismiss-nonce",
      issuedAt: Date(), requestedAction: .shellExec, targetSummary: "test",
      riskTier: .reversible, expiresAt: Date().addingTimeInterval(60),
      expectedHash: "dismiss-hash", turnContext: context)

    let pendingTask = Task { @MainActor in await model.awaitConfirmation(challenge) }
    while model.pendingConfirmation == nil { await Task.yield() }
    model.dismissPendingConfirmationForWindowClose()
    #expect(await pendingTask.value == false)

    var rows = try await store.database.query(
      sql: "SELECT * FROM redacted_trace_records ORDER BY rowid;", arguments: [])
    for _ in 0..<50 where rows.count < 2 {
      try await Task.sleep(for: .milliseconds(10))
      rows = try await store.database.query(
        sql: "SELECT * FROM redacted_trace_records ORDER BY rowid;", arguments: [])
    }
    #expect(rows.count == 2)
    #expect(rows.map { $0["outcome"]?.textValue } == ["requested", "dismissed"])
    #expect(rows.allSatisfy { $0["payload_json"] == nil })
  }

  @Test("emergency stop cancels a pending confirmation and persists redacted trace")
  @MainActor
  func emergencyStopCancellationPersistsRedactedTrace() async throws {
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("aura-emergency-cancel-(UUID().uuidString).sqlite").path
    defer { try? FileManager.default.removeItem(atPath: path) }

    let store = try await AuraStore(path: path)
    let model = AuraAppModel(startRuntime: false)
    model.eventBus = AuraEventBus(
      logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "trace"),
      tracePersistence: store)
    let context = TurnContext(
      sessionID: UUID(), correlationID: UUID(), causationID: UUID(),
      activationSource: .text, actor: .user, authority: .userUtterance,
      sensitivity: .internalLevel)
    let challenge = PolicyConfirmationChallenge(
      requestID: UUID(), sessionID: context.sessionID, nonce: "cancel-nonce",
      issuedAt: Date(), requestedAction: .shellExec, targetSummary: "test",
      riskTier: .reversible, expiresAt: Date().addingTimeInterval(60),
      expectedHash: "cancel-hash", turnContext: context)

    let pendingTask = Task { @MainActor in await model.awaitConfirmation(challenge) }
    while model.pendingConfirmation == nil { await Task.yield() }
    model.triggerEmergencyStop()
    while model.pendingConfirmation != nil { await Task.yield() }
    #expect(await pendingTask.value == false)
    #expect(model.emergencyStopActive)

    var rows = try await store.database.query(
      sql: "SELECT * FROM redacted_trace_records ORDER BY rowid;", arguments: [])
    for _ in 0..<50 where rows.count < 2 {
      try await Task.sleep(for: .milliseconds(10))
      rows = try await store.database.query(
        sql: "SELECT * FROM redacted_trace_records ORDER BY rowid;", arguments: [])
    }
    #expect(rows.count == 2)
    #expect(rows.map { $0["outcome"]?.textValue } == ["requested", "cancelled"])
    #expect(rows.allSatisfy { $0["payload_json"] == nil })
  }

  @MainActor
  private func makeMemoryRow(from record: MemoryRecord) -> AuraMemoryRow {
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
      canMutate: true)
  }

  @MainActor
  private func applyProjectionEvents(
    to model: AuraAppModel, taskID: UUID, now: Date, row: AuraMemoryRow
  ) {
    for state in [
      ConversationState.idle,
      .listening,
      .thinking,
      .speaking,
      .interrupted,
      .timeout,
      .error,
    ] {
      model.applyConversationState(
        ConversationStateEvent(state: state, reason: state.rawValue))
    }
    model.applyRuntimeHealth([
      RuntimeHealth(componentID: "zeta", status: .degraded, detail: "degraded"),
      RuntimeHealth(componentID: "alpha", status: .ready, detail: "ready"),
    ])
    model.applyRuntimeHealth(
      RuntimeHealth(componentID: "beta", status: .failed, detail: "failed"))
    model.recordTask(
      TaskEnqueuedEvent(
        taskID: taskID, objective: "Inspect status", priority: .normal, enqueuedAt: now))
    model.updateTask(
      TaskStateChangedEvent(
        taskID: taskID, previousState: .pending, newState: .running, changedAt: now))
    model.applyPartialTranscript(STTPartialEvent(text: "partial", confidence: 0.8))
    model.applyCompletedTurn(TurnCompletedEvent(text: "hello", confidence: 1, isFinal: true))
    model.applyCompletedTurn(TurnCompletedEvent(text: "  ", confidence: 1, isFinal: true))
    model.applyResponsePlan(
      ResponsePlanEvent(planID: "plan", summary: "answer", hasSpokenResponse: true))
    model.applyResponsePlan(
      ResponsePlanEvent(planID: "empty", summary: "", hasSpokenResponse: false))
    model.applyToolResult(
      ToolResultEvent(intentID: UUID(), toolID: "tool", succeeded: false, summary: "blocked"))
    model.applyIntentBlocked(IntentBlockedEvent(intentID: UUID(), reason: "policy"))
    model.appendConversation(.init(role: .assistant, text: "answer"))
    model.appendConversation(.init(role: .assistant, text: "answer"))
    model.appendConversation(.init(role: .system, text: "   "))
    model.setEmergencyStopActive()
    model.setError("diagnostic")
    model.beginMemoryCorrection(row)
    model.selectTab(.tasks)
    model.setUILanguage(.turkish)
    model.beginOnboarding()
    model.advanceOnboarding()
    model.skipOptionalOnboardingStep()
    model.closeOnboarding()
    model.resolveConfirmation(accepted: false)
  }

  @MainActor
  private func constructProductSurfaces(model: AuraAppModel, row: AuraMemoryRow, now: Date) {
    let challenge = PolicyConfirmationChallenge(
      requestID: UUID(), sessionID: UUID(), nonce: "nonce", issuedAt: now,
      requestedAction: .shellExec, targetSummary: "echo test", riskTier: .mutation,
      expiresAt: now.addingTimeInterval(60), expectedHash: "hash")
    let menu = AuraMenuView(model: model)
    _ = menu.body
    _ = menu.header
    _ = menu.tabPicker
    for tab in AuraProductTab.allCases {
      model.productUIState.selectedTab = tab
      _ = menu.tabContent
      _ = menu.sectionTitle(tab.copyKey, symbol: tab.symbolName)
    }
    for state in TaskState.allCases { _ = menu.taskState(state) }
    for state in [
      AgentBackendHealthState.ready,
      .degraded,
      .unavailable,
      .unauthorized,
      .versionMismatch,
    ] {
      _ = menu.backendState(state)
    }
    _ = menu.locality("local")
    _ = menu.locality("remote")
    _ = menu.permissionIndicator("Permission", "Granted")
    _ = menu.conversationMessage(
      AuraConversationMessage(role: .user, text: "user", sourceSummary: "source"))
    _ = menu.conversationMessage(AuraConversationMessage(role: .system, text: "system"))
    _ = AuraConfirmationCard(model: model, challenge: challenge).body
    _ = MemoryRowView(model: model, record: row).body
    let auditRow = AuraMemoryRow(
      id: row.id, memoryClass: "auditSecurity", subject: row.subject,
      statement: row.statement, purpose: row.purpose, provenance: row.provenance,
      confidence: row.confidence, sensitivity: row.sensitivity, createdAt: row.createdAt,
      canMutate: false)
    _ = MemoryRowView(model: model, record: auditRow).body
    _ = MemoryCorrectionSheet(model: model, record: row).body
    for stage in AuraOnboardingStage.allCases {
      model.productUIState.onboarding.stage = stage
      _ = AuraOnboardingView(model: model).body
    }
    _ = AuraSettingsView(model: model).body
  }

  @Test("design typography uses scalable relative text styles for Dynamic Type")
  func designTypographyScalesWithDynamicType() {
    // WCAG 1.4.4 (resize text): the product surface must scale with the
    // user's Dynamic Type / accessibility text size. Fixed `Font.system(size:)`
    // point sizes would leave the UI unreadable at large accessibility sizes.
    // The design tokens must resolve to relative text styles, not fixed sizes.
    // (SF Symbol icon sizes are exempt — icons do not carry text.)
    //
    // `Font` has no public `size` accessor, so we assert the tokens equal the
    // relative text styles they are defined as. A fixed `Font.system(size:)`
    // would not equal any of these.
    #expect(AuraDesign.Typography.body == Font.body)
    #expect(AuraDesign.Typography.sectionTitle == Font.subheadline.weight(.semibold))
    #expect(AuraDesign.Typography.meta == Font.caption)
    #expect(AuraDesign.Typography.wordmark == Font.headline.weight(.semibold))
  }
}
