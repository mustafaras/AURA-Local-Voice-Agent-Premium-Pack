import AuraCore
import Foundation

/// Thin `OrchestratedAgentRunning` wrappers over the already-verified
/// Codex/Claude/Copilot CLI adapters.
///
/// Each wrapper only remaps an already-normalized, already-verified event
/// case to the reduced `OrchestrationAgentEvent` shape — no new backend
/// behavior, CLI flag, or event schema is introduced here. Policy
/// evaluation, upfront approval, budget enforcement, and cancellation all
/// still happen exactly as `CodexAdapter`/`ClaudeAdapter`/`CopilotAdapter`
/// already implement them; the orchestrator never bypasses that gate.
///
/// Ollama is deliberately not wrapped here: its adapter drives a structured
/// local HTTP API (`OllamaStructuredRequest`), not a free-text CLI turn, and
/// shoehorning it into this text-turn shape would be a premature, likely
/// wrong abstraction. Named follow-up — see ADR-015.

public struct CodexOrchestratedAgent: OrchestratedAgentRunning {
  public let backendName = "codex"

  private let adapter: CodexAdapter
  private let model: String?
  private let timeoutSeconds: Double?

  public init(adapter: CodexAdapter, model: String? = nil, timeoutSeconds: Double? = nil) {
    self.adapter = adapter
    self.model = model
    self.timeoutSeconds = timeoutSeconds
  }

  public func run(
    _ request: OrchestratedAgentRunRequest
  ) async -> AsyncThrowingStream<OrchestrationAgentEvent, Error> {
    let backendRequest = CodexRunRequest(
      prompt: request.objective,
      workingDirectory: request.workingDirectory,
      sandbox: request.writable ? .workspaceWrite : .readOnly,
      model: model,
      timeoutSeconds: timeoutSeconds
    )
    let inner = await adapter.run(
      request: backendRequest, actor: request.actor, sessionID: request.sessionID,
      correlationID: request.correlationID, causationID: request.causationID)
    return Self.remap(
      inner,
      onCancel: { await self.adapter.cancel(correlationID: request.correlationID) },
      { event in
        switch event {
        case .agentText(let role, let text, _):
          return .text(role: role, content: text)
        case .approvalDecision(_, let allowed, let reason):
          return allowed ? nil : .approvalDenied(reason: reason)
        case .turnCompleted:
          return .turnCompleted
        case .turnFailed(let message):
          return .turnFailed(message: message)
        case .codexError(let message):
          return .turnFailed(message: message)
        // `.itemError` is a nested, non-fatal per-item warning (e.g. a
        // metadata-lookup fallback notice) — `CodexTaskRunner` itself treats
        // it as ignorable (`default: break`), not a turn failure; mirrored
        // here via the `default` branch below.
        case .budgetExceeded(let kind, let limit, let observed):
          return .budgetExceeded(kind: kind, limit: limit, observed: observed)
        default:
          return nil
        }
      }
    )
  }

  public func cancel(correlationID: UUID) async {
    await adapter.cancel(correlationID: correlationID)
  }

  /// Forwards a backend-specific normalized event stream into the reduced
  /// `OrchestrationAgentEvent` shape. `onCancel` propagates true consumer
  /// cancellation down to the wrapped adapter's own `cancel(correlationID:)`
  /// — mirroring the `continuation.onTermination` idiom every adapter's own
  /// `run(...)` already uses, since cancelling the forwarding `Task` alone
  /// does not by itself terminate the wrapped adapter's in-flight process.
  fileprivate static func remap<Inner: Sendable>(
    _ inner: AsyncThrowingStream<Inner, Error>,
    onCancel: @escaping @Sendable () async -> Void,
    _ transform: @escaping @Sendable (Inner) -> OrchestrationAgentEvent?
  ) -> AsyncThrowingStream<OrchestrationAgentEvent, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await event in inner {
            if let mapped = transform(event) {
              continuation.yield(mapped)
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { @Sendable termination in
        guard case .cancelled = termination else { return }
        task.cancel()
        Task { await onCancel() }
      }
    }
  }
}

public struct ClaudeOrchestratedAgent: OrchestratedAgentRunning {
  public let backendName = "claude"

  private let adapter: ClaudeAdapter
  private let model: String?
  private let timeoutSeconds: Double?

  public init(adapter: ClaudeAdapter, model: String? = nil, timeoutSeconds: Double? = nil) {
    self.adapter = adapter
    self.model = model
    self.timeoutSeconds = timeoutSeconds
  }

  public func run(
    _ request: OrchestratedAgentRunRequest
  ) async -> AsyncThrowingStream<OrchestrationAgentEvent, Error> {
    let backendRequest = ClaudeRunRequest(
      objective: request.objective,
      workingDirectory: request.workingDirectory,
      toolProfile: request.writable ? .workspaceWrite : .readOnly,
      model: model,
      timeoutSeconds: timeoutSeconds
    )
    let inner = await adapter.run(
      request: backendRequest, actor: request.actor, sessionID: request.sessionID,
      correlationID: request.correlationID, causationID: request.causationID)
    return CodexOrchestratedAgent.remap(
      inner,
      onCancel: { await self.adapter.cancel(correlationID: request.correlationID) },
      { event in
        switch event {
        case .message(let role, let text, _):
          return .text(role: role, content: text)
        case .approvalDecision(_, let allowed, let reason):
          return allowed ? nil : .approvalDenied(reason: reason)
        case .turnCompleted:
          return .turnCompleted
        case .turnFailed(let message, _):
          return .turnFailed(message: message)
        case .claudeError(let message):
          return .turnFailed(message: message)
        case .budgetExceeded(let kind, let limit, let observed):
          return .budgetExceeded(kind: kind, limit: limit, observed: observed)
        default:
          return nil
        }
      }
    )
  }

  public func cancel(correlationID: UUID) async {
    await adapter.cancel(correlationID: correlationID)
  }
}

public struct CopilotOrchestratedAgent: OrchestratedAgentRunning {
  public let backendName = "copilot"

  private let adapter: CopilotAdapter
  private let model: String?
  private let timeoutSeconds: Double?

  public init(adapter: CopilotAdapter, model: String? = nil, timeoutSeconds: Double? = nil) {
    self.adapter = adapter
    self.model = model
    self.timeoutSeconds = timeoutSeconds
  }

  public func run(
    _ request: OrchestratedAgentRunRequest
  ) async -> AsyncThrowingStream<OrchestrationAgentEvent, Error> {
    let backendRequest = CopilotRunRequest(
      objective: request.objective,
      workingDirectory: request.workingDirectory,
      toolProfile: request.writable ? .workspaceWrite : .readOnly,
      model: model,
      timeoutSeconds: timeoutSeconds
    )
    let inner = await adapter.run(
      request: backendRequest, actor: request.actor, sessionID: request.sessionID,
      correlationID: request.correlationID, causationID: request.causationID)
    return CodexOrchestratedAgent.remap(
      inner,
      onCancel: { await self.adapter.cancel(correlationID: request.correlationID) },
      { event in
        switch event {
        case .message(let role, let content, _):
          return .text(role: role, content: content)
        case .approvalDecision(_, let allowed, let reason):
          return allowed ? nil : .approvalDenied(reason: reason)
        case .turnCompleted:
          return .turnCompleted
        case .turnFailed(let message):
          return .turnFailed(message: message)
        case .copilotError(let message):
          return .turnFailed(message: message)
        case .budgetExceeded(let kind, let limit, let observed):
          return .budgetExceeded(kind: kind, limit: limit, observed: observed)
        default:
          return nil
        }
      }
    )
  }

  public func cancel(correlationID: UUID) async {
    await adapter.cancel(correlationID: correlationID)
  }
}
