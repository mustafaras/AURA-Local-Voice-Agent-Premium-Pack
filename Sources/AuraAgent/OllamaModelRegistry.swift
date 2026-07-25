import AuraCore
import Foundation

/// The AURA-level task capabilities models are routed by. Distinct from
/// Ollama's own raw per-model `capabilities` strings (`completion`, `tools`,
/// `thinking`, `vision`, observed in real `/api/tags` responses) — a model's
/// raw capabilities describe what the inference engine supports; these
/// describe what AURA subsystems ask the registry to route.
public enum OllamaTaskCapability: String, Sendable, Equatable, CaseIterable {
  case classification
  case summarization
  case reasoning
}

/// A model entry as known to AURA's registry, built entirely from real
/// `/api/tags` fields — no capability or size is guessed or hardcoded.
public struct OllamaRegisteredModel: Sendable, Equatable {
  public let name: String
  public let sizeBytes: UInt64
  public let rawCapabilities: Set<String>
  /// `true` when the `/api/tags` entry reported no `remote_host` — the
  /// prompt never leaves the device. `false` for `:cloud` models, which
  /// proxy to Ollama's hosted backend regardless of the local name chosen
  /// for them.
  public let isLocal: Bool
  public let parameterSize: String?
  public let contextLength: Int?

  public init(
    name: String,
    sizeBytes: UInt64,
    rawCapabilities: Set<String>,
    isLocal: Bool,
    parameterSize: String? = nil,
    contextLength: Int? = nil
  ) {
    self.name = name
    self.sizeBytes = sizeBytes
    self.rawCapabilities = rawCapabilities
    self.isLocal = isLocal
    self.parameterSize = parameterSize
    self.contextLength = contextLength
  }
}

/// Maintains the set of models known to the local Ollama daemon and routes
/// AURA task capabilities to a concrete model deterministically — callers
/// never name a model directly.
public actor OllamaModelRegistry {
  private let apiClient: any OllamaAPIClient
  private let eventBus: AuraEventBus
  private var cachedModels: [OllamaRegisteredModel] = []

  public init(apiClient: any OllamaAPIClient, eventBus: AuraEventBus = .shared) {
    self.apiClient = apiClient
    self.eventBus = eventBus
  }

  /// Re-fetch `/api/tags` and replace the cached snapshot.
  @discardableResult
  public func refresh(
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async throws -> [OllamaRegisteredModel] {
    let tags = try await apiClient.listModels()
    let models = tags.map { tag in
      OllamaRegisteredModel(
        name: tag.name,
        sizeBytes: tag.size,
        rawCapabilities: Set(tag.capabilities),
        isLocal: (tag.remoteHost ?? "").isEmpty,
        parameterSize: tag.details.parameterSize,
        contextLength: tag.details.contextLength
      )
    }
    cachedModels = models

    let localCount = models.count { $0.isLocal }
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: OllamaRegistryRefreshedEvent(
        modelCount: models.count,
        localModelCount: localCount,
        cloudModelCount: models.count - localCount
      )
    )
    await eventBus.emit(envelope)
    return models
  }

  /// The last-fetched snapshot; empty until `refresh` has been called once.
  public func models() -> [OllamaRegisteredModel] {
    cachedModels
  }

  /// Deterministically select a model for the given capability.
  ///
  /// Rules (all grounded in real, observed `/api/tags` fields):
  /// 1. Only models advertising the base `"completion"` raw capability are
  ///    eligible — this phase never routes to embedding-only or otherwise
  ///    non-generative entries.
  /// 2. `.reasoning` prefers models that also advertise `"thinking"`;
  ///    `.classification`/`.summarization` do not require it.
  /// 3. Cloud-proxied models (`isLocal == false`) are excluded unless
  ///    `allowCloudModels` is `true` — "Models are routed by capability, not
  ///    name" must not silently imply "routed off-device."
  /// 4. Among remaining candidates, the smallest `sizeBytes` is chosen, to
  ///    minimize resident-memory pressure on the documented 16 GB target
  ///    profile.
  ///
  /// Returns `nil` when no registered model satisfies the request — the
  /// caller (`OllamaAdapter`) is responsible for entering degraded mode.
  public func route(
    capability: OllamaTaskCapability,
    allowCloudModels: Bool
  ) -> OllamaRegisteredModel? {
    var candidates = cachedModels.filter { $0.rawCapabilities.contains("completion") }
    if !allowCloudModels {
      candidates = candidates.filter { $0.isLocal }
    }
    if capability == .reasoning {
      let thinkingCapable = candidates.filter { $0.rawCapabilities.contains("thinking") }
      if !thinkingCapable.isEmpty {
        candidates = thinkingCapable
      }
    }
    return candidates.min { $0.sizeBytes < $1.sizeBytes }
  }
}
