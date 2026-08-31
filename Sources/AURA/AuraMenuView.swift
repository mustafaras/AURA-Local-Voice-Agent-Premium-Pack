import AuraAgent
import AuraCore
import SwiftUI

struct AuraMenuView: View {
  @ObservedObject var model: AuraAppModel
  @Environment(\.openSettings) var openSettings

  var language: AuraUILanguage { model.productUIState.language }

}

struct AuraConfirmationCard: View {
  @ObservedObject var model: AuraAppModel
  let challenge: PolicyConfirmationChallenge

  private var language: AuraUILanguage { model.productUIState.language }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  var body: some View {
    // The highest-stakes surface in the product: the user is authorizing a real
    // action. It is deliberately the most prominent panel — tinted heading,
    // risk stated in words, and the safe choice (Deny) reachable first in both
    // reading and tab order.
    AuraPanel(title: copy("confirmation.title"), tint: .orange) {
      VStack(alignment: .leading, spacing: AuraDesign.Spacing.s) {
        Text("\(challenge.requestedAction.domain).\(challenge.requestedAction.action)")
          .font(AuraDesign.Typography.sectionTitle)
        Text(challenge.targetSummary)
          .font(AuraDesign.Typography.body)
          .fixedSize(horizontal: false, vertical: true)
        Label(
          "\(copy("confirmation.riskPrefix")): \(challenge.riskTier.rawValue) · "
            + "\(copy("confirmation.expires")) \(challenge.expiresAt.formatted())",
          systemImage: "exclamationmark.shield"
        )
        .font(AuraDesign.Typography.meta)
        .foregroundStyle(.secondary)
        if let turnContext = challenge.turnContext {
          let traceText = AuraTraceDisplay.summary(
            correlationID: turnContext.correlationID, causationID: turnContext.causationID)
          Text(traceText)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .accessibilityLabel("\(copy("a11y.tracePrefix")): \(traceText)")
        }
        HStack {
          Button(copy("confirmation.deny"), role: .cancel) {
            model.resolveConfirmation(accepted: false, outcome: .denied)
          }
          .keyboardShortcut(.cancelAction)
          Spacer()
          Button(copy("confirmation.allowOnce")) {
            model.resolveConfirmation(accepted: true, outcome: .accepted)
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

struct MemoryRowView: View {
  @ObservedObject var model: AuraAppModel
  let record: AuraMemoryRow

  private var language: AuraUILanguage { model.productUIState.language }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 6) {
        Text(record.statement).fixedSize(horizontal: false, vertical: true)
        Text("\(record.memoryClass) · \(record.subject)")
          .font(.caption).foregroundStyle(.secondary)
        Text(
          "\(copy("memory.purpose")): \(record.purpose) · "
            + "\(copy("memory.provenance")): \(record.provenance)")
          .font(.caption2).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(
          "\(copy("memory.confidence")): \(Int(record.confidence * 100))% · "
            + "\(copy("memory.sensitivity")): \(record.sensitivity)")
          .font(.caption2).foregroundStyle(.secondary)
        Text(
          "\(copy("memory.retention")): \(String(describing: record.retention)) · "
            + "\(copy("memory.scope")): \(scopeSummary)")
          .font(.caption2).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if record.canMutate {
          HStack {
            Button(copy("memory.correctShort")) { model.beginMemoryCorrection(record) }
            Button(copy("memory.deleteShort"), role: .destructive) {
              model.deleteMemory(record.id)
            }
          }
        } else {
          Text(copy("memory.immutable"))
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .contain)
  }

  private var scopeSummary: String {
    let values = [
      record.scope.projectID.map { "project=\($0)" },
      record.scope.taskID.map { "task=\($0.uuidString.prefix(8))" },
      record.scope.sessionID.map { "session=\($0.uuidString.prefix(8))" },
    ].compactMap { $0 }
    return values.isEmpty ? copy("memory.global") : values.joined(separator: ", ")
  }
}

struct MemoryCorrectionSheet: View {
  @ObservedObject var model: AuraAppModel
  let record: AuraMemoryRow
  let draft: AuraMemoryCorrectionDraft

  init(model: AuraAppModel, record: AuraMemoryRow) {
    self.model = model
    self.record = record
    self.draft = AuraMemoryCorrectionDraft(statement: record.statement)
  }

  private var language: AuraUILanguage { model.productUIState.language }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(copy("privacy.correct")).font(.headline)
      TextEditor(
        text: Binding(
          get: { draft.statement },
          set: { draft.statement = $0 })
      )
      .frame(minHeight: 120)
      .border(.secondary)
      .accessibilityLabel(copy("a11y.correctedMemory"))
      HStack {
        Button(copy("action.cancel"), role: .cancel) { model.memoryCorrectionTarget = nil }
        Spacer()
        Button(copy("memory.saveCorrection")) {
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

final class AuraMemoryCorrectionDraft: ObservableObject {
  var statement: String

  init(statement: String) {
    self.statement = statement
  }
}

struct AuraOnboardingView: View {
  @ObservedObject var model: AuraAppModel
  private var language: AuraUILanguage { model.productUIState.language }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label(copy("onboarding.title"), systemImage: "wand.and.stars")
          .font(.title2.bold())
        Spacer()
        Button(copy("onboarding.close")) { model.closeOnboarding() }
          .accessibilityIdentifier(AuraAccessibilityID.onboardingClose)
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
            .accessibilityIdentifier(AuraAccessibilityID.onboardingSkip)
        }
        Spacer()
        Button(primaryLabel) { model.onboardingPrimaryAction() }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier(AuraAccessibilityID.onboardingPrimary)
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
        : "Compatibility and health are shown from the live runtime evidence "
          + "available to this process."
    case .voicePermissions:
      return language == .turkish
        ? "Yalnızca mikrofon ve Konuşma Tanıma izni istenir. "
          + "Reddederseniz güvenli kısıtlı mod korunur."
        : "Only Microphone and Speech Recognition are requested here. "
          + "If denied, AURA remains safely restricted."
    case .voiceTest:
      return language == .turkish
        ? "Push to Talk ile tek bir yerel konuşma tanıma turu başlatın; "
          + "kısmi ve kesin döküm Konuşma sekmesinde görünür."
        : "Use Push to Talk for one local speech-recognition turn; partial and "
          + "final transcripts appear in Conversation."
    case .ttsTest:
      return language == .turkish
        ? "Sesli yanıt, yapılandırılmış yerel TTS hattından gelir. "
          + "Ayrı bir sahte başarı sonucu gösterilmez."
        : "Spoken responses use the configured local TTS pipeline. "
          + "This setup step does not invent a separate success result."
    case .wakeWord:
      return language == .turkish
        ? "Uyandırma sözcüğü isteğe bağlıdır; mevcut kurulumda akustik model "
          + "yoktur ve Bas Konuş kullanılabilir."
        : "Wake word is optional; no acoustic model is installed in this "
          + "configuration, so Push to Talk remains available."
    case .privilegedAccess:
      return language == .turkish
        ? "Erişilebilirlik ve Ekran Kaydı yalnızca açık kullanıcı eylemiyle "
          + "istenir; verilmezse yetenekler devre dışı kalır."
        : "Accessibility and Screen Recording are requested only by explicit "
          + "user action; denied capabilities remain disabled."
    case .localModel:
      return copy("models.unverified")
    case .integrations:
      return language == .turkish
        ? "Tarayıcı, posta ve takvim entegrasyonları isteğe bağlıdır; bu turda kapsam verilmez."
        : "Browser, mail, and calendar integrations are optional; no account "
          + "scope is granted by this step."
    case .emergencyStop:
      return language == .turkish
        ? "Acil durdurma tüm oluşturulan girdileri kapatır. Önce durdurmayı, "
          + "sonra açıkça yeniden kurmayı deneyin."
        : "Emergency stop disables generated input. Test the stop first, then explicitly re-arm it."
    case .safeCommand:
      return language == .turkish
        ? "Güvenli başlangıç komutu olarak yalnızca açıklama/yardım isteği "
          + "kullanın; yan etkili işlem yetkilendirilmez."
        : "Use a read-only help or explanation request as the safe first "
          + "command; side effects are not authorized here."
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

  private var language: AuraUILanguage { model.productUIState.language }

  private func copy(_ key: String) -> String {
    AuraCopy.text(key, language: language)
  }

  var body: some View {
    Form {
      // A confirmation raised by a control in *this* window must be answerable
      // *in* this window. `AuraConfirmationCard` otherwise renders only inside
      // the main panel, and every AURA window dismisses when the app's focus
      // moves — so a user toggling launch-at-login here was asked to authorize
      // in a window they were not looking at, the challenge expired unanswered,
      // and the toggle failed with "was not confirmed". Verified live and
      // recorded in `EV-SP-030-20260831-R11-LIVE-GATE-02`.
      //
      // Rendered inline as the first row rather than in a `.sheet`: sheets
      // attached inside SwiftUI's `Settings` scene do not reliably present, so
      // a sheet here would have reintroduced the same invisible-confirmation
      // bug in a new form. First row means it is on screen without scrolling.
      if let challenge = model.pendingConfirmation {
        AuraConfirmationCard(model: model, challenge: challenge)
      }
      Section(copy("settings.productUI")) {
        Picker(
          copy("settings.language"),
          selection: Binding(
            get: { model.productUIState.language },
            set: { model.setUILanguage($0) })
        ) {
          Text("English").tag(AuraUILanguage.english)
          Text("Türkçe").tag(AuraUILanguage.turkish)
        }
        Button(copy("settings.openGuidedSetup")) { model.beginOnboarding() }
      }
      Section(copy("models.voice")) {
        LabeledContent(copy("settings.activation"), value: copy("conversation.pushToTalk"))
        Text(copy("settings.noWakeModel"))
          .foregroundStyle(.secondary)
        Button(copy("settings.requestMicSpeech")) { model.requestVoicePermissions() }
      }
      Section(copy("settings.systemPermissions")) {
        Button(copy("settings.requestAccessibility")) { model.requestAccessibilityPermission() }
        Button(copy("settings.requestScreenRecording")) { model.requestScreenRecordingPermission() }
        Button(copy("settings.openMicSettings")) { model.openMicrophoneSettings() }
        Button(copy("settings.openSpeechSettings")) { model.openSpeechSettings() }
        Button(copy("settings.openAccessibilitySettings")) { model.openAccessibilitySettings() }
        Button(copy("settings.openScreenRecordingSettings")) { model.openScreenRecordingSettings() }
        Button(copy("settings.refreshPermissions")) { model.refreshPermissions() }
      }
      Section(copy("settings.vscodeBridge")) {
        if model.isVSCodeBridgeAcceptanceEnabled {
          Text(copy("settings.bridgeSecretNote"))
          .foregroundStyle(.secondary)
          LabeledContent(copy("settings.extensionID"), value: model.vscodeBridgeExtensionID)
          SecureField(copy("settings.sharedSecret"), text: $model.vscodeBridgeSecret)
            .textContentType(.password)
          HStack {
            Button(copy("settings.provision")) { model.provisionVSCodeBridge() }
              .disabled(model.vscodeBridgeSecret.utf8.count < 16)
            Button(copy("settings.revoke")) { model.revokeVSCodeBridge() }
              .disabled(!model.isVSCodeBridgeProvisioned)
          }
          LabeledContent(
            copy("settings.auraKeychain"),
            value: model.isVSCodeBridgeProvisioned
              ? copy("settings.provisioned") : copy("settings.notProvisioned"))
        } else {
          Text(copy("settings.bridgeDisabled"))
            .foregroundStyle(.secondary)
        }
      }
      Section(copy("settings.startup")) {
        Toggle(
          copy("settings.launchAtLogin"),
          isOn: Binding(
            get: { model.launchAtLoginEnabled },
            set: { model.setLaunchAtLogin($0) }))
        Text(copy("settings.launchAtLoginNote"))
          .font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if !model.launchAtLoginDetail.isEmpty {
          Text(model.launchAtLoginDetail)
            .font(.caption2).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Section(copy("settings.privacy")) {
        Text(copy("settings.onDeviceNote"))
        Text(copy("settings.pluginIsolation"))
      }
      Section(copy("settings.configGovernance")) {
        Toggle(
          copy("recovery.localTuning"),
          isOn: Binding(
            get: { model.localRecommendationsEnabled },
            set: { model.setLocalRecommendationsEnabled($0) }))
        Text(copy("settings.aggregateNote"))
        .foregroundStyle(.secondary)
        LabeledContent(copy("settings.effectiveKeys"), value: "\(model.effectiveConfiguration.count)")
        LabeledContent(copy("settings.auditRecords"), value: "\(model.configurationAuditCount)")
        ForEach(
          model.effectiveConfiguration.filter(\.differsFromDefault).prefix(8), id: \.key
        ) { entry in
          LabeledContent(entry.key, value: entry.value.displayValue)
        }
        Button(copy("settings.refreshConfig")) { model.refreshConfigurationInspection() }
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 620, height: 600)
    .onAppear { model.refreshLaunchAtLogin() }
    // Closing this window with a confirmation still unanswered fails closed
    // rather than leaving the challenge to lapse on its 60 s timer.
    .onDisappear { model.denyConfirmationIfStillPending() }
  }
}
