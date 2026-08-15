import AuraAgent
import AuraCore
import SwiftUI

extension AuraMenuView {

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      tabPicker
      Divider()
      ScrollView {
        tabContent
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 8)
      }
    }
    .padding(16)
    .frame(minWidth: 680, minHeight: 720)
    .onAppear { model.refreshProductSnapshots() }
    .sheet(
      isPresented: Binding(
        get: { model.productUIState.onboarding.isPresented },
        set: { isPresented in
          if !isPresented { model.closeOnboarding() }
        })
    ) {
      AuraOnboardingView(model: model)
    }
    .sheet(item: $model.memoryCorrectionTarget) { record in
      MemoryCorrectionSheet(model: model, record: record)
    }
  }

  var header: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: model.status.symbolName)
        .font(.title2)
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text("AURA")
          .font(.headline)
        Text("\(model.status.title) — \(model.statusDetail)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 8)
      Picker(
        "Language",
        selection: Binding(
          get: { model.productUIState.language },
          set: { model.setUILanguage($0) })
      ) {
        Text("EN").tag(AuraUILanguage.english)
        Text("TR").tag(AuraUILanguage.turkish)
      }
      .pickerStyle(.segmented)
      .frame(width: 92)
      .accessibilityLabel(language == .turkish ? "Arayüz dili" : "Interface language")
      Button {
        model.beginOnboarding()
      } label: {
        Label(copy("onboarding.title"), systemImage: "wand.and.stars")
      }
      .buttonStyle(.bordered)
      .accessibilityHint(language == .turkish ? "Kurulum adımlarını açar" : "Opens guided setup")
    }
    .accessibilityElement(children: .contain)
  }

  var tabPicker: some View {
    Picker(
      "Sections",
      selection: Binding(
        get: { model.productUIState.selectedTab },
        set: { model.selectTab($0) })
    ) {
      ForEach(AuraProductTab.allCases) { tab in
        Label(copy(tab.copyKey), systemImage: tab.symbolName).tag(tab)
      }
    }
    .pickerStyle(.segmented)
    .accessibilityLabel(language == .turkish ? "AURA bölümleri" : "AURA sections")
  }

  @ViewBuilder
  var tabContent: some View {
    switch model.productUIState.selectedTab {
    case .conversation: conversationTab
    case .tasks: tasksTab
    case .capabilities: capabilitiesTab
    case .models: modelsTab
    case .privacy: privacyTab
    case .recovery: recoveryTab
    }
  }

  var conversationTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("conversation.title", symbol: "bubble.left.and.bubble.right")
      Label(copy("conversation.local"), systemImage: "lock.fill")
        .foregroundStyle(.secondary)
        .accessibilityLabel("\(copy("conversation.local")). \(copy("conversation.cloudDisabled"))")
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if model.conversationMessages.isEmpty {
            Text(copy("conversation.empty"))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          ForEach(model.conversationMessages) { message in
            conversationMessage(message)
          }
          if !model.partialTranscript.isEmpty {
            GroupBox(copy("conversation.partial")) {
              Text(model.partialTranscript)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(copy("conversation.partial")): \(model.partialTranscript)")
          }
        }
      }
      .frame(minHeight: 180, maxHeight: 300)
      .accessibilityElement(children: .contain)

      HStack(alignment: .bottom, spacing: 8) {
        TextField(copy("conversation.input"), text: $model.textInput)
          .textFieldStyle(.roundedBorder)
          .onSubmit { model.submitText() }
          .accessibilityLabel(copy("conversation.input"))
        Button {
          model.submitText()
        } label: {
          Image(systemName: "arrow.up.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(copy("conversation.submit"))
      }
      Button {
        model.pushToTalk()
      } label: {
        Label(copy("conversation.pushToTalk"), systemImage: "mic.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(model.emergencyStopActive)
      .keyboardShortcut(.space, modifiers: [.command, .shift])
      .accessibilityHint(copy("conversation.pushHint"))

      if let challenge = model.pendingConfirmation {
        AuraConfirmationCard(model: model, challenge: challenge)
          .id(challenge.requestID)
      }
      if let plan = model.lastPlanSummary, !plan.isEmpty {
        GroupBox("Plan / Verification") {
          Text(plan)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
      }
      if !model.lastOperationMessage.isEmpty {
        Text(model.lastOperationMessage)
          .font(.callout)
          .foregroundStyle(model.status == .error ? .red : .secondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("Diagnostic: \(model.lastOperationMessage)")
      }
      emergencyControls
    }
  }

  func conversationMessage(_ message: AuraConversationMessage) -> some View {
    let role: String
    switch message.role {
    case .user: role = language == .turkish ? "Siz" : "You"
    case .assistant: role = "AURA"
    case .system: role = language == .turkish ? "Sistem" : "System"
    }
    return GroupBox {
      VStack(alignment: .leading, spacing: 4) {
        Text(role).font(.caption).bold()
        Text(message.text)
          .fixedSize(horizontal: false, vertical: true)
        if let source = message.sourceSummary {
          Text(source).font(.caption2).foregroundStyle(.secondary)
        }
        if let trace = message.traceSummary {
          Text(trace)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .accessibilityLabel("Trace: \(trace)")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .tint(message.isDegraded ? .orange : .accentColor)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(role): \(message.text)")
  }

}
