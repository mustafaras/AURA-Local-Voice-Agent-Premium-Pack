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
  /// Optional shared resource governor (R7). When present, the adapter
  /// reserves the `.reasoning` workload before admission and releases it
  /// when the request completes or degrades. When absent (e.g. tests), no
  /// shared reservation is made — the adapter's own
  /// `maxResidentModelBytes` budget still applies.
  let resourceGovernor: VoiceResourceGovernor?

  public init(
    configuration: OllamaConfiguration,
    policyEngine: PolicyEngine,
    approvalPresenter: any OllamaApprovalPresenting = OllamaAlwaysDenyApprovalPresenter(),
    apiClient: (any OllamaAPIClient)? = nil,
    eventBus: AuraEventBus = .shared,
    thermalStateProvider: @escaping @Sendable () -> ProcessInfo.ThermalState = {
      ProcessInfo.processInfo.thermalState
    },
    resourceGovernor: VoiceResourceGovernor? = nil
  ) throws(AuraError) {
    self.configuration = configuration
    self.policyEngine = policyEngine
    self.approvalPresenter = approvalPresenter
    self.eventBus = eventBus
    self.thermalStateProvider = thermalStateProvider
    self.resourceGovernor = resourceGovernor
    let resolvedClient: any OllamaAPIClient
    if let apiClient {
      resolvedClient = apiClient
    } else {
      resolvedClient = try URLSessionOllamaAPIClient(configuration: configuration)
    }
    self.apiClient = resolvedClient
    self.registry = OllamaModelRegistry(apiClient: resolvedClient, eventBus: eventBus)
  }

  /// Map an Ollama task capability to the shared governor workload.
  static func voiceWorkload(for capability: OllamaTaskCapability) -> VoiceWorkload {
    switch capability {
    case .classification, .summarization, .reasoning: .reasoning
    }
  }

  /// Reserve the shared governor's `.reasoning` budget for a request if a
  /// governor is present. On denial, records a governor failure circuit and
  /// returns `false` so the caller degrades.
  func reserveSharedGovernor(_ capability: OllamaTaskCapability) async -> Bool {
    guard let resourceGovernor else { return true }
    let decision = await resourceGovernor.reserve(
      Self.voiceWorkload(for: capability), estimatedMemoryMB: 2_048, priority: .interactive)
    guard decision.granted else {
      await resourceGovernor.recordFailure(Self.voiceWorkload(for: capability))
      return false
    }
    return true
  }

  func releaseSharedGovernor(_ capability: OllamaTaskCapability) async {
    guard let resourceGovernor else { return }
    await resourceGovernor.release(
      Self.voiceWorkload(for: capability), estimatedMemoryMB: 2_048)
  }

}
