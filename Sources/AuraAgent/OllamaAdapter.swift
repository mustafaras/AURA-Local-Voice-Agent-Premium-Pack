import AuraCore
import AuraPolicy
import Foundation

/// The outcome of a single Ollama-routed capability request.
public struct OllamaCapabilityResult: Sendable, Equatable {
  public let text: String
  /// `nil` only when `degraded` is `true` and no model was ever reached.
  public let model: String?
  /// `true` when the result came from a caller-supplied deterministic
  /// fallback rather than real model inference.
  public let degraded: Bool

  public init(text: String, model: String?, degraded: Bool) {
    self.text = text
    self.model = model
    self.degraded = degraded
  }
}

public struct OllamaInferenceContext: Sendable {
  public let actor: ActorID
  public let sessionID: UUID
  public let correlationID: UUID
  public let causationID: UUID

  public init(actor: ActorID, sessionID: UUID, correlationID: UUID, causationID: UUID) {
    self.actor = actor
    self.sessionID = sessionID
    self.correlationID = correlationID
    self.causationID = causationID
  }
}

/// Coordinates capability-routed Ollama inference: health check, thermal and
/// memory-budget gating, model routing, policy gate (local vs. cloud), and —
/// unlike the Codex/Claude/Copilot CLI adapters — a caller-suppliable
/// deterministic fallback for graceful degradation, per
/// `docs/subsystems/20_OLLAMA_CONTROLLER.md`'s "degrade to deterministic
/// rules for simple commands."
///
/// Architecturally distinct from the CLI adapters: this drives a local HTTP
/// API, not a spawned process, so there is no `AdapterProcessExecuting`
/// seam or explicit `cancel(executionID:)` — a caller cancels the enclosing
/// `Task` and the in-flight `URLSession` request is interrupted the normal
/// Swift-concurrency way.
public actor OllamaAdapter {
  let configuration: OllamaConfiguration
  let policyEngine: PolicyEngine
  let approvalPresenter: any OllamaApprovalPresenting
  let apiClient: any OllamaAPIClient
  let registry: OllamaModelRegistry
  let eventBus: AuraEventBus
  let thermalStateProvider: @Sendable () -> ProcessInfo.ThermalState

  public init(
    configuration: OllamaConfiguration,
    policyEngine: PolicyEngine,
    approvalPresenter: any OllamaApprovalPresenting = OllamaAlwaysDenyApprovalPresenter(),
    apiClient: (any OllamaAPIClient)? = nil,
    eventBus: AuraEventBus = .shared,
    thermalStateProvider: @escaping @Sendable () -> ProcessInfo.ThermalState = {
      ProcessInfo.processInfo.thermalState
    }
  ) throws(AuraError) {
    self.configuration = configuration
    self.policyEngine = policyEngine
    self.approvalPresenter = approvalPresenter
    self.eventBus = eventBus
    self.thermalStateProvider = thermalStateProvider
    let resolvedClient: any OllamaAPIClient
    if let apiClient {
      resolvedClient = apiClient
    } else {
      resolvedClient = try URLSessionOllamaAPIClient(configuration: configuration)
    }
    self.apiClient = resolvedClient
    self.registry = OllamaModelRegistry(apiClient: resolvedClient, eventBus: eventBus)
  }

}
