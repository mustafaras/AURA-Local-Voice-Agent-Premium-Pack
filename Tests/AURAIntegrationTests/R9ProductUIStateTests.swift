import AuraAgent
import AuraCore
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
}
