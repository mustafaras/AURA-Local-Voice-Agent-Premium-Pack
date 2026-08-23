import AuraCore
import AuraPolicy
import Foundation

extension OllamaAdapter {
  // MARK: - Preflight (health, thermal, routing, policy, budget)

  enum PreflightResult {
    case ready(OllamaRegisteredModel)
    case degraded(OllamaDegradedModeEvent.Reason)
  }

  func preflight(
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

    // Reserve the shared R7 governor's reasoning budget before model routing
    // and admission, so a competing STT/TTS reservation that has already
    // consumed the resident budget denies this request (fail closed) instead
    // of silently co-residing. Released in every terminal `*Inference` method.
    guard await reserveSharedGovernor(capability) else {
      await emitAudit(
        OllamaBudgetExceededEvent(kind: .residentMemory, limit: 0, observed: 1),
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

    guard
      await policyAllows(
        model: model,
        capability: capability,
        context: OllamaPolicyContext(
          actor: actor,
          sessionID: sessionID,
          correlationID: correlationID,
          causationID: causationID))
    else {
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

  private func policyAllows(
    model: OllamaRegisteredModel,
    capability: OllamaTaskCapability,
    context: OllamaPolicyContext
  ) async -> Bool {
    let request = OllamaPolicyAdapter.request(
      model: model,
      capability: capability,
      context: context)
    switch await policyEngine.evaluate(request) {
    case .allow:
      return true
    case .deny:
      return false
    case .confirm(let challenge, _):
      let response = await approvalPresenter.present(challenge: challenge)
      if case .allow = await policyEngine.submitConfirmation(response) {
        return true
      }
      return false
    }
  }

  /// Ensures `model` fits within `maxResidentModelBytes`, evicting other
  /// resident models (oldest-`expires_at`-first) via `keep_alive: 0` if
  /// necessary. Returns `false` only if the model still would not fit even
  /// after evicting every other resident model.
  ///
  /// A model not yet resident is only known by its on-disk `/api/tags`
  /// size, which is not the same quantity as resident VRAM (real-world
  /// gap proven in `EV-R2-20260803-OLLAMA-LIVE-BENCHMARK-01`: `gemma4:latest`
  /// at 9.6 GB on disk resolved to ~3.2 GB `size_vram` once loaded). Using
  /// the raw disk size here would falsely reject a cold load that fits
  /// comfortably once resident, so the candidate's estimated footprint is
  /// derated by `configuration.estimatedResidentMemoryRatio`. Already
  /// resident models (both the ones already accounted for in `running` and
  /// the fast-path check below) always use their real measured
  /// `size_vram`, never this estimate.
  func ensureMemoryBudget(
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

    let estimatedModelBytes = UInt64(
      Double(model.sizeBytes) * configuration.estimatedResidentMemoryRatio)

    var residentBytes = running.reduce(UInt64(0)) { $0 + $1.sizeVram }
    guard residentBytes + estimatedModelBytes > configuration.maxResidentModelBytes else {
      return true
    }

    for resident in running.sorted(by: { $0.expiresAt < $1.expiresAt }) {
      guard residentBytes + estimatedModelBytes > configuration.maxResidentModelBytes else {
        break
      }
      try? await apiClient.unload(model: resident.name)
      residentBytes -= min(residentBytes, resident.sizeVram)
      await emitAudit(
        OllamaModelLifecycleEvent(
          model: resident.name, phase: .evictedForBudget, sizeBytes: resident.sizeVram),
        actor: actor, correlationID: correlationID, causationID: causationID)
    }

    guard residentBytes + estimatedModelBytes <= configuration.maxResidentModelBytes else {
      await emitAudit(
        OllamaBudgetExceededEvent(
          kind: .residentMemory, limit: Double(configuration.maxResidentModelBytes),
          observed: Double(residentBytes + estimatedModelBytes)),
        actor: actor, correlationID: correlationID, causationID: causationID)
      return false
    }
    return true
  }

  func emitDegraded(
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

  func emitAudit<Payload: EventPayload>(
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
