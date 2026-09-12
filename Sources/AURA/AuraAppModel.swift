import AppKit
import AuraAgent
import AuraAudio
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

  /// Launch-at-login state, mirrored from the lifecycle controller. The
  /// capability was implemented in SP-028 and wired into the kernel, but had
  /// no user-reachable control until 2026-08-30 — a feature nobody can turn on
  /// is not shipped, and the R11 gate asks for a live enable/disable.
  @Published var launchAtLoginEnabled = false
  @Published var launchAtLoginDetail = ""
  /// Guards against a double-fire of `setLaunchAtLogin`. Found live 2026-09-01:
  /// the Settings `Toggle`'s inline `Binding(get:set:)` re-invoked `set` a
  /// second time before `launchAtLoginEnabled` had caught up (it only updates
  /// after an async kernel round trip), and the second call's
  /// `awaitConfirmation` immediately superseded — denied — the first one's
  /// still-pending challenge before the confirmation card ever rendered. The
  /// user saw "was not confirmed" instantly, with no card visible at all.
  var isSettingLaunchAtLogin = false
  /// Latency percentiles (p50/p95/p99) observed in this process, for the
  /// Recovery tab readout. Empty until a real turn has been taken.
  @Published var latencySummaries: [LatencyPercentileSummary] = []
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
  /// ADR-055: mirrors `configuration.ollama.allowCloudModels` — the machine
  /// policy bound that decides whether the cloud-context banner claims the
  /// machine policy or the user preference is what keeps local-only on.
  @Published var isCloudContextPolicyAllowed = false

  /// The cloud-context status label resolved against the live machine policy
  /// and the user preference, so the UI never shows a stale static claim.
  var cloudContextStatusLabel: String {
    if !isCloudContextPolicyAllowed {
      return AuraCopy.text("conversation.cloudDisabled", language: productUIState.language)
    }
    if memoryPreferenceProfile.localOnly {
      return AuraCopy.text(
        "conversation.cloudPreferenceOff", language: productUIState.language)
    }
    return AuraCopy.text("conversation.cloudAvailable", language: productUIState.language)
  }
  @Published var conversationMessages: [AuraConversationMessage] = []
  @Published var partialTranscript = ""
  /// Scalar mic level for display (0…1) while listening; `nil` whenever the
  /// assistant is not listening (honest idle). Published by
  /// `AudioLevelBridge` — a scalar only: no sample data, no history, no
  /// persistence, no logging (06-cross-cutting-constraints.md §6). UI-1 rule:
  /// render transform-only from this value, never `withAnimation` on it
  /// (11-motion-system.md §5).
  @Published var inputLevel: Double?
  @Published var lastOperationMessage = ""
  @Published var productUIState = AuraProductUIState()
  @Published var memoryCorrectionTarget: AuraMemoryRow?
  /// Receipt for the most recent permanent memory deletion, retained so the
  /// user can verify the deletion after the transient status line is gone.
  @Published var lastMemoryDeletionReceipt: AuraMemoryDeletionReceiptRow?
  /// The address being typed into the mail row's inline approval field.
  /// Transient user input only; never persisted or logged.
  @Published var mailApprovalAddress = ""

  let confirmationPresenter = UIConfirmationPresenter()
  let emergencyShortcutMonitor = EmergencyShortcutMonitor()
  /// UI level meter for the listening state (UI-1 G1-1). Owned by the app
  /// model; subscribed by `bootstrap()`, driven by the model's own status
  /// transitions so `inputLevel` and the status pill can never disagree.
  let levelBridge: AudioLevelBridge
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
    // Conversation FSM mirroring (`applyConversationState`) falls back to the
    // bare English status title whenever the underlying transition reason is
    // an internal diagnostic key, not user-facing copy. Route that through
    // the same status-title translation the pill above already uses, so the
    // detail line never shows the untranslated English word.
    if detail == status.title(for: .english) {
      return status.title(for: .turkish)
    }
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
    // The level bridge needs a bus to observe; the model constructs it on the
    // shared bus with a placeholder capture actor, and `bootstrap()` reattaches
    // it to the kernel's real capture actor + bus before subscribing.
    let bridge = AudioLevelBridge(
      audio: AuraAudio(
        configuration: AudioConfiguration(), eventBus: .shared,
        logger: AuraLogger(subsystem: "AURA", category: "audio")),
      eventBus: .shared)
    self.levelBridge = bridge
    bridge.onLevelChange = { [weak self] level in
      MainActor.assumeIsolated {
        self?.inputLevel = level
      }
    }
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
      productUIState.soundFeedbackEnabled = savedState.soundFeedbackEnabled
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
