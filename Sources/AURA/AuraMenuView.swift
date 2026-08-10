import AuraAgent
import AuraCore
import SwiftUI

struct AuraMenuView: View {
  @ObservedObject var model: AuraAppModel

  private var language: AuraUILanguage { model.productUIState.language }

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

  private var header: some View {
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

  private var tabPicker: some View {
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
  private var tabContent: some View {
    switch model.productUIState.selectedTab {
    case .conversation: conversationTab
    case .tasks: tasksTab
    case .capabilities: capabilitiesTab
    case .models: modelsTab
    case .privacy: privacyTab
    case .recovery: recoveryTab
    }
  }

  private var conversationTab: some View {
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

  private func conversationMessage(_ message: AuraConversationMessage) -> some View {
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
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .tint(message.isDegraded ? .orange : .accentColor)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(role): \(message.text)")
  }

  private var tasksTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("tasks.title", symbol: "checklist")
      if model.taskStatuses.isEmpty {
        Text(copy("tasks.empty")).foregroundStyle(.secondary)
      }
      ForEach(model.taskStatuses) { task in
        GroupBox {
          VStack(alignment: .leading, spacing: 7) {
            HStack {
              Text(task.objective).bold().fixedSize(horizontal: false, vertical: true)
              Spacer()
              Text(taskState(task.state))
                .foregroundStyle(task.state == .failed ? .red : .secondary)
            }
            ProgressView(value: task.percentComplete)
              .accessibilityLabel(
                "\(copy("tasks.progress")): \(Int(task.percentComplete * 100)) percent")
            Text(
              task.currentStepDescription.isEmpty
                ? "\(task.completedSteps)/\(task.totalSteps)"
                : task.currentStepDescription
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            if let error = task.errorMessage {
              Text("Failed: \(error)")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
              Text(task.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2).foregroundStyle(.secondary)
              Spacer()
              if task.state == .pending || task.state == .running || task.state == .paused {
                Button(copy("tasks.cancel"), role: .destructive) {
                  model.cancelTask(task.id)
                }
                .accessibilityHint(
                  language == .turkish
                    ? "Bu kalıcı görevin çalışmasını durdurmayı ister"
                    : "Requests cancellation of this durable task")
              }
            }
          }
        }
        .accessibilityElement(children: .contain)
      }
    }
  }

  private var capabilitiesTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionTitle("capabilities.title", symbol: "switch.2")
        Spacer()
        Button {
          model.refreshProductSnapshots()
        } label: {
          Label(copy("capabilities.refresh"), systemImage: "arrow.clockwise")
        }
        .accessibilityLabel(copy("capabilities.refresh"))
      }
      ForEach(model.capabilityRows, id: \AuraCapabilityRow.id) { (capability: AuraCapabilityRow) in
        GroupBox {
          VStack(alignment: .leading, spacing: 5) {
            HStack {
              Text(capability.title).bold()
              Spacer()
              Text(capability.state)
                .foregroundStyle(capability.isEnabled ? .green : .orange)
            }
            Text(capability.description).fixedSize(horizontal: false, vertical: true)
            Text("\(locality(capability.locality)) · \(capability.qualifiedID)")
              .font(.caption).foregroundStyle(.secondary)
            Text(capability.detail)
              .font(.caption)
              .foregroundStyle(capability.isEnabled ? Color.secondary : Color.orange)
              .fixedSize(horizontal: false, vertical: true)
            Text("Confirmation / risk: \(capability.riskAndConfirmation)")
              .font(.caption2).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(capability.title), \(capability.state), \(capability.detail), \(locality(capability.locality))"
        )
      }
      if model.capabilityRows.isEmpty {
        Text("No registered capabilities are available to inspect.")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var modelsTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionTitle("models.title", symbol: "waveform.and.mic")
        Spacer()
        Button {
          model.refreshProductSnapshots()
        } label: {
          Label(copy("models.refresh"), systemImage: "arrow.clockwise")
        }
      }
      GroupBox("Voice") {
        VStack(alignment: .leading, spacing: 5) {
          Label(
            "Speech recognition: \(model.permissions.speechRecognition.title)",
            systemImage: "waveform")
          Label("System speech synthesis: configured local pipeline", systemImage: "speaker.wave.2")
          Text(
            "Reference-voice cloning is not enabled by this surface and requires explicit consent."
          )
          .font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      ForEach(model.backendHealth, id: \.backend) { backend in
        GroupBox(backend.backend.rawValue.capitalized) {
          VStack(alignment: .leading, spacing: 4) {
            Text("State: \(backendState(backend.state))")
            Text("Authentication: \(backend.authentication.rawValue)")
            Text("Model availability: \(backend.modelAvailability)")
            Text(backend.detail)
              .font(.caption).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
      }
      Text(copy("models.unverified"))
        .font(.caption).foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var privacyTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("privacy.title", symbol: "lock.shield")
      GroupBox("Permission indicators") {
        VStack(alignment: .leading, spacing: 5) {
          permissionIndicator("Microphone", model.permissions.microphone.title)
          permissionIndicator(
            "Active speech recognition", model.permissions.speechRecognition.title)
          permissionIndicator("Screen observation", model.permissions.screenRecording.title)
          Label(copy("conversation.cloudDisabled"), systemImage: "icloud.slash")
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack {
        Button {
          model.exportMemory()
        } label: {
          Label(copy("privacy.export"), systemImage: "square.and.arrow.up")
        }
        .accessibilityHint(
          language == .turkish
            ? "Denetim ve güvenlik kayıtları dışarı aktarılmaz"
            : "Audit and security records are excluded")
        Spacer()
        Text("\(model.memoryRows.count) records")
          .font(.caption).foregroundStyle(.secondary)
      }
      if model.memoryRows.isEmpty {
        Text(copy("privacy.noMemory")).foregroundStyle(.secondary)
      }
      ForEach(model.memoryRows) { record in
        MemoryRowView(model: model, record: record)
      }
    }
  }

  private var recoveryTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionTitle("recovery.title", symbol: "stethoscope")
        Spacer()
        Button {
          model.refreshPermissions()
          model.refreshProductSnapshots()
        } label: {
          Label(copy("recovery.refresh"), systemImage: "arrow.clockwise")
        }
      }
      GroupBox("Permissions") {
        VStack(alignment: .leading, spacing: 7) {
          permissionIndicator("Microphone", model.permissions.microphone.title)
          permissionIndicator("Speech Recognition", model.permissions.speechRecognition.title)
          permissionIndicator("Accessibility", model.permissions.accessibility.title)
          permissionIndicator("Screen Recording", model.permissions.screenRecording.title)
          Button("Open macOS Privacy Settings") { model.openMicrophoneSettings() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      GroupBox("Runtime diagnostics") {
        VStack(alignment: .leading, spacing: 5) {
          ForEach(model.runtimeHealth, id: \RuntimeHealth.componentID) { (health: RuntimeHealth) in
            let diagnosticLabel =
              "\(health.componentID): \(health.status.rawValue). \(health.detail)"
            Label(
              "\(health.componentID): \(health.status.rawValue)",
              systemImage: health.status == .ready ? "checkmark.circle" : "exclamationmark.triangle"
            )
            .foregroundStyle(health.status == .ready ? Color.secondary : Color.orange)
            .accessibilityLabel(diagnosticLabel)
          }
          ForEach(model.runtimeWarnings, id: \.self) { warning in
            Text(warning).font(.caption).foregroundStyle(.orange)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      emergencyControls
      Toggle(
        "Local tuning recommendations",
        isOn: Binding(
          get: { model.localRecommendationsEnabled },
          set: { model.setLocalRecommendationsEnabled($0) }))
      Text(copy("recovery.support"))
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var emergencyControls: some View {
    GroupBox("Emergency control") {
      if model.emergencyStopActive {
        Button("Re-arm generated input") {
          model.resetEmergencyStop()
        }
        .controlSize(.large)
        .accessibilityHint("Allows generated mouse and keyboard input again")
      } else {
        Button(role: .destructive) {
          model.triggerEmergencyStop()
        } label: {
          Label("Emergency Stop", systemImage: "hand.raised.fill")
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .keyboardShortcut(.escape, modifiers: [.command, .shift])
        .accessibilityHint("Immediately disables generated input")
      }
    }
  }

  private func sectionTitle(_ key: String, symbol: String) -> some View {
    Label(copy(key), systemImage: symbol)
      .font(.title3.bold())
      .accessibilityAddTraits(.isHeader)
  }

  private func permissionIndicator(_ name: String, _ state: String) -> some View {
    HStack {
      Text(name)
      Spacer()
      Text(state).foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(name): \(state)")
  }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  private func locality(_ value: String) -> String {
    value == "local"
      ? (language == .turkish ? "Yerel" : "Local")
      : (language == .turkish ? "Bulut" : "Cloud")
  }

  private func taskState(_ state: TaskState) -> String {
    guard language == .turkish else { return state.rawValue.capitalized }
    switch state {
    case .pending: return "Bekliyor"
    case .running: return "Çalışıyor"
    case .paused: return "Duraklatıldı"
    case .cancelled: return "İptal edildi"
    case .completed: return "Tamamlandı"
    case .failed: return "Başarısız"
    }
  }

  private func backendState(_ state: AgentBackendHealthState) -> String {
    guard language == .turkish else { return state.rawValue }
    switch state {
    case .ready: return "Hazır"
    case .degraded: return "Kısıtlı"
    case .unavailable: return "Kullanılamıyor"
    case .unauthorized: return "Yetkisiz"
    case .versionMismatch: return "Sürüm uyumsuz"
    }
  }
}

private struct AuraConfirmationCard: View {
  @ObservedObject var model: AuraAppModel
  let challenge: PolicyConfirmationChallenge

  var body: some View {
    GroupBox("Confirmation Required") {
      VStack(alignment: .leading, spacing: 8) {
        Text("\(challenge.requestedAction.domain).\(challenge.requestedAction.action)")
          .font(.headline)
        Text(challenge.targetSummary)
          .fixedSize(horizontal: false, vertical: true)
        Text("Risk: \(challenge.riskTier.rawValue) · Expires \(challenge.expiresAt.formatted())")
          .font(.caption).foregroundStyle(.secondary)
        HStack {
          Button("Deny", role: .cancel) {
            model.resolveConfirmation(accepted: false)
          }
          .keyboardShortcut(.cancelAction)
          Spacer()
          Button("Allow Once") {
            model.resolveConfirmation(accepted: true)
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }
}

private struct MemoryRowView: View {
  @ObservedObject var model: AuraAppModel
  let record: AuraMemoryRow

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 6) {
        Text(record.statement).fixedSize(horizontal: false, vertical: true)
        Text("\(record.memoryClass) · \(record.subject)")
          .font(.caption).foregroundStyle(.secondary)
        Text("Purpose: \(record.purpose) · Provenance: \(record.provenance)")
          .font(.caption2).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text("Confidence: \(Int(record.confidence * 100))% · Sensitivity: \(record.sensitivity)")
          .font(.caption2).foregroundStyle(.secondary)
        if record.canMutate {
          HStack {
            Button("Correct") { model.beginMemoryCorrection(record) }
            Button("Delete", role: .destructive) { model.deleteMemory(record.id) }
          }
        } else {
          Text("Audit/security records are not user-mutable.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .contain)
  }
}

private struct MemoryCorrectionSheet: View {
  @ObservedObject var model: AuraAppModel
  let record: AuraMemoryRow
  let draft: AuraMemoryCorrectionDraft

  init(model: AuraAppModel, record: AuraMemoryRow) {
    self.model = model
    self.record = record
    self.draft = AuraMemoryCorrectionDraft(statement: record.statement)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Correct memory").font(.headline)
      TextEditor(
        text: Binding(
          get: { draft.statement },
          set: { draft.statement = $0 })
      )
      .frame(minHeight: 120)
      .border(.secondary)
      .accessibilityLabel("Corrected memory statement")
      HStack {
        Button("Cancel", role: .cancel) { model.memoryCorrectionTarget = nil }
        Spacer()
        Button("Save correction") {
          model.correctMemory(record.id, statement: draft.statement)
          model.memoryCorrectionTarget = nil
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .frame(width: 480, height: 260)
  }
}

private final class AuraMemoryCorrectionDraft: ObservableObject {
  var statement: String

  init(statement: String) {
    self.statement = statement
  }
}

private struct AuraOnboardingView: View {
  @ObservedObject var model: AuraAppModel
  private var language: AuraUILanguage { model.productUIState.language }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label(copy("onboarding.title"), systemImage: "wand.and.stars")
          .font(.title2.bold())
        Spacer()
        Button(copy("onboarding.close")) { model.closeOnboarding() }
      }
      ProgressView(value: Double(model.productUIState.onboarding.stage.rawValue), total: 12)
        .accessibilityLabel(
          "Setup step \(model.productUIState.onboarding.stage.rawValue + 1) of 13")
      Text(copy(model.productUIState.onboarding.stage.copyKey))
        .font(.title3.bold())
      Text(explanation)
        .fixedSize(horizontal: false, vertical: true)
      HStack {
        if model.productUIState.onboarding.stage.isOptional {
          Button(copy("onboarding.skip")) { model.skipOptionalOnboardingStep() }
        }
        Spacer()
        Button(primaryLabel) { model.onboardingPrimaryAction() }
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(24)
    .frame(width: 560, height: 300)
  }

  private var explanation: String {
    switch model.productUIState.onboarding.stage {
    case .privacy:
      return copy("conversation.cloudDisabled")
    case .health:
      return language == .turkish
        ? "Uyumluluk ve sağlık göstergeleri bu pencerede gerçek runtime kanıtıyla gösterilir."
        : "Compatibility and health are shown from the live runtime evidence available to this process."
    case .voicePermissions:
      return language == .turkish
        ? "Yalnızca mikrofon ve Konuşma Tanıma izni istenir. Reddederseniz güvenli kısıtlı mod korunur."
        : "Only Microphone and Speech Recognition are requested here. If denied, AURA remains safely restricted."
    case .voiceTest:
      return language == .turkish
        ? "Push to Talk ile tek bir yerel konuşma tanıma turu başlatın; kısmi ve kesin döküm Konuşma sekmesinde görünür."
        : "Use Push to Talk for one local speech-recognition turn; partial and final transcripts appear in Conversation."
    case .ttsTest:
      return language == .turkish
        ? "Sesli yanıt, yapılandırılmış yerel TTS hattından gelir. Ayrı bir sahte başarı sonucu gösterilmez."
        : "Spoken responses use the configured local TTS pipeline. This setup step does not invent a separate success result."
    case .wakeWord:
      return language == .turkish
        ? "Uyandırma sözcüğü isteğe bağlıdır; mevcut kurulumda akustik model yoktur ve Bas Konuş kullanılabilir."
        : "Wake word is optional; no acoustic model is installed in this configuration, so Push to Talk remains available."
    case .privilegedAccess:
      return language == .turkish
        ? "Erişilebilirlik ve Ekran Kaydı yalnızca açık kullanıcı eylemiyle istenir; verilmezse yetenekler devre dışı kalır."
        : "Accessibility and Screen Recording are requested only by explicit user action; denied capabilities remain disabled."
    case .localModel:
      return copy("models.unverified")
    case .integrations:
      return language == .turkish
        ? "Tarayıcı, posta ve takvim entegrasyonları isteğe bağlıdır; bu turda kapsam verilmez."
        : "Browser, mail, and calendar integrations are optional; no account scope is granted by this step."
    case .emergencyStop:
      return language == .turkish
        ? "Acil durdurma tüm oluşturulan girdileri kapatır. Önce durdurmayı, sonra açıkça yeniden kurmayı deneyin."
        : "Emergency stop disables generated input. Test the stop first, then explicitly re-arm it."
    case .safeCommand:
      return language == .turkish
        ? "Güvenli başlangıç komutu olarak yalnızca açıklama/yardım isteği kullanın; yan etkili işlem yetkilendirilmez."
        : "Use a read-only help or explanation request as the safe first command; side effects are not authorized here."
    case .launchAtLogin:
      return language == .turkish
        ? "Girişte başlatma R11 kapsamındadır; bu adım ayarı değiştirmez."
        : "Launch at login belongs to R11; this step does not change that setting."
    case .complete:
      return language == .turkish ? "Kurulum tamamlandı." : "Setup is complete."
    }
  }

  private var primaryLabel: String {
    switch model.productUIState.onboarding.stage {
    case .voicePermissions: return language == .turkish ? "İzinleri iste" : "Request permissions"
    case .voiceTest: return language == .turkish ? "Teste geç" : "Continue to test"
    case .emergencyStop: return language == .turkish ? "Durdur / yeniden kur" : "Stop / re-arm"
    case .complete: return language == .turkish ? "Kapat" : "Close"
    default: return copy("onboarding.next")
    }
  }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }
}

struct AuraSettingsView: View {
  @ObservedObject var model: AuraAppModel

  var body: some View {
    Form {
      Section("Product UI") {
        Picker(
          "Language",
          selection: Binding(
            get: { model.productUIState.language },
            set: { model.setUILanguage($0) })
        ) {
          Text("English").tag(AuraUILanguage.english)
          Text("Türkçe").tag(AuraUILanguage.turkish)
        }
        Button("Open guided setup") { model.beginOnboarding() }
      }
      Section("Voice") {
        LabeledContent("Activation", value: "Push to Talk")
        Text("A trained acoustic wake-word model is not installed.")
          .foregroundStyle(.secondary)
        Button("Request Microphone and Speech Access") { model.requestVoicePermissions() }
      }
      Section("System Permissions") {
        Button("Request Accessibility Access") { model.requestAccessibilityPermission() }
        Button("Request Screen Recording Access") { model.requestScreenRecordingPermission() }
        Button("Open Microphone Settings") { model.openMicrophoneSettings() }
        Button("Open Speech Recognition Settings") { model.openSpeechSettings() }
        Button("Open Accessibility Settings") { model.openAccessibilitySettings() }
        Button("Open Screen Recording Settings") { model.openScreenRecordingSettings() }
        Button("Refresh Permission Status") { model.refreshPermissions() }
      }
      Section("Privacy") {
        Text("Speech recognition and system speech synthesis remain on device.")
        Text("Plugin execution remains isolated in the verified helper process.")
      }
      Section("Configuration Governance") {
        Toggle(
          "Local tuning recommendations",
          isOn: Binding(
            get: { model.localRecommendationsEnabled },
            set: { model.setLocalRecommendationsEnabled($0) }))
        Text(
          "Uses bounded aggregate metrics only. Recommendations are never applied automatically."
        )
        .foregroundStyle(.secondary)
        LabeledContent("Effective keys", value: "\(model.effectiveConfiguration.count)")
        LabeledContent("Audit records", value: "\(model.configurationAuditCount)")
        ForEach(model.effectiveConfiguration.filter(\.differsFromDefault).prefix(8), id: \.key) {
          entry in
          LabeledContent(entry.key, value: entry.value.displayValue)
        }
        Button("Refresh Configuration Inspection") { model.refreshConfigurationInspection() }
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 620, height: 600)
  }
}
