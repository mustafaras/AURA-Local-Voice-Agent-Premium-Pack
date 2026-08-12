import AuraCore
import AuraTasks
import Foundation

/// Runs a Copilot CLI turn as a durable `AuraTasks` task. Mirrors
/// `CodexTaskRunner`/`ClaudeTaskRunner`.
///
/// There is no type-based runner registry in `AuraTaskEngine` — whoever
/// creates a Copilot-driven `TaskRequest` passes a `CopilotTaskRunner`
/// instance explicitly to `engine.enqueue(request:runner:)`. Working
/// directory and tool profile are read from `TaskRequest.context`'s existing
/// free-form dictionary, so no changes to `AuraTasks` were needed for this
/// phase.
public struct CopilotTaskRunner: TaskRunner {
  /// `TaskRequest.context` key for the Copilot run's working directory.
  public static let workingDirectoryContextKey = "copilot.workingDirectory"
  /// `TaskRequest.context` key for the Copilot tool profile
  /// (`CopilotToolProfile.rawValue`).
  public static let toolProfileContextKey = "copilot.toolProfile"

  private let adapter: CopilotAdapter
  private let actor: ActorID
  private let sessionID: UUID
  private let defaultWorkingDirectory: String
  private let defaultToolProfile: CopilotToolProfile

  public init(
    adapter: CopilotAdapter,
    actor: ActorID = .agentCopilot,
    sessionID: UUID,
    defaultWorkingDirectory: String,
    defaultToolProfile: CopilotToolProfile = .readOnly
  ) {
    self.adapter = adapter
    self.actor = actor
    self.sessionID = sessionID
    self.defaultWorkingDirectory = defaultWorkingDirectory
    self.defaultToolProfile = defaultToolProfile
  }

  /// A single `copilot -p` turn is opaque ahead of time, so this always
  /// reports one step.
  public func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan {
    TaskPlan(totalSteps: 1, stepDescriptions: ["Run Copilot CLI turn"])
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
      request.context[Self.toolProfileContextKey].flatMap(CopilotToolProfile.init(rawValue:))
      ?? defaultToolProfile

    let runRequest = CopilotRunRequest(
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
    stream: AsyncThrowingStream<CopilotNormalizedEvent, Error>,
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
      let next: CopilotNormalizedEvent?
      do {
        next = try await iterator.next()
      } catch let error as AuraError {
        throw error
      } catch {
        throw AuraError.copilotError("copilot stream failed: \(error)")
      }
      guard let event = next else { return }
      try await handle(event: event, plan: plan, context: context)
    }
  }

  private func handle(
    event: CopilotNormalizedEvent,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    switch event {
    case .approvalDecision(_, let allowed, let reason) where !allowed:
      throw AuraError.copilotError(reason ?? "copilot run denied by policy")
    case .copilotError(let message):
      throw AuraError.copilotError(message)
    case .message(let role, let content, _):
      await context.reportProgress(
        completedSteps: 0, totalSteps: plan.totalSteps,
        currentStepDescription: "\(role): \(content.prefix(120))")
    case .turnFailed(let message):
      throw AuraError.copilotError(message ?? "copilot turn failed")
    case .budgetExceeded(let kind, let limit, let observed):
      throw AuraError.copilotError(
        "copilot budget exceeded: \(kind) limit=\(limit) observed=\(observed)")
    case .turnCompleted(let exitCode, _, _, let filesModifiedCount, _, _):
      await context.reportProgress(
        completedSteps: 1, totalSteps: plan.totalSteps,
        currentStepDescription:
          "Copilot turn completed (exit \(exitCode), \(filesModifiedCount) files modified)")
    default:
      break
    }
  }
}
