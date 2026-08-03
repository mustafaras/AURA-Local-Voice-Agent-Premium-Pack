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
  private let configuration: OllamaConfiguration
  private let policyEngine: PolicyEngine
  private let approvalPresenter: any OllamaApprovalPresenting
  private let apiClient: any OllamaAPIClient
  private let registry: OllamaModelRegistry
  private let eventBus: AuraEventBus
  private let thermalStateProvider: @Sendable () -> ProcessInfo.ThermalState

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

  /// Lightweight liveness probe (`GET /api/version`).
  public func healthCheck(actor: ActorID, correlationID: UUID, causationID: UUID) async -> Bool {
    let start = Date()
    do {
      let version = try await apiClient.health()
      let latencyMs = Date().timeIntervalSince(start) * 1000
      await emitAudit(
        OllamaHealthCheckEvent(healthy: true, version: version.version, latencyMilliseconds: latencyMs),
        actor: actor, correlationID: correlationID, causationID: causationID)
      return true
    } catch {
      await emitAudit(
        OllamaHealthCheckEvent(healthy: false),
        actor: actor, correlationID: correlationID, causationID: causationID)
      return false
    }
  }

  /// Classify `prompt` into exactly one of `labels`, using a schema-
  /// constrained structured request re-validated against `labels`.
  public func classify(
    prompt: String,
    labels: [String],
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    deterministicFallback: (@Sendable (String, [String]) -> String)? = nil
  ) async throws(AuraError) -> OllamaCapabilityResult {
    let capability = OllamaTaskCapability.classification
    switch await preflight(
      capability: capability, actor: actor, sessionID: sessionID, correlationID: correlationID,
      causationID: causationID)
    {
    case .degraded(let reason):
      await emitDegraded(capability: capability, reason: reason, actor: actor,
        correlationID: correlationID, causationID: causationID)
      guard let deterministicFallback else {
        throw AuraError.ollamaError(
          "ollama unavailable for classification and no deterministic fallback was provided (reason: \(reason.rawValue))"
        )
      }
      return OllamaCapabilityResult(text: deterministicFallback(prompt, labels), model: nil, degraded: true)

    case .ready(let model):
      let runID = correlationID
      await emitAudit(
        OllamaInferenceStartedEvent(
          runID: runID, model: model.name, capability: capability.rawValue,
          isLocalModel: model.isLocal, structuredOutputRequested: true),
        actor: actor, correlationID: correlationID, causationID: causationID)
      do {
        let result = try await OllamaStructuredRequest.classify(
          apiClient: apiClient, model: model.name, prompt: prompt, labels: labels,
          keepAliveSeconds: configuration.keepAliveSeconds)
        await emitAudit(
          OllamaInferenceCompletedEvent(runID: runID, model: model.name),
          actor: actor, correlationID: correlationID, causationID: causationID)
        return OllamaCapabilityResult(text: result.classification, model: model.name, degraded: false)
      } catch {
        await emitAudit(
          OllamaErrorEvent(runID: runID, category: .structuredValidationFailed, message: "\(error)"),
          actor: actor, correlationID: correlationID, causationID: causationID)
        if let deterministicFallback {
          return OllamaCapabilityResult(
            text: deterministicFallback(prompt, labels), model: model.name, degraded: true)
        }
        throw error
      }
    }
  }

  public func structuredNLU(
    prompt: String,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async throws(AuraError) -> OllamaNLUResult {
    let capability = OllamaTaskCapability.classification
    switch await preflight(
      capability: capability,
      actor: actor,
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: causationID)
    {
    case .degraded(let reason):
      await emitDegraded(
        capability: capability,
        reason: reason,
        actor: actor,
        correlationID: correlationID,
        causationID: causationID)
      throw AuraError.ollamaError(
        "ollama unavailable for structured NLU (reason: \(reason.rawValue))")
    case .ready(let model):
      await emitAudit(
        OllamaInferenceStartedEvent(
          runID: correlationID,
          model: model.name,
          capability: capability.rawValue,
          isLocalModel: model.isLocal,
          structuredOutputRequested: true),
        actor: actor,
        correlationID: correlationID,
        causationID: causationID)
      do {
        let result = try await OllamaStructuredRequest.propose(
          apiClient: apiClient,
          model: model.name,
          prompt: prompt,
          keepAliveSeconds: configuration.keepAliveSeconds)
        await emitAudit(
          OllamaInferenceCompletedEvent(runID: correlationID, model: model.name),
          actor: actor,
          correlationID: correlationID,
          causationID: causationID)
        return result
      } catch {
        await emitAudit(
          OllamaErrorEvent(
            runID: correlationID,
            category: .structuredValidationFailed,
            message: "structured NLU response rejected"),
          actor: actor,
          correlationID: correlationID,
          causationID: causationID)
        throw error
      }
    }
  }

  /// Summarize `prompt` into a single string, structured-output validated.
  public func summarize(
    prompt: String,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    deterministicFallback: (@Sendable (String) -> String)? = nil
  ) async throws(AuraError) -> OllamaCapabilityResult {
    let capability = OllamaTaskCapability.summarization
    switch await preflight(
      capability: capability, actor: actor, sessionID: sessionID, correlationID: correlationID,
      causationID: causationID)
    {
    case .degraded(let reason):
      await emitDegraded(capability: capability, reason: reason, actor: actor,
        correlationID: correlationID, causationID: causationID)
      guard let deterministicFallback else {
        throw AuraError.ollamaError(
          "ollama unavailable for summarization and no deterministic fallback was provided (reason: \(reason.rawValue))"
        )
      }
      return OllamaCapabilityResult(text: deterministicFallback(prompt), model: nil, degraded: true)

    case .ready(let model):
      let runID = correlationID
      await emitAudit(
        OllamaInferenceStartedEvent(
          runID: runID, model: model.name, capability: capability.rawValue,
          isLocalModel: model.isLocal, structuredOutputRequested: true),
        actor: actor, correlationID: correlationID, causationID: causationID)
      do {
        let result = try await OllamaStructuredRequest.summarize(
          apiClient: apiClient, model: model.name, prompt: prompt,
          keepAliveSeconds: configuration.keepAliveSeconds)
        await emitAudit(
          OllamaInferenceCompletedEvent(runID: runID, model: model.name),
          actor: actor, correlationID: correlationID, causationID: causationID)
        return OllamaCapabilityResult(text: result.summary, model: model.name, degraded: false)
      } catch {
        await emitAudit(
          OllamaErrorEvent(runID: runID, category: .structuredValidationFailed, message: "\(error)"),
          actor: actor, correlationID: correlationID, causationID: causationID)
        if let deterministicFallback {
          return OllamaCapabilityResult(
            text: deterministicFallback(prompt), model: model.name, degraded: true)
        }
        throw error
      }
    }
  }

  /// Free-form, unconstrained generation for lightweight reasoning tasks.
  /// No deterministic fallback is offered — open-ended reasoning has no
  /// honest rule-based substitute, so this throws when Ollama is
  /// unavailable rather than fabricating a canned response.
  public func reason(
    prompt: String,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async throws(AuraError) -> OllamaCapabilityResult {
    let capability = OllamaTaskCapability.reasoning
    switch await preflight(
      capability: capability, actor: actor, sessionID: sessionID, correlationID: correlationID,
      causationID: causationID)
    {
    case .degraded(let reason):
      await emitDegraded(capability: capability, reason: reason, actor: actor,
        correlationID: correlationID, causationID: causationID)
      throw AuraError.ollamaError(
        "ollama unavailable for reasoning; no deterministic fallback exists for open-ended reasoning (reason: \(reason.rawValue))"
      )

    case .ready(let model):
      let runID = correlationID
      await emitAudit(
        OllamaInferenceStartedEvent(
          runID: runID, model: model.name, capability: capability.rawValue,
          isLocalModel: model.isLocal, structuredOutputRequested: false),
        actor: actor, correlationID: correlationID, causationID: causationID)
      do {
        let response = try await apiClient.generate(
          model: model.name, prompt: prompt, format: nil,
          keepAliveSeconds: configuration.keepAliveSeconds)
        await emitAudit(
          OllamaInferenceCompletedEvent(
            runID: runID, model: model.name, evalCount: response.evalCount,
            totalDurationMilliseconds: response.totalDuration.map { Double($0) / 1_000_000.0 },
            doneReason: response.doneReason),
          actor: actor, correlationID: correlationID, causationID: causationID)
        return OllamaCapabilityResult(text: response.response, model: model.name, degraded: false)
      } catch {
        let auraError = error as? AuraError ?? AuraError.ollamaError("\(error)")
        await emitAudit(
          OllamaErrorEvent(runID: runID, category: .networkError, message: "\(auraError)"),
          actor: actor, correlationID: correlationID, causationID: causationID)
        throw auraError
      }
    }
  }

  // MARK: - Preflight (health, thermal, routing, policy, budget)

  private enum PreflightResult {
    case ready(OllamaRegisteredModel)
    case degraded(OllamaDegradedModeEvent.Reason)
  }

  private func preflight(
    capability: OllamaTaskCapability,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> PreflightResult {
    guard await healthCheck(actor: actor, correlationID: correlationID, causationID: causationID)
    else {
      return .degraded(.healthCheckFailed)
    }

    if configuration.thermalAwarenessEnabled, thermalStateProvider() == .critical {
      await emitAudit(
        OllamaBudgetExceededEvent(kind: .thermalPressure, limit: 0, observed: 1),
        actor: actor, correlationID: correlationID, causationID: causationID)
      return .degraded(.budgetExceeded)
    }

    if await registry.models().isEmpty {
      _ = try? await registry.refresh(
        actor: actor, correlationID: correlationID, causationID: causationID)
    }

    guard
      let model = await registry.route(
        capability: capability, allowCloudModels: configuration.allowCloudModels)
    else {
      return .degraded(.noModelForCapability)
    }

    let policyRequest = OllamaPolicyAdapter.request(
      model: model, capability: capability, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    let decision = await policyEngine.evaluate(policyRequest)
    let approved: Bool
    switch decision {
    case .allow:
      approved = true
    case .deny:
      approved = false
    case .confirm(let challenge, _):
      let response = await approvalPresenter.present(challenge: challenge)
      let resolved = await policyEngine.submitConfirmation(response)
      if case .allow = resolved {
        approved = true
      } else {
        approved = false
      }
    }
    guard approved else {
      return .degraded(.policyDenied)
    }

    guard
      await ensureMemoryBudget(
        for: model, actor: actor, correlationID: correlationID, causationID: causationID)
    else {
      return .degraded(.budgetExceeded)
    }

    return .ready(model)
  }

  /// Ensures `model` fits within `maxResidentModelBytes`, evicting other
  /// resident models (oldest-`expires_at`-first) via `keep_alive: 0` if
  /// necessary. Returns `false` only if the model still would not fit even
  /// after evicting every other resident model.
  private func ensureMemoryBudget(
    for model: OllamaRegisteredModel,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async -> Bool {
    guard let running = try? await apiClient.listRunningModels() else {
      // /api/ps is unavailable; proceed optimistically rather than blocking
      // every request on a transient residency-listing failure.
      return true
    }
    if running.contains(where: { $0.name == model.name }) {
      return true
    }

    var residentBytes = running.reduce(UInt64(0)) { $0 + $1.sizeVram }
    guard residentBytes + model.sizeBytes > configuration.maxResidentModelBytes else {
      return true
    }

    for resident in running.sorted(by: { $0.expiresAt < $1.expiresAt }) {
      guard residentBytes + model.sizeBytes > configuration.maxResidentModelBytes else { break }
      try? await apiClient.unload(model: resident.name)
      residentBytes -= min(residentBytes, resident.sizeVram)
      await emitAudit(
        OllamaModelLifecycleEvent(
          model: resident.name, phase: .evictedForBudget, sizeBytes: resident.sizeVram),
        actor: actor, correlationID: correlationID, causationID: causationID)
    }

    guard residentBytes + model.sizeBytes <= configuration.maxResidentModelBytes else {
      await emitAudit(
        OllamaBudgetExceededEvent(
          kind: .residentMemory, limit: Double(configuration.maxResidentModelBytes),
          observed: Double(residentBytes + model.sizeBytes)),
        actor: actor, correlationID: correlationID, causationID: causationID)
      return false
    }
    return true
  }

  private func emitDegraded(
    capability: OllamaTaskCapability,
    reason: OllamaDegradedModeEvent.Reason,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    await emitAudit(
      OllamaDegradedModeEvent(capability: capability.rawValue, reason: reason),
      actor: actor, correlationID: correlationID, causationID: causationID)
  }

  private func emitAudit<Payload: EventPayload>(
    _ payload: Payload,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}
