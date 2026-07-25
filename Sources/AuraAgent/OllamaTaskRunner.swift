import AuraCore
import AuraTasks
import Foundation

/// Runs a single Ollama capability request (classification, summarization,
/// or reasoning) as a durable `AuraTasks` task — useful for capabilities
/// whose latency (e.g. a long summarization job on a large document) merits
/// checkpointing and progress reporting rather than a bare async call.
///
/// There is no type-based runner registry in `AuraTaskEngine` — whoever
/// creates an Ollama-driven `TaskRequest` passes an `OllamaTaskRunner`
/// instance explicitly to `engine.enqueue(request:runner:)`. The capability
/// (and, for classification, the label set) is read from
/// `TaskRequest.context`'s existing free-form dictionary, so no changes to
/// `AuraTasks` were needed for this phase — the same pattern
/// `CodexTaskRunner`/`ClaudeTaskRunner`/`CopilotTaskRunner` established.
public struct OllamaTaskRunner: TaskRunner {
  /// `TaskRequest.context` key selecting `OllamaTaskCapability.rawValue`.
  public static let capabilityContextKey = "ollama.capability"
  /// `TaskRequest.context` key: comma-separated labels, required when the
  /// capability is `.classification`.
  public static let labelsContextKey = "ollama.labels"

  private let adapter: OllamaAdapter
  private let actor: ActorID
  private let sessionID: UUID
  private let defaultCapability: OllamaTaskCapability

  public init(
    adapter: OllamaAdapter,
    actor: ActorID = .agentOllama,
    sessionID: UUID,
    defaultCapability: OllamaTaskCapability = .reasoning
  ) {
    self.adapter = adapter
    self.actor = actor
    self.sessionID = sessionID
    self.defaultCapability = defaultCapability
  }

  /// A single Ollama request is opaque ahead of time, so this always
  /// reports one step.
  public func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan {
    TaskPlan(totalSteps: 1, stepDescriptions: ["Run Ollama capability request"])
  }

  public func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    await context.checkCancellation()
    if await context.isCancelled {
      throw AuraError.taskCancelled(taskID)
    }

    let capability =
      request.context[Self.capabilityContextKey].flatMap(OllamaTaskCapability.init(rawValue:))
      ?? defaultCapability

    let result: OllamaCapabilityResult
    switch capability {
    case .classification:
      let labels =
        (request.context[Self.labelsContextKey] ?? "")
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
      guard !labels.isEmpty else {
        throw AuraError.ollamaError(
          "classification task requires '\(Self.labelsContextKey)' context with at least one label"
        )
      }
      result = try await adapter.classify(
        prompt: request.objective, labels: labels, actor: actor, sessionID: sessionID,
        correlationID: taskID, causationID: taskID)

    case .summarization:
      result = try await adapter.summarize(
        prompt: request.objective, actor: actor, sessionID: sessionID, correlationID: taskID,
        causationID: taskID)

    case .reasoning:
      result = try await adapter.reason(
        prompt: request.objective, actor: actor, sessionID: sessionID, correlationID: taskID,
        causationID: taskID)
    }

    await context.reportProgress(
      completedSteps: 1, totalSteps: plan.totalSteps,
      currentStepDescription: result.degraded
        ? "Completed via deterministic fallback"
        : "Completed via \(result.model ?? "unknown model")"
    )
  }
}
