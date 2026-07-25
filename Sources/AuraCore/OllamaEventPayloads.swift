import Foundation

// MARK: - Ollama local model controller event payloads
//
// Unlike the Codex/Claude/Copilot adapters, Ollama is driven over its local
// HTTP API (verified: `http://127.0.0.1:11434`), not a spawned CLI process —
// there is no "approval need" concept here since the confirmed API surface
// used by this phase (`/api/tags`, `/api/show`, `/api/ps`, `/api/generate`,
// `/api/chat`, `/api/version`) never writes files or runs commands. The
// meaningful policy boundary is instead local-vs-cloud: a model whose
// `/api/tags` entry reports a `remote_host` proxies the prompt to Ollama's
// hosted backend, which is the one action in this phase that leaves the
// device.

/// Emitted after a model-registry refresh (`GET /api/tags`, optionally
/// `POST /api/show` per model for capability/context-length detail).
public struct OllamaRegistryRefreshedEvent: EventPayload {
  public static let eventType = "ollama.registry.refreshed"

  public let modelCount: Int
  public let localModelCount: Int
  public let cloudModelCount: Int
  public let refreshedAt: Date

  public init(
    modelCount: Int,
    localModelCount: Int,
    cloudModelCount: Int,
    refreshedAt: Date = Date()
  ) {
    self.modelCount = modelCount
    self.localModelCount = localModelCount
    self.cloudModelCount = cloudModelCount
    self.refreshedAt = refreshedAt
  }
}

/// Emitted for the lightweight `GET /api/version` liveness probe.
public struct OllamaHealthCheckEvent: EventPayload {
  public static let eventType = "ollama.health.checked"

  public let healthy: Bool
  public let version: String?
  public let latencyMilliseconds: Double?
  public let checkedAt: Date

  public init(
    healthy: Bool,
    version: String? = nil,
    latencyMilliseconds: Double? = nil,
    checkedAt: Date = Date()
  ) {
    self.healthy = healthy
    self.version = version
    self.latencyMilliseconds = latencyMilliseconds
    self.checkedAt = checkedAt
  }
}

/// Emitted when a model is loaded or unloaded from `/api/ps`-tracked
/// residency, including evictions performed to respect the memory budget.
public struct OllamaModelLifecycleEvent: EventPayload {
  public static let eventType = "ollama.model.lifecycle"

  public enum Phase: String, Codable, Sendable, Equatable {
    case loaded
    case unloaded
    case evictedForBudget
  }

  public let model: String
  public let phase: Phase
  public let sizeBytes: UInt64?
  public let observedAt: Date

  public init(
    model: String,
    phase: Phase,
    sizeBytes: UInt64? = nil,
    observedAt: Date = Date()
  ) {
    self.model = model
    self.phase = phase
    self.sizeBytes = sizeBytes
    self.observedAt = observedAt
  }
}

/// Emitted when an inference request (`/api/generate` or `/api/chat`) is
/// about to be sent, after policy and budget checks pass.
public struct OllamaInferenceStartedEvent: EventPayload {
  public static let eventType = "ollama.inference.started"

  public let runID: UUID
  public let model: String
  public let capability: String
  public let isLocalModel: Bool
  public let structuredOutputRequested: Bool
  public let startedAt: Date

  public init(
    runID: UUID,
    model: String,
    capability: String,
    isLocalModel: Bool,
    structuredOutputRequested: Bool,
    startedAt: Date = Date()
  ) {
    self.runID = runID
    self.model = model
    self.capability = capability
    self.isLocalModel = isLocalModel
    self.structuredOutputRequested = structuredOutputRequested
    self.startedAt = startedAt
  }
}

/// Emitted once an inference request returns a response, decoded from the
/// confirmed `/api/generate`/`/api/chat` fields (`eval_count`,
/// `total_duration`, etc.). Never carries prompt or completion text.
public struct OllamaInferenceCompletedEvent: EventPayload {
  public static let eventType = "ollama.inference.completed"

  public let runID: UUID
  public let model: String
  public let evalCount: Int?
  public let totalDurationMilliseconds: Double?
  public let doneReason: String?
  public let completedAt: Date

  public init(
    runID: UUID,
    model: String,
    evalCount: Int? = nil,
    totalDurationMilliseconds: Double? = nil,
    doneReason: String? = nil,
    completedAt: Date = Date()
  ) {
    self.runID = runID
    self.model = model
    self.evalCount = evalCount
    self.totalDurationMilliseconds = totalDurationMilliseconds
    self.doneReason = doneReason
    self.completedAt = completedAt
  }
}

/// Emitted when a model's response fails to decode against the caller's
/// requested typed schema, even though `format` was supplied to Ollama —
/// the `format` grammar constraint is a best-effort hint, not a guarantee,
/// so AURA independently validates every structured response before it is
/// trusted. Never carries the raw response text.
public struct OllamaStructuredValidationFailedEvent: EventPayload {
  public static let eventType = "ollama.structuredOutput.validationFailed"

  public let runID: UUID
  public let model: String
  public let schemaTypeName: String
  public let reason: String
  public let occurredAt: Date

  public init(
    runID: UUID,
    model: String,
    schemaTypeName: String,
    reason: String,
    occurredAt: Date = Date()
  ) {
    self.runID = runID
    self.model = model
    self.schemaTypeName = schemaTypeName
    self.reason = reason
    self.occurredAt = occurredAt
  }
}

/// Emitted when a request is refused or a model is evicted because of the
/// configured resident-memory budget or `ProcessInfo` thermal state.
public struct OllamaBudgetExceededEvent: EventPayload {
  public static let eventType = "ollama.budget.exceeded"

  public enum Kind: String, Codable, Sendable, Equatable {
    case residentMemory
    case thermalPressure
  }

  public let kind: Kind
  public let limit: Double
  public let observed: Double
  public let exceededAt: Date

  public init(
    kind: Kind,
    limit: Double,
    observed: Double,
    exceededAt: Date = Date()
  ) {
    self.kind = kind
    self.limit = limit
    self.observed = observed
    self.exceededAt = exceededAt
  }
}

/// Emitted when `OllamaAdapter` falls back to a deterministic, non-model
/// rule for a capability because the daemon is unreachable, policy denied
/// the only available model, or no registered model satisfies the request.
public struct OllamaDegradedModeEvent: EventPayload {
  public static let eventType = "ollama.degradedMode.entered"

  public enum Reason: String, Codable, Sendable, Equatable {
    case healthCheckFailed
    case noModelForCapability
    case policyDenied
    case budgetExceeded
  }

  public let capability: String
  public let reason: Reason
  public let enteredAt: Date

  public init(
    capability: String,
    reason: Reason,
    enteredAt: Date = Date()
  ) {
    self.capability = capability
    self.reason = reason
    self.enteredAt = enteredAt
  }
}

/// Emitted whenever an Ollama request fails for any reason.
public struct OllamaErrorEvent: EventPayload {
  public static let eventType = "ollama.error"

  public enum Category: String, Codable, Sendable, Equatable {
    case healthCheckFailed
    case decodeFailed
    case structuredValidationFailed
    case budgetExceeded
    case policyDenied
    case timedOut
    case networkError
    case modelNotFound
    case cloudModelDisallowed
    case unknown
  }

  public let runID: UUID?
  public let category: Category
  public let message: String
  public let occurredAt: Date

  public init(
    runID: UUID? = nil,
    category: Category,
    message: String,
    occurredAt: Date = Date()
  ) {
    self.runID = runID
    self.category = category
    self.message = message
    self.occurredAt = occurredAt
  }
}
