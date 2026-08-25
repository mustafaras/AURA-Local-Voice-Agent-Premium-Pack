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
  let traceSummary: String?

  init(
    id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date(),
    isDegraded: Bool = false, sourceSummary: String? = nil, traceSummary: String? = nil
  ) {
    self.id = id
    self.role = role
    self.text = text
    self.timestamp = timestamp
    self.isDegraded = isDegraded
    self.sourceSummary = sourceSummary
    self.traceSummary = traceSummary
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

/// One read-first integration as the user sees it.
///
/// `accountLabel` is deliberately the masked form produced by
/// `ProductivityRedaction.displayLabel`. This row can end up in a screenshot,
/// a screen recording, or a support conversation, and none of those need a
/// full address to tell two accounts apart.
struct AuraIntegrationRow: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let state: String
  let detail: String
  /// The next concrete user action; empty when the integration is ready.
  let remediation: String
  /// Masked account or profile label, or `nil` when nothing is connected.
  let accountLabel: String?
  let isReady: Bool
  let isRevocable: Bool
  /// Whether the user can start the provider's in-app authorization flow.
  let canConnect: Bool
  /// Whether the user can trigger this leg's macOS permission prompt from
  /// here. False once macOS has recorded a decision — then the remediation
  /// points at System Settings, which is the only place left to change it.
  let canGrantAccess: Bool
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
  let retention: MemoryRetentionPolicy
  let scope: MemoryScope
  let supersedes: UUID?

  init(
    id: UUID,
    memoryClass: String,
    subject: String,
    statement: String,
    purpose: String,
    provenance: String,
    confidence: Double,
    sensitivity: String,
    createdAt: Date,
    canMutate: Bool,
    retention: MemoryRetentionPolicy = .indefinite,
    scope: MemoryScope = .global,
    supersedes: UUID? = nil
  ) {
    self.id = id
    self.memoryClass = memoryClass
    self.subject = subject
    self.statement = statement
    self.purpose = purpose
    self.provenance = provenance
    self.confidence = confidence
    self.sensitivity = sensitivity
    self.createdAt = createdAt
    self.canMutate = canMutate
    self.retention = retention
    self.scope = scope
    self.supersedes = supersedes
  }
}

struct AuraMemoryConflictRow: Identifiable, Equatable, Sendable {
  let id: UUID
  let subject: String
  let existingRecordID: UUID
  let newRecordID: UUID
  let existingStatement: String
  let newStatement: String
  let detectedAt: Date
  let resolution: MemoryConflictResolution?

  var resolutionSummary: String {
    switch resolution {
    case nil: return "Unresolved"
    case .supersededExisting: return "New statement marked as superseding the previous one"
    case .keptExisting: return "Previous statement retained"
    case .bothRetained: return "Both statements retained"
    }
  }
}

/// User-visible proof that a memory record was permanently deleted.
///
/// `MemoryEngine.deleteRecord` already returns a `MemoryDeletionReceipt`, but
/// before SP-019 the kernel discarded it and the Privacy tab showed only a
/// transient sentence. A deletion the user cannot verify afterwards is not an
/// inspectable control, so the receipt is projected here and held until the
/// next deletion replaces it. It deliberately carries no deleted content —
/// only the record identity, class, reason, and time — because a receipt that
/// preserved the statement would relocate the data instead of removing it.
struct AuraMemoryDeletionReceiptRow: Identifiable, Equatable, Sendable {
  let id: UUID
  let memoryClass: String
  let reason: String
  let deletedAt: Date

  init(receipt: MemoryDeletionReceipt) {
    self.id = receipt.recordID
    self.memoryClass = receipt.memoryClass.rawValue
    self.reason = receipt.reason
    self.deletedAt = receipt.deletedAt
  }
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
  private static let translations: [String: [AuraUILanguage: String]] = [
    "app.name": [.english: "AURA", .turkish: "AURA"],
    "tab.conversation": [.english: "Conversation", .turkish: "Konuşma"],
    "tab.tasks": [.english: "Tasks", .turkish: "Görevler"],
    "tab.capabilities": [.english: "Capabilities", .turkish: "Yetenekler"],
    "tab.models": [.english: "Models & Voice", .turkish: "Modeller ve Ses"],
    "tab.privacy": [.english: "Privacy & Memory", .turkish: "Gizlilik ve Bellek"],
    "tab.recovery": [.english: "Recovery", .turkish: "Kurtarma"],
    "conversation.title": [.english: "Conversation", .turkish: "Konuşma"],
    "conversation.input": [.english: "Type a request", .turkish: "Bir istek yazın"],
    "conversation.submit": [.english: "Submit typed request", .turkish: "Yazılı isteği gönder"],
    "conversation.pushToTalk": [.english: "Push to Talk", .turkish: "Bas Konuş"],
    "conversation.pushHint": [
      .english: "Starts one local speech-recognition turn",
      .turkish: "Tek bir yerel konuşma tanıma turu başlatır",
    ],
    "conversation.partial": [.english: "Live partial transcript", .turkish: "Canlı kısmi döküm"],
    "conversation.empty": [
      .english: "Your conversation will appear here.", .turkish: "Konuşmanız burada görünecek.",
    ],
    "conversation.local": [.english: "Local processing", .turkish: "Yerel işleme"],
    "conversation.cloudDisabled": [
      .english: "Cloud context is disabled by machine policy",
      .turkish: "Bulut bağlamı makine politikasıyla devre dışı",
    ],
    "tasks.title": [.english: "Task Center", .turkish: "Görev Merkezi"],
    "tasks.empty": [
      .english: "No durable tasks are currently tracked.",
      .turkish: "Şu anda izlenen kalıcı görev yok.",
    ],
    "tasks.cancel": [.english: "Cancel task", .turkish: "Görevi iptal et"],
    "tasks.progress": [.english: "Progress", .turkish: "İlerleme"],
    "capabilities.title": [
      .english: "Capability & Permission Center", .turkish: "Yetenek ve İzin Merkezi",
    ],
    "capabilities.refresh": [
      .english: "Refresh capability status", .turkish: "Yetenek durumunu yenile",
    ],
    "capabilities.disabled": [.english: "Disabled", .turkish: "Devre dışı"],
    "capabilities.ready": [.english: "Ready", .turkish: "Hazır"],
    "capabilities.degraded": [.english: "Degraded", .turkish: "Kısıtlı"],
    "models.title": [.english: "Model & Voice Center", .turkish: "Model ve Ses Merkezi"],
    "models.refresh": [.english: "Refresh model health", .turkish: "Model sağlığını yenile"],
    "models.local": [.english: "Local", .turkish: "Yerel"],
    "models.unverified": [
      .english: "Authentication and model availability are unverified",
      .turkish: "Kimlik doğrulama ve model kullanılabilirliği doğrulanmadı",
    ],
    "privacy.title": [
      .english: "Privacy, Memory & Integrations", .turkish: "Gizlilik, Bellek ve Entegrasyonlar",
    ],
    "privacy.export": [
      .english: "Export non-audit memory", .turkish: "Denetim dışı belleği dışa aktar",
    ],
    "privacy.delete": [.english: "Delete memory", .turkish: "Belleği sil"],
    "privacy.correct": [.english: "Correct memory", .turkish: "Belleği düzelt"],
    "privacy.noMemory": [
      .english: "No user-inspectable memory records.",
      .turkish: "Kullanıcının inceleyebileceği bellek kaydı yok.",
    ],
    "integrations.title": [
      .english: "Read-only integrations", .turkish: "Salt okunur entegrasyonlar",
    ],
    "integrations.connected": [.english: "Connected", .turkish: "Bağlı"],
    "integrations.notConnected": [.english: "Not connected", .turkish: "Bağlı değil"],
    "integrations.action": [.english: "Next step", .turkish: "Sonraki adım"],
    "integrations.revoke": [.english: "Disconnect", .turkish: "Bağlantıyı kes"],
    "integrations.connect": [.english: "Connect Gmail", .turkish: "Gmail'i bağla"],
    "integrations.connectBrowser": [
      .english: "Connect Safari profile", .turkish: "Safari profilini bağla",
    ],
    "integrations.grantAccess": [
      .english: "Grant access", .turkish: "Erişim izni ver",
    ],
    "integrations.readOnly": [
      .english: "AURA reads only. Sending mail and changing events or contacts are not enabled.",
      .turkish:
        "AURA yalnızca okur. Posta gönderme ve etkinlik veya kişi değiştirme etkin değildir.",
    ],
    "integrations.none": [
      .english: "No read-only integration is composed in this build.",
      .turkish: "Bu sürümde yapılandırılmış salt okunur entegrasyon yok.",
    ],
    "recovery.title": [.english: "Recovery & Diagnostics", .turkish: "Kurtarma ve Tanılama"],
    "recovery.refresh": [
      .english: "Refresh health and permissions", .turkish: "Sağlık ve izinleri yenile",
    ],
    "recovery.support": [
      .english: "Support bundles are not enabled in this R9 slice",
      .turkish: "Destek paketleri bu R9 diliminde etkin değil",
    ],
    "onboarding.title": [.english: "AURA setup", .turkish: "AURA kurulumu"],
    "onboarding.next": [.english: "Continue", .turkish: "Devam et"],
    "onboarding.skip": [.english: "Skip optional step", .turkish: "İsteğe bağlı adımı geç"],
    "onboarding.close": [.english: "Close setup", .turkish: "Kurulumu kapat"],
    "onboarding.stage.0": [
      .english: "Privacy and local processing", .turkish: "Gizlilik ve yerel işleme",
    ],
    "onboarding.stage.1": [
      .english: "Compatibility and health", .turkish: "Uyumluluk ve sağlık",
    ],
    "onboarding.stage.2": [
      .english: "Microphone and Speech Recognition permission",
      .turkish: "Mikrofon ve Konuşma Tanıma izni",
    ],
    "onboarding.stage.3": [
      .english: "Microphone and STT test", .turkish: "Mikrofon ve STT testi",
    ],
    "onboarding.stage.4": [.english: "System voice test", .turkish: "Sistem sesi testi"],
    "onboarding.stage.5": [
      .english: "Wake word (optional)", .turkish: "Uyandırma sözcüğü (isteğe bağlı)",
    ],
    "onboarding.stage.6": [
      .english: "Accessibility and Screen Recording (optional)",
      .turkish: "Erişilebilirlik ve Ekran Kaydı (isteğe bağlı)",
    ],
    "onboarding.stage.7": [
      .english: "Local model readiness", .turkish: "Yerel model hazırlığı",
    ],
    "onboarding.stage.8": [
      .english: "Browser, mail, and calendar integrations (optional)",
      .turkish: "Tarayıcı, posta ve takvim entegrasyonları (isteğe bağlı)",
    ],
    "onboarding.stage.9": [.english: "Emergency stop", .turkish: "Acil durdurma"],
    "onboarding.stage.10": [
      .english: "Guided safe command", .turkish: "Güvenli komut rehberi",
    ],
    "onboarding.stage.11": [
      .english: "Launch at login (owned by R11)", .turkish: "Girişte başlatma (R11 kapsamı)",
    ],
    "onboarding.stage.12": [.english: "Setup complete", .turkish: "Kurulum tamamlandı"],
  ]

  static func text(_ key: String, language: AuraUILanguage) -> String {
    let values = translations[key] ?? [.english: key, .turkish: key]
    return values[language] ?? values[.english] ?? key
  }
}
