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
  /// Whether the row's blocking state is a configuration gate that a Settings
  /// control can lift (a disabled-but-composable leg, a mail adapter that
  /// needs an approved account).
  let canEnableInConfiguration: Bool
  /// Whether the row is blocked by a macOS privacy decision that only System
  /// Settings can change (TCC denied/restricted, or an expired screen
  /// observation). The button opens the exact pane.
  let canOpenSystemSettings: Bool
  /// Deep link for `canOpenSystemSettings`, or `nil`.
  let systemSettingsAnchor: String?
  /// Whether the stored credential exists but needs a fresh authorization
  /// (an expired/revoked Gmail token).
  let canReconnect: Bool
  /// Whether the row should show the inline mail-account approval field (a
  /// mail row with no approved account yet — the old remediation text was a
  /// dead end because no Setup surface existed).
  let needsMailApproval: Bool
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
    "a11y.tracePrefix": [.english: "Trace", .turkish: "İz"],
    "a11y.diagnosticPrefix": [.english: "Diagnostic", .turkish: "Tanılama"],
    "a11y.correctedMemory": [
      .english: "Corrected memory statement", .turkish: "Düzeltilmiş bellek ifadesi",
    ],
    "a11y.vscodeRead": [
      .english: "Read VS Code editor state", .turkish: "VS Code düzenleyici durumunu oku",
    ],
    "a11y.vscodeReadHint": [
      .english: "Performs a read-only, policy-authorized live bridge check",
      .turkish: "Salt okunur, politikaca yetkilendirilmiş canlı köprü denetimi yapar",
    ],
    "a11y.memorySearch": [
      .english: "Search inspectable memory", .turkish: "İncelenebilir bellekte ara",
    ],
    "a11y.deletionReceipt": [
      .english: "Memory deletion receipt", .turkish: "Bellek silme makbuzu",
    ],
    "a11y.receiptRecord": [.english: "Record", .turkish: "Kayıt"],
    "a11y.receiptClass": [.english: "class", .turkish: "sınıf"],
    "a11y.receiptReason": [.english: "reason", .turkish: "gerekçe"],
    "a11y.receiptDeletedAt": [.english: "deleted at", .turkish: "silinme zamanı"],
    "a11y.statusPrefix": [.english: "AURA status", .turkish: "AURA durumu"],
    // The confirmation card is where the user authorizes a real, side-effecting
    // action. It is the same class of surface as the emergency control, so it
    // gets the same treatment: every word the user reads before consenting.
    "confirmation.title": [.english: "Confirmation Required", .turkish: "Onay Gerekli"],
    "confirmation.deny": [.english: "Deny", .turkish: "Reddet"],
    "confirmation.allowOnce": [.english: "Allow Once", .turkish: "Bir Kez İzin Ver"],
    // Deliberately identical: "risk" is the ordinary Turkish word, a loanword
    // with no distinct native equivalent in this register. It is excluded from
    // the differs-between-languages assertion for that reason, not by oversight.
    "confirmation.riskPrefix": [.english: "Risk", .turkish: "Risk"],
    "confirmation.expires": [.english: "Expires", .turkish: "Bitiş"],
    "action.cancel": [.english: "Cancel", .turkish: "İptal"],
    "memory.saveCorrection": [
      .english: "Save correction", .turkish: "Düzeltmeyi kaydet",
    ],
    "message.degraded": [.english: "Degraded response", .turkish: "Kısıtlı yanıt"],
    "emergency.group": [.english: "Emergency control", .turkish: "Acil durum kontrolü"],
    "emergency.stop": [.english: "Emergency Stop", .turkish: "Acil Durdurma"],
    "emergency.stopHint": [
      .english: "Immediately disables generated input",
      .turkish: "Üretilen girdiyi anında devre dışı bırakır",
    ],
    "emergency.rearm": [
      .english: "Re-arm generated input", .turkish: "Üretilen girdiyi yeniden etkinleştir",
    ],
    "emergency.rearmHint": [
      .english: "Allows generated mouse and keyboard input again",
      .turkish: "Üretilen fare ve klavye girdisine yeniden izin verir",
    ],
    // --- Permission surface (F-005, third instance) -------------------------
    "perm.group": [.english: "Permissions", .turkish: "İzinler"],
    "perm.indicators": [.english: "Permission indicators", .turkish: "İzin göstergeleri"],
    "perm.microphone": [.english: "Microphone", .turkish: "Mikrofon"],
    "perm.speechRecognition": [.english: "Speech Recognition", .turkish: "Konuşma Tanıma"],
    "perm.activeSpeechRecognition": [
      .english: "Active speech recognition", .turkish: "Etkin konuşma tanıma",
    ],
    "perm.accessibility": [.english: "Accessibility", .turkish: "Erişilebilirlik"],
    "perm.screenRecording": [.english: "Screen Recording", .turkish: "Ekran Kaydı"],
    "perm.screenObservation": [.english: "Screen observation", .turkish: "Ekran gözlemi"],
    "perm.openPrivacySettings": [
      .english: "Open macOS Privacy Settings", .turkish: "macOS Gizlilik Ayarlarını aç",
    ],
    "perm.granted": [.english: "Granted", .turkish: "Verildi"],
    "perm.denied": [.english: "Denied", .turkish: "Reddedildi"],
    "perm.notRequested": [.english: "Not requested", .turkish: "İstenmedi"],
    "perm.restricted": [.english: "Restricted", .turkish: "Kısıtlı"],
    "perm.unavailable": [.english: "Unavailable", .turkish: "Kullanılamıyor"],
    // --- Capability / model inspection --------------------------------------
    "tasks.failed": [.english: "Failed", .turkish: "Başarısız"],
    "capabilities.confirmationRisk": [.english: "Confirmation / risk", .turkish: "Onay / risk"],
    "capabilities.none": [
      .english: "No registered capabilities are available to inspect.",
      .turkish: "İncelenebilecek kayıtlı yetenek yok.",
    ],
    "models.voice": [.english: "Voice", .turkish: "Ses"],
    "models.speechRecognition": [.english: "Speech recognition", .turkish: "Konuşma tanıma"],
    "models.systemTTS": [
      .english: "System speech synthesis: configured local pipeline",
      .turkish: "Sistem konuşma sentezi: yapılandırılmış yerel hat",
    ],
    "models.state": [.english: "State", .turkish: "Durum"],
    "models.authentication": [.english: "Authentication", .turkish: "Kimlik doğrulama"],
    "models.availability": [
      .english: "Model availability", .turkish: "Model kullanılabilirliği",
    ],
    // --- Memory inspection and controls -------------------------------------
    "memory.preferenceProfile": [
      .english: "Memory preference profile", .turkish: "Bellek tercih profili",
    ],
    "memory.preferenceNote": [
      .english: "This is a bounded user preference, not an execution grant.",
      .turkish: "Bu, sınırlı bir kullanıcı tercihidir; yürütme izni değildir.",
    ],
    "memory.savePreference": [.english: "Save preference", .turkish: "Tercihi kaydet"],
    "memory.clearPreference": [
      .english: "Clear saved preference", .turkish: "Kayıtlı tercihi temizle",
    ],
    "memory.controls": [.english: "Memory controls", .turkish: "Bellek denetimleri"],
    "memory.visibleOf": [.english: "visible of", .turkish: "görünür /"],
    "memory.records": [.english: "records", .turkish: "kayıt"],
    "memory.runRetention": [
      .english: "Run retention cleanup", .turkish: "Saklama temizliğini çalıştır",
    ],
    "memory.receiptGone": [
      .english: "The record content is gone; only this receipt and the audit event remain.",
      .turkish: "Kayıt içeriği silindi; yalnızca bu makbuz ve denetim olayı kalır.",
    ],
    "memory.conflicts": [
      .english: "Unresolved and resolved conflicts",
      .turkish: "Çözülmemiş ve çözülmüş çakışmalar",
    ],
    "memory.previous": [.english: "Previous", .turkish: "Önceki"],
    "memory.new": [.english: "New", .turkish: "Yeni"],
    "memory.keepPrevious": [.english: "Keep previous", .turkish: "Öncekini koru"],
    "memory.keepNew": [.english: "Keep new", .turkish: "Yeniyi koru"],
    "memory.searchPlaceholder": [.english: "Search memory", .turkish: "Bellekte ara"],
    // Capitalized variants of the lowercase `a11y.receipt*` keys, which are
    // composed mid-sentence in the VoiceOver label and cannot be reused as
    // sentence-initial visible labels.
    "memory.reasonLabel": [.english: "Reason", .turkish: "Gerekçe"],
    "memory.deletedAtLabel": [.english: "Deleted at", .turkish: "Silinme zamanı"],
    "memory.purpose": [.english: "Purpose", .turkish: "Amaç"],
    "memory.provenance": [.english: "Provenance", .turkish: "Köken"],
    "memory.confidence": [.english: "Confidence", .turkish: "Güven"],
    "memory.sensitivity": [.english: "Sensitivity", .turkish: "Duyarlılık"],
    "memory.retention": [.english: "Retention", .turkish: "Saklama"],
    "memory.scope": [.english: "Scope", .turkish: "Kapsam"],
    "memory.global": [.english: "global", .turkish: "genel"],
    "memory.correctShort": [.english: "Correct", .turkish: "Düzelt"],
    "memory.deleteShort": [.english: "Delete", .turkish: "Sil"],
    "memory.immutable": [
      .english: "Audit/security records are not user-mutable.",
      .turkish: "Denetim/güvenlik kayıtları kullanıcı tarafından değiştirilemez.",
    ],
    // --- Recovery / diagnostics ---------------------------------------------
    "recovery.diagnostics": [
      .english: "Runtime diagnostics", .turkish: "Çalışma zamanı tanılamaları",
    ],
    "recovery.localTuning": [
      .english: "Local tuning recommendations", .turkish: "Yerel ayar önerileri",
    ],
    // --- VS Code bridge / plan ----------------------------------------------
    "vscode.bridge": [.english: "VS Code live bridge", .turkish: "VS Code canlı köprüsü"],
    "vscode.probeNote": [
      .english: "Read-only probe through the authenticated AURA extension bridge.",
      .turkish: "Kimliği doğrulanmış AURA uzantı köprüsü üzerinden salt okunur sonda.",
    ],
    "plan.title": [.english: "Plan / Verification", .turkish: "Plan / Doğrulama"],
    // --- Settings window ----------------------------------------------------
    "settings.productUI": [.english: "Product UI", .turkish: "Ürün arayüzü"],
    "settings.language": [.english: "Language", .turkish: "Dil"],
    "settings.openGuidedSetup": [
      .english: "Open guided setup", .turkish: "Rehberli kurulumu aç",
    ],
    "settings.activation": [.english: "Activation", .turkish: "Etkinleştirme"],
    "settings.noWakeModel": [
      .english: "A trained acoustic wake-word model is not installed.",
      .turkish: "Eğitilmiş akustik uyandırma sözcüğü modeli kurulu değil.",
    ],
    "settings.requestMicSpeech": [
      .english: "Request Microphone and Speech Access",
      .turkish: "Mikrofon ve Konuşma erişimi iste",
    ],
    "settings.systemPermissions": [
      .english: "System Permissions", .turkish: "Sistem İzinleri",
    ],
    "settings.requestAccessibility": [
      .english: "Request Accessibility Access", .turkish: "Erişilebilirlik erişimi iste",
    ],
    "settings.requestScreenRecording": [
      .english: "Request Screen Recording Access", .turkish: "Ekran Kaydı erişimi iste",
    ],
    "settings.openMicSettings": [
      .english: "Open Microphone Settings", .turkish: "Mikrofon Ayarlarını aç",
    ],
    "settings.openSpeechSettings": [
      .english: "Open Speech Recognition Settings", .turkish: "Konuşma Tanıma Ayarlarını aç",
    ],
    "settings.openAccessibilitySettings": [
      .english: "Open Accessibility Settings", .turkish: "Erişilebilirlik Ayarlarını aç",
    ],
    "settings.openScreenRecordingSettings": [
      .english: "Open Screen Recording Settings", .turkish: "Ekran Kaydı Ayarlarını aç",
    ],
    "settings.refreshPermissions": [
      .english: "Refresh Permission Status", .turkish: "İzin durumunu yenile",
    ],
    "settings.vscodeBridge": [.english: "VS Code Bridge", .turkish: "VS Code Köprüsü"],
    "settings.bridgeSecretNote": [
      .english: "Local authenticated bridge; the shared secret stays in AURA Keychain "
        + "and VS Code SecretStorage.",
      .turkish: "Yerel kimlik doğrulamalı köprü; paylaşılan gizli anahtar AURA Anahtar "
        + "Zinciri'nde ve VS Code SecretStorage'da kalır.",
    ],
    "settings.extensionID": [.english: "Extension ID", .turkish: "Uzantı kimliği"],
    "settings.sharedSecret": [
      .english: "Shared secret (16+ characters)",
      .turkish: "Paylaşılan gizli anahtar (16+ karakter)",
    ],
    "settings.provision": [.english: "Provision in AURA", .turkish: "AURA'da sağla"],
    "settings.revoke": [.english: "Revoke", .turkish: "İptal et"],
    "settings.auraKeychain": [.english: "AURA Keychain", .turkish: "AURA Anahtar Zinciri"],
    "settings.provisioned": [.english: "Provisioned", .turkish: "Sağlandı"],
    "settings.notProvisioned": [.english: "Not provisioned", .turkish: "Sağlanmadı"],
    "settings.bridgeDisabled": [
      .english: "The SP-012 live bridge profile is not enabled.",
      .turkish: "SP-012 canlı köprü profili etkin değil.",
    ],
    "settings.startup": [.english: "Startup", .turkish: "Başlangıç"],
    "settings.launchAtLogin": [
      .english: "Launch AURA at login", .turkish: "Girişte AURA'yı başlat",
    ],
    "settings.launchAtLoginNote": [
      .english: "Registers AURA with macOS Login Items via ServiceManagement.",
      .turkish: "AURA'yı ServiceManagement ile macOS Giriş Ögeleri'ne kaydeder.",
    ],
    "recovery.latency": [
      .english: "Observed latency (this session)", .turkish: "Gözlenen gecikme (bu oturum)",
    ],
    "recovery.latencyNone": [
      .english: "No latency samples yet. Take a turn to populate this.",
      .turkish: "Henüz gecikme örneği yok. Doldurmak için bir tur yapın.",
    ],
    "recovery.latencyRefresh": [
      .english: "Refresh latency readout", .turkish: "Gecikme okumasını yenile",
    ],
    "recovery.samples": [.english: "samples", .turkish: "örnek"],
    "recovery.mockDerived": [
      .english: "mock-derived — not a live measurement",
      .turkish: "sahte motordan — canlı ölçüm değil",
    ],
    "settings.privacy": [.english: "Privacy", .turkish: "Gizlilik"],
    "settings.onDeviceNote": [
      .english: "Speech recognition and system speech synthesis remain on device.",
      .turkish: "Konuşma tanıma ve sistem konuşma sentezi cihazda kalır.",
    ],
    "settings.pluginIsolation": [
      .english: "Plugin execution remains isolated in the verified helper process.",
      .turkish: "Eklenti yürütmesi doğrulanmış yardımcı süreçte yalıtılmış kalır.",
    ],
    "settings.configGovernance": [
      .english: "Configuration Governance", .turkish: "Yapılandırma Yönetişimi",
    ],
    "settings.aggregateNote": [
      .english: "Uses bounded aggregate metrics only. Recommendations are never applied "
        + "automatically.",
      .turkish: "Yalnızca sınırlı toplu ölçümler kullanır. Öneriler asla otomatik uygulanmaz.",
    ],
    "settings.effectiveKeys": [.english: "Effective keys", .turkish: "Etkin anahtarlar"],
    "settings.auditRecords": [.english: "Audit records", .turkish: "Denetim kayıtları"],
    "settings.refreshConfig": [
      .english: "Refresh Configuration Inspection",
      .turkish: "Yapılandırma incelemesini yenile",
    ],
    "tasks.title": [.english: "Task Center", .turkish: "Görev Merkezi"],
    "tasks.empty": [
      .english: "No durable tasks are currently tracked.",
      .turkish: "Şu anda izlenen kalıcı görev yok.",
    ],
    "tasks.cancel": [.english: "Cancel task", .turkish: "Görevi iptal et"],
    "tasks.pause": [.english: "Pause", .turkish: "Duraklat"],
    "tasks.resume": [.english: "Resume", .turkish: "Sürdür"],
    "tasks.retry": [.english: "Retry", .turkish: "Tekrar dene"],
    "tasks.backend": [.english: "Backend", .turkish: "Arka uç"],
    "tasks.mode": [.english: "Mode", .turkish: "Mod"],
    "tasks.health": [.english: "Health", .turkish: "Sağlık"],
    "tasks.workspace": [.english: "Workspace", .turkish: "Çalışma alanı"],
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
    "capabilities.noEvidence": [
      .english: "No availability evidence is registered",
      .turkish: "Kayıtlı kullanılabilirlik kanıtı yok",
    ],
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
      .english: "Connect Chrome", .turkish: "Chrome'u bağla",
    ],
    "integrations.grantAccess": [
      .english: "Grant access", .turkish: "Erişim izni ver",
    ],
    "integrations.enableInConfiguration": [
      .english: "Enable in configuration", .turkish: "Yapılandırmada etkinleştir",
    ],
    "integrations.systemSettings": [
      .english: "Open System Settings", .turkish: "Sistem Ayarlarını aç",
    ],
    "integrations.retry": [
      .english: "Retry", .turkish: "Yeniden dene",
    ],
    "integrations.reconnectGmail": [
      .english: "Reconnect Gmail", .turkish: "Gmail'i yeniden bağla",
    ],
    "integrations.mailApprovalPlaceholder": [
      .english: "Approve a Gmail address for read-only access",
      .turkish: "Salt-okunur erişim için bir Gmail adresi onaylayın",
    ],
    "integrations.approveAndConnect": [
      .english: "Approve and connect", .turkish: "Onayla ve bağla",
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

  /// Every key in the table, for the coverage guard in `AURAIntegrationTests`.
  /// Exposed so the guard cannot drift out of step with the table by hand-listing
  /// keys — a hand-maintained list is exactly what let earlier gaps survive.
  static var allKeys: [String] { translations.keys.sorted() }

  static func text(_ key: String, language: AuraUILanguage) -> String {
    let values = translations[key] ?? [.english: key, .turkish: key]
    return values[language] ?? values[.english] ?? key
  }
}
