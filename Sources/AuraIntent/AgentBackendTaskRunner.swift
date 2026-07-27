import AuraAgent
import AuraCore
import AuraTasks
import Foundation

/// Single `TaskRunner` multiplexing Codex/Claude/Copilot by a backend key
/// carried in `TaskRequest.context` — the only runner `ToolRouter` (via
/// `AuraKernel`) ever passes to `AuraTaskEngine.enqueue`/`.start`.
///
/// This isn't a convenience wrapper; it's structurally required. `AuraTask
/// Engine.pumpQueueAsync(runner:)` dequeues *whatever task is next* in the
/// shared priority queue and executes it with *whatever runner was passed
/// to that specific pump call* — not necessarily the runner a given task
/// was originally enqueued with (confirmed by reading `Sources/AuraTasks/
/// AuraTaskEngine.swift`: `enqueue`/`start` both call `pumpQueue(runner:)`
/// with their own `runner` argument, and `pumpQueueAsync` dequeues
/// independently of which runner enqueued which task). Running more than
/// one CLI backend through the same task engine therefore requires one
/// multiplexing runner that dispatches internally by inspecting the task's
/// own `context`, not three separate runner instances passed to different
/// `enqueue` calls.
public struct AgentBackendTaskRunner: TaskRunner {
  /// `TaskRequest.context` key naming which backend a task runs against.
  /// Required — a task enqueued without this key cannot be routed.
  public static let backendContextKey = "agent.backend"
  public static let supportedBackends: Set<String> = ["codex", "claude", "copilot"]

  private let codex: CodexTaskRunner
  private let claude: ClaudeTaskRunner
  private let copilot: CopilotTaskRunner

  public init(codex: CodexTaskRunner, claude: ClaudeTaskRunner, copilot: CopilotTaskRunner) {
    self.codex = codex
    self.claude = claude
    self.copilot = copilot
  }

  public func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan {
    switch try backend(for: task) {
    case .codex: return try await codex.plan(for: task)
    case .claude: return try await claude.plan(for: task)
    case .copilot: return try await copilot.plan(for: task)
    }
  }

  public func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    switch try backend(for: request) {
    case .codex:
      try await codex.execute(taskID: taskID, request: request, plan: plan, context: context)
    case .claude:
      try await claude.execute(taskID: taskID, request: request, plan: plan, context: context)
    case .copilot:
      try await copilot.execute(taskID: taskID, request: request, plan: plan, context: context)
    }
  }

  private enum Backend {
    case codex, claude, copilot
  }

  private func backend(for task: TaskRequest) throws(AuraError) -> Backend {
    guard let raw = task.context[Self.backendContextKey] else {
      throw AuraError.taskError(
        "TaskRequest is missing the '\(Self.backendContextKey)' context key")
    }
    switch raw {
    case "codex": return .codex
    case "claude": return .claude
    case "copilot": return .copilot
    default: throw AuraError.taskError("unsupported agent backend: \(raw)")
    }
  }
}
