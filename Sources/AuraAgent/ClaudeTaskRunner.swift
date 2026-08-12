import AuraCore
import AuraTasks
import Foundation

/// Runs a Claude Code turn as a durable `AuraTasks` task. Mirrors
/// `CodexTaskRunner`.
///
/// There is no type-based runner registry in `AuraTaskEngine` — whoever
/// creates a Claude-driven `TaskRequest` passes a `ClaudeTaskRunner` instance
/// explicitly to `engine.enqueue(request:runner:)`. Working directory and
/// tool profile are read from `TaskRequest.context`'s existing free-form
/// dictionary, so no changes to `AuraTasks` were needed for this phase.
public struct ClaudeTaskRunner: TaskRunner {
  /// `TaskRequest.context` key for the Claude run's working directory.
  public static let workingDirectoryContextKey = "claude.workingDirectory"
  /// `TaskRequest.context` key for the Claude tool profile
  /// (`ClaudeToolProfile.rawValue`).
  public static let toolProfileContextKey = "claude.toolProfile"

  private let adapter: ClaudeAdapter
  private let actor: ActorID
  private let sessionID: UUID
  private let defaultWorkingDirectory: String
  private let defaultToolProfile: ClaudeToolProfile

  public init(
    adapter: ClaudeAdapter,
    actor: ActorID = .agentClaude,
    sessionID: UUID,
    defaultWorkingDirectory: String,
    defaultToolProfile: ClaudeToolProfile = .readOnly
  ) {
    self.adapter = adapter
    self.actor = actor
    self.sessionID = sessionID
    self.defaultWorkingDirectory = defaultWorkingDirectory
    self.defaultToolProfile = defaultToolProfile
  }

  /// A single `claude -p` turn is opaque ahead of time, so this always
  /// reports one step.
  public func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan {
    TaskPlan(totalSteps: 1, stepDescriptions: ["Run Claude Code turn"])
  }

  public func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    let workingDirectory =
      request.context[Self.workingDirectoryContextKey] ?? defaultWorkingDirectory
    let toolProfile =
      request.context[Self.toolProfileContextKey].flatMap(ClaudeToolProfile.init(rawValue:))
      ?? defaultToolProfile

    let runRequest = ClaudeRunRequest(
      objective: request.objective,
      workingDirectory: workingDirectory,
      toolProfile: toolProfile
    )

    let stream = await adapter.run(
      request: runRequest,
      actor: actor,
      sessionID: sessionID,
      correlationID: taskID,
      causationID: taskID
    )

    try await consume(stream: stream, taskID: taskID, plan: plan, context: context)
  }

  private func consume(
    stream: AsyncThrowingStream<ClaudeNormalizedEvent, Error>,
    taskID: UUID,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    var iterator = stream.makeAsyncIterator()
    while true {
      await context.checkCancellation()
      guard !(await context.isCancelled) else {
        throw AuraError.taskCancelled(taskID)
      }
      let next: ClaudeNormalizedEvent?
      do {
        next = try await iterator.next()
      } catch let error as AuraError {
        throw error
      } catch {
        throw AuraError.claudeError("claude stream failed: \(error)")
      }
      guard let event = next else { return }
      try await handle(event: event, plan: plan, context: context)
    }
  }

  private func handle(
    event: ClaudeNormalizedEvent,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    switch event {
    case .approvalDecision(_, let allowed, let reason) where !allowed:
      throw AuraError.claudeError(reason ?? "claude run denied by policy")
    case .message(let role, let text, _):
      await context.reportProgress(
        completedSteps: 0, totalSteps: plan.totalSteps,
        currentStepDescription: "\(role): \(text.prefix(120))")
    case .turnFailed(let message, _):
      throw AuraError.claudeError(message ?? "claude turn failed")
    case .claudeError(let message):
      throw AuraError.claudeError(message)
    case .budgetExceeded(let kind, let limit, let observed):
      throw AuraError.claudeError(
        "claude budget exceeded: \(kind) limit=\(limit) observed=\(observed)")
    case .turnCompleted(let resultText, _, _, _, _, _):
      await context.reportProgress(
        completedSteps: 1, totalSteps: plan.totalSteps,
        currentStepDescription: "Claude turn completed: \(resultText.prefix(120))")
    default:
      break
    }
  }
}
