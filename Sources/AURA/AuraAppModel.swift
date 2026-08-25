import AppKit
import AuraAgent
import AuraConfig
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation

enum AuraAppStatus: String, Sendable {
  case starting
  case restricted
  case idle
  case listening
  case thinking
  case speaking
  case stopped
  case error

  /// Localized short title for the status pill, so the live state is
  /// understandable in the selected UI language, not only English.
  func title(for language: AuraUILanguage) -> String {
    switch self {
    case .starting: return language == .turkish ? "Başlatılıyor" : "Starting"
    case .restricted: return language == .turkish ? "Kısıtlı" : "Restricted"
    case .idle: return language == .turkish ? "Boşta" : "Idle"
    case .listening: return language == .turkish ? "Dinleniyor" : "Listening"
    case .thinking: return language == .turkish ? "Düşünülüyor" : "Thinking"
    case .speaking: return language == .turkish ? "Konuşuluyor" : "Speaking"
    case .stopped: return language == .turkish ? "Durduruldu" : "Stopped"
    case .error: return language == .turkish ? "Hata" : "Error"
    }
  }

  var symbolName: String {
    switch self {
    case .starting: "hourglass"
    case .restricted: "lock.trianglebadge.exclamationmark"
    case .idle: "waveform"
    case .listening: "mic.fill"
    case .thinking: "brain"
    case .speaking: "speaker.wave.2.fill"
    case .stopped: "hand.raised.fill"
    case .error: "exclamationmark.triangle.fill"
    }
  }
}

struct AuraTaskSummary: Identifiable, Sendable {
  let id: UUID
  var title: String
  var state: String
}

@MainActor
final class AuraAppModel: ObservableObject {
  @Published var status: AuraAppStatus = .starting
  @Published var statusDetail = "Starting local services"
  @Published var permissions = PermissionCoordinator.snapshot()
  @Published var pendingConfirmation: PolicyConfirmationChallenge?
  @Published var tasks: [AuraTaskSummary] = []
  @Published var emergencyStopActive = false
  @Published var runtimeWarnings: [String] = [
    "Acoustic wake-word model unavailable; use Push to Talk."
  ]
  @Published var runtimeHealth: [RuntimeHealth] = []
  @Published var textInput = ""
  @Published var effectiveConfiguration: [EffectiveConfigurationEntry] = []
  @Published var configurationAuditCount = 0
  @Published var localRecommendationsEnabled = false
  @Published var taskStatuses: [TaskStatus] = []
  @Published var capabilityRows: [AuraCapabilityRow] = []
  @Published var integrationRows: [AuraIntegrationRow] = []
  @Published var backendHealth: [AgentBackendHealth] = []
  /// Transient user input only; never persisted, logged, or rendered back.
  @Published var vscodeBridgeSecret = ""
  @Published var isVSCodeBridgeProvisioned = false
  @Published var vscodeBridgeRoundTripStatus = ""
  @Published var memoryRows: [AuraMemoryRow] = []
  @Published var memoryConflicts: [AuraMemoryConflictRow] = []
  @Published var memorySearchText = ""
  @Published var memoryPreferenceProfile = UserPreferenceProfile()
  @Published var hasSavedMemoryPreference = false
  @Published var conversationMessages: [AuraConversationMessage] = []
  @Published var partialTranscript = ""
  @Published var lastPlanSummary: String?
  @Published var lastOperationMessage = ""
  @Published var productUIState = AuraProductUIState()
  @Published var memoryCorrectionTarget: AuraMemoryRow?
  /// Receipt for the most recent permanent memory deletion, retained so the
  /// user can verify the deletion after the transient status line is gone.
  @Published var lastMemoryDeletionReceipt: AuraMemoryDeletionReceiptRow?

  let confirmationPresenter = UIConfirmationPresenter()
  let emergencyShortcutMonitor = EmergencyShortcutMonitor()
  var confirmationContinuation: CheckedContinuation<Bool, Never>?
  var kernel: AuraKernel?
  var eventBus: AuraEventBus?
  var bootTask: Task<Void, Never>?

  /// Localized rendering of `statusDetail` for the current UI language.
  ///
  /// The status detail is produced by runtime code in English so it stays a
  /// stable internal key. This maps the known set to the selected language so
  /// the live state pill is understandable in Turkish too, matching
  /// `AuraAppStatus.title(for:)`.
  var displayStatusDetail: String {
    let detail = statusDetail
    guard productUIState.language == .turkish else { return detail }
    switch detail {
    case "Starting local services": return "Yerel hizmetler başlatılıyor"
    case "Waiting for voice permissions": return "Ses izinleri bekleniyor"
    case "Ready — use Push to Talk": return "Hazır — Bas Konuş'u kullanın"
    case "Voice permissions are required for speech input":
      return "Sesli giriş için ses izinleri gerekli"
    case "Grant microphone and Speech Recognition access first":
      return "Önce mikrofon ve Konuşma Tanıma erişimi verin"
    case "Listening on device": return "Cihazda dinleniyor"
    case "Processing typed request": return "Yazılı istek işleniyor"
    case "Generated input is disabled until explicitly re-armed":
      return "Üretilen giriş açıkça yeniden etkinleştirilene dek devre dışı"
    case "Voice permissions required": return "Ses izinleri gerekli"
    case "Voice permissions are required before continuing":
      return "Devam etmeden önce ses izinleri gerekli"
    case "Complete voice permission onboarding":
      return "Ses izni kurulumunu tamamlayın"
    case "Emergency stop active": return "Acil durdurma etkin"
    case "Waiting for speech permissions": return "Ses izinleri bekleniyor"
    default: return detail
    }
  }

  init(startRuntime: Bool = true) {
    if let rawLanguage = UserDefaults.standard.string(forKey: "aura.ui.language"),
      let savedLanguage = AuraUILanguage(rawValue: rawLanguage)
    {
      productUIState.language = savedLanguage
    }
    if let data = UserDefaults.standard.data(forKey: "aura.ui.state"),
      let savedState = try? JSONDecoder().decode(AuraProductUIState.self, from: data)
    {
      productUIState.selectedTab = savedState.selectedTab
      productUIState.onboarding = savedState.onboarding
    }
    if startRuntime {
      bootTask = Task { [weak self] in
        guard let self else { return }
        self.emergencyShortcutMonitor.start { [weak self] in
          self?.triggerEmergencyStop()
        }
        await self.configureConfirmationPresenter()
        await self.bootstrap()
      }
    }
  }

}
