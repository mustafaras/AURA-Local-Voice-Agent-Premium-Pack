import AuraCore
import Foundation

struct AuraMemoryExportDocument: Codable {
  let generatedAt: Date
  let records: [MemoryRecord]
  let conflicts: [MemoryConflict]
}

struct AuraConversationMessage: Identifiable, Equatable, Sendable {
  enum Role: String, Sendable {
    case user
    case assistant
    case system
  }

  let id: UUID
  let role: Role
  let text: String
  let timestamp: Date
  let isDegraded: Bool
  let sourceSummary: String?

  init(
    id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date(),
    isDegraded: Bool = false, sourceSummary: String? = nil
  ) {
    self.id = id
    self.role = role
    self.text = text
    self.timestamp = timestamp
    self.isDegraded = isDegraded
    self.sourceSummary = sourceSummary
  }
}

struct AuraCapabilityRow: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let description: String
  let locality: String
  let state: String
  let detail: String
  let riskAndConfirmation: String
  let qualifiedID: String
  let isEnabled: Bool
}

struct AuraMemoryRow: Identifiable, Equatable, Sendable {
  let id: UUID
  let memoryClass: String
  let subject: String
  let statement: String
  let purpose: String
  let provenance: String
  let confidence: Double
  let sensitivity: String
  let createdAt: Date
  let canMutate: Bool
}

/// The product surfaces are deliberately finite so keyboard navigation,
/// VoiceOver ordering, and state restoration have one inspectable contract.
enum AuraProductTab: String, CaseIterable, Codable, Identifiable, Sendable {
  case conversation
  case tasks
  case capabilities
  case models
  case privacy
  case recovery

  var id: String { rawValue }

  var symbolName: String {
    switch self {
    case .conversation: "bubble.left.and.bubble.right"
    case .tasks: "checklist"
    case .capabilities: "switch.2"
    case .models: "waveform.and.mic"
    case .privacy: "lock.shield"
    case .recovery: "stethoscope"
    }
  }

  var copyKey: String { "tab.\(rawValue)" }
}

enum AuraUILanguage: String, CaseIterable, Codable, Sendable {
  case english = "en"
  case turkish = "tr"
}

enum AuraOnboardingStage: Int, CaseIterable, Codable, Sendable {
  case privacy = 0
  case health
  case voicePermissions
  case voiceTest
  case ttsTest
  case wakeWord
  case privilegedAccess
  case localModel
  case integrations
  case emergencyStop
  case safeCommand
  case launchAtLogin
  case complete

  var copyKey: String { "onboarding.stage.\(rawValue)" }

  var isOptional: Bool {
    switch self {
    case .wakeWord, .privilegedAccess, .localModel, .integrations, .launchAtLogin:
      true
    default:
      false
    }
  }
}

struct AuraOnboardingState: Codable, Equatable, Sendable {
  var stage: AuraOnboardingStage
  var isPresented: Bool

  init(stage: AuraOnboardingStage = .privacy, isPresented: Bool = false) {
    self.stage = stage
    self.isPresented = isPresented
  }
}

enum AuraProductUIAction: Equatable, Sendable {
  case selectTab(AuraProductTab)
  case setLanguage(AuraUILanguage)
  case beginOnboarding
  case advanceOnboarding
  case skipOptionalOnboardingStep
  case closeOnboarding
  case showConfirmation
  case hideConfirmation
}

struct AuraProductUIState: Codable, Equatable, Sendable {
  var selectedTab: AuraProductTab = .conversation
  var language: AuraUILanguage = .english
  var onboarding = AuraOnboardingState()
  var confirmationNeedsFocus = false

  mutating func reduce(_ action: AuraProductUIAction) {
    switch action {
    case .selectTab(let tab):
      selectedTab = tab
    case .setLanguage(let language):
      self.language = language
    case .beginOnboarding:
      onboarding.isPresented = true
    case .advanceOnboarding:
      guard onboarding.stage != .complete else {
        onboarding.isPresented = false
        return
      }
      onboarding.stage = AuraOnboardingStage(rawValue: onboarding.stage.rawValue + 1) ?? .complete
    case .skipOptionalOnboardingStep:
      guard onboarding.stage.isOptional else { return }
      onboarding.stage = AuraOnboardingStage(rawValue: onboarding.stage.rawValue + 1) ?? .complete
    case .closeOnboarding:
      onboarding.isPresented = false
    case .showConfirmation:
      confirmationNeedsFocus = true
    case .hideConfirmation:
      confirmationNeedsFocus = false
    }
  }
}

/// A small, dependency-free localization table for the product shell. Domain
/// content remains supplied by the owning subsystem; this table covers the
/// controls, states, and recovery guidance owned by the UI.
enum AuraCopy {
  static func text(_ key: String, language: AuraUILanguage) -> String {
    let values: [AuraUILanguage: String]
    switch key {
    case "app.name": values = [.english: "AURA", .turkish: "AURA"]
    case "tab.conversation": values = [.english: "Conversation", .turkish: "Konuşma"]
    case "tab.tasks": values = [.english: "Tasks", .turkish: "Görevler"]
    case "tab.capabilities": values = [.english: "Capabilities", .turkish: "Yetenekler"]
    case "tab.models": values = [.english: "Models & Voice", .turkish: "Modeller ve Ses"]
    case "tab.privacy": values = [.english: "Privacy & Memory", .turkish: "Gizlilik ve Bellek"]
    case "tab.recovery": values = [.english: "Recovery", .turkish: "Kurtarma"]
    case "conversation.title": values = [.english: "Conversation", .turkish: "Konuşma"]
    case "conversation.input": values = [.english: "Type a request", .turkish: "Bir istek yazın"]
    case "conversation.submit":
      values = [.english: "Submit typed request", .turkish: "Yazılı isteği gönder"]
    case "conversation.pushToTalk": values = [.english: "Push to Talk", .turkish: "Bas Konuş"]
    case "conversation.pushHint":
      values = [
        .english: "Starts one local speech-recognition turn",
        .turkish: "Tek bir yerel konuşma tanıma turu başlatır",
      ]
    case "conversation.partial":
      values = [.english: "Live partial transcript", .turkish: "Canlı kısmi döküm"]
    case "conversation.empty":
      values = [
        .english: "Your conversation will appear here.", .turkish: "Konuşmanız burada görünecek.",
      ]
    case "conversation.local": values = [.english: "Local processing", .turkish: "Yerel işleme"]
    case "conversation.cloudDisabled":
      values = [
        .english: "Cloud context is disabled by machine policy",
        .turkish: "Bulut bağlamı makine politikasıyla devre dışı",
      ]
    case "tasks.title": values = [.english: "Task Center", .turkish: "Görev Merkezi"]
    case "tasks.empty":
      values = [
        .english: "No durable tasks are currently tracked.",
        .turkish: "Şu anda izlenen kalıcı görev yok.",
      ]
    case "tasks.cancel": values = [.english: "Cancel task", .turkish: "Görevi iptal et"]
    case "tasks.progress": values = [.english: "Progress", .turkish: "İlerleme"]
    case "capabilities.title":
      values = [.english: "Capability & Permission Center", .turkish: "Yetenek ve İzin Merkezi"]
    case "capabilities.refresh":
      values = [.english: "Refresh capability status", .turkish: "Yetenek durumunu yenile"]
    case "capabilities.disabled": values = [.english: "Disabled", .turkish: "Devre dışı"]
    case "capabilities.ready": values = [.english: "Ready", .turkish: "Hazır"]
    case "capabilities.degraded": values = [.english: "Degraded", .turkish: "Kısıtlı"]
    case "models.title":
      values = [.english: "Model & Voice Center", .turkish: "Model ve Ses Merkezi"]
    case "models.refresh":
      values = [.english: "Refresh model health", .turkish: "Model sağlığını yenile"]
    case "models.local": values = [.english: "Local", .turkish: "Yerel"]
    case "models.unverified":
      values = [
        .english: "Authentication and model availability are unverified",
        .turkish: "Kimlik doğrulama ve model kullanılabilirliği doğrulanmadı",
      ]
    case "privacy.title":
      values = [
        .english: "Privacy, Memory & Integrations", .turkish: "Gizlilik, Bellek ve Entegrasyonlar",
      ]
    case "privacy.export":
      values = [.english: "Export non-audit memory", .turkish: "Denetim dışı belleği dışa aktar"]
    case "privacy.delete": values = [.english: "Delete memory", .turkish: "Belleği sil"]
    case "privacy.correct": values = [.english: "Correct memory", .turkish: "Belleği düzelt"]
    case "privacy.noMemory":
      values = [
        .english: "No user-inspectable memory records.",
        .turkish: "Kullanıcının inceleyebileceği bellek kaydı yok.",
      ]
    case "recovery.title":
      values = [.english: "Recovery & Diagnostics", .turkish: "Kurtarma ve Tanılama"]
    case "recovery.refresh":
      values = [.english: "Refresh health and permissions", .turkish: "Sağlık ve izinleri yenile"]
    case "recovery.support":
      values = [
        .english: "Support bundles are not enabled in this R9 slice",
        .turkish: "Destek paketleri bu R9 diliminde etkin değil",
      ]
    case "onboarding.title": values = [.english: "AURA setup", .turkish: "AURA kurulumu"]
    case "onboarding.next": values = [.english: "Continue", .turkish: "Devam et"]
    case "onboarding.skip":
      values = [.english: "Skip optional step", .turkish: "İsteğe bağlı adımı geç"]
    case "onboarding.close": values = [.english: "Close setup", .turkish: "Kurulumu kapat"]
    case "onboarding.stage.0":
      values = [.english: "Privacy and local processing", .turkish: "Gizlilik ve yerel işleme"]
    case "onboarding.stage.1":
      values = [.english: "Compatibility and health", .turkish: "Uyumluluk ve sağlık"]
    case "onboarding.stage.2":
      values = [
        .english: "Microphone and Speech Recognition permission",
        .turkish: "Mikrofon ve Konuşma Tanıma izni",
      ]
    case "onboarding.stage.3":
      values = [.english: "Microphone and STT test", .turkish: "Mikrofon ve STT testi"]
    case "onboarding.stage.4":
      values = [.english: "System voice test", .turkish: "Sistem sesi testi"]
    case "onboarding.stage.5":
      values = [.english: "Wake word (optional)", .turkish: "Uyandırma sözcüğü (isteğe bağlı)"]
    case "onboarding.stage.6":
      values = [
        .english: "Accessibility and Screen Recording (optional)",
        .turkish: "Erişilebilirlik ve Ekran Kaydı (isteğe bağlı)",
      ]
    case "onboarding.stage.7":
      values = [.english: "Local model readiness", .turkish: "Yerel model hazırlığı"]
    case "onboarding.stage.8":
      values = [
        .english: "Browser, mail, and calendar integrations (optional)",
        .turkish: "Tarayıcı, posta ve takvim entegrasyonları (isteğe bağlı)",
      ]
    case "onboarding.stage.9": values = [.english: "Emergency stop", .turkish: "Acil durdurma"]
    case "onboarding.stage.10":
      values = [.english: "Guided safe command", .turkish: "Güvenli komut rehberi"]
    case "onboarding.stage.11":
      values = [
        .english: "Launch at login (owned by R11)", .turkish: "Girişte başlatma (R11 kapsamı)",
      ]
    case "onboarding.stage.12":
      values = [.english: "Setup complete", .turkish: "Kurulum tamamlandı"]
    default: values = [.english: key, .turkish: key]
    }
    return values[language] ?? values[.english] ?? key
  }
}
