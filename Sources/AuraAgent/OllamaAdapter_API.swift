import AuraCore
import AuraPolicy
import Foundation

extension OllamaAdapter {
  /// Lightweight liveness probe (`GET /api/version`).
  public func healthCheck(actor: ActorID, correlationID: UUID, causationID: UUID) async -> Bool {
    let start = Date()
    do {
      let version = try await apiClient.health()
      let latencyMs = Date().timeIntervalSince(start) * 1000
      await emitAudit(
        OllamaHealthCheckEvent(
          healthy: true, version: version.version, latencyMilliseconds: latencyMs),
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
    context: OllamaInferenceContext,
    deterministicFallback: (@Sendable (String, [String]) -> String)? = nil
  ) async throws(AuraError) -> OllamaCapabilityResult {
    let actor = context.actor
    let sessionID = context.sessionID
    let correlationID = context.correlationID
    let causationID = context.causationID
    let capability = OllamaTaskCapability.classification
    switch await preflight(
      capability: capability, actor: actor, sessionID: sessionID, correlationID: correlationID,
      causationID: causationID)
    {
    case .degraded(let reason):
      await emitDegraded(
        capability: capability, reason: reason, actor: actor,
        correlationID: correlationID, causationID: causationID)
      guard let deterministicFallback else {
        throw AuraError.ollamaError(
          "ollama unavailable for classification and no deterministic fallback "
            + "was provided (reason: \(reason.rawValue))"
        )
      }
      return OllamaCapabilityResult(
        text: deterministicFallback(prompt, labels), model: nil, degraded: true)

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
        return OllamaCapabilityResult(
          text: result.classification, model: model.name, degraded: false)
      } catch {
        await emitAudit(
          OllamaErrorEvent(
            runID: runID, category: .structuredValidationFailed, message: "\(error)"),
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
    switch await preflight(
      capability: .classification,
      actor: actor,
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: causationID)
    {
    case .degraded(let reason):
      await emitDegraded(
        capability: .classification,
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
          capability: OllamaTaskCapability.classification.rawValue,
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
      await emitDegraded(
        capability: capability, reason: reason, actor: actor,
        correlationID: correlationID, causationID: causationID)
      guard let deterministicFallback else {
        throw AuraError.ollamaError(
          "ollama unavailable for summarization and no deterministic fallback "
            + "was provided (reason: \(reason.rawValue))"
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
          OllamaErrorEvent(
            runID: runID, category: .structuredValidationFailed, message: "\(error)"),
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
      await emitDegraded(
        capability: capability, reason: reason, actor: actor,
        correlationID: correlationID, causationID: causationID)
      throw AuraError.ollamaError(
        "ollama unavailable for reasoning; no deterministic fallback exists for "
          + "open-ended reasoning (reason: \(reason.rawValue))"
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
}
