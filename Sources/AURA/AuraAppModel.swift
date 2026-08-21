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

  var title: String {
    rawValue.capitalized
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
  @Published var conversationMessages: [AuraConversationMessage] = []
  @Published var partialTranscript = ""
  @Published var lastPlanSummary: String?
  @Published var lastOperationMessage = ""
  @Published var productUIState = AuraProductUIState()
  @Published var memoryCorrectionTarget: AuraMemoryRow?

  let confirmationPresenter = UIConfirmationPresenter()
  let emergencyShortcutMonitor = EmergencyShortcutMonitor()
  var confirmationContinuation: CheckedContinuation<Bool, Never>?
  var kernel: AuraKernel?
  var eventBus: AuraEventBus?
  var bootTask: Task<Void, Never>?

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
