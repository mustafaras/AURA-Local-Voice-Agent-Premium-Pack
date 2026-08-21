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

  var body: some View {
    // The highest-stakes surface in the product: the user is authorizing a real
    // action. It is deliberately the most prominent panel — tinted heading,
    // risk stated in words, and the safe choice (Deny) reachable first in both
    // reading and tab order.
    AuraPanel(title: "Confirmation Required", tint: .orange) {
      VStack(alignment: .leading, spacing: AuraDesign.Spacing.s) {
        Text("\(challenge.requestedAction.domain).\(challenge.requestedAction.action)")
          .font(AuraDesign.Typography.sectionTitle)
        Text(challenge.targetSummary)
          .font(AuraDesign.Typography.body)
          .fixedSize(horizontal: false, vertical: true)
        Label(
          "Risk: \(challenge.riskTier.rawValue) · Expires \(challenge.expiresAt.formatted())",
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
          .accessibilityLabel("Trace: \(traceText)")
        }
        HStack {
          Button("Deny", role: .cancel) {
            model.resolveConfirmation(accepted: false, outcome: .denied)
          }
          .keyboardShortcut(.cancelAction)
          Spacer()
          Button("Allow Once") {
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

struct MemoryCorrectionSheet: View {
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
      Section("VS Code Bridge") {
        if model.isVSCodeBridgeAcceptanceEnabled {
          Text("Local authenticated bridge; the shared secret stays in AURA Keychain and VS Code SecretStorage.")
            .foregroundStyle(.secondary)
          LabeledContent("Extension ID", value: model.vscodeBridgeExtensionID)
          SecureField("Shared secret (16+ characters)", text: $model.vscodeBridgeSecret)
            .textContentType(.password)
          HStack {
            Button("Provision in AURA") { model.provisionVSCodeBridge() }
              .disabled(model.vscodeBridgeSecret.utf8.count < 16)
            Button("Revoke") { model.revokeVSCodeBridge() }
              .disabled(!model.isVSCodeBridgeProvisioned)
          }
          LabeledContent(
            "AURA Keychain",
            value: model.isVSCodeBridgeProvisioned ? "Provisioned" : "Not provisioned")
        } else {
          Text("The SP-012 live bridge profile is not enabled.")
            .foregroundStyle(.secondary)
        }
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
        ForEach(
          model.effectiveConfiguration.filter(\.differsFromDefault).prefix(8), id: \.key
        ) { entry in
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
