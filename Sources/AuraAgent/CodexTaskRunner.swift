import AuraCore
import AuraTasks
import Foundation

/// Runs a Codex CLI turn as a durable `AuraTasks` task.
///
/// There is no type-based runner registry in `AuraTaskEngine` — whoever
/// creates a Codex-driven `TaskRequest` passes a `CodexTaskRunner` instance
/// explicitly to `engine.enqueue(request:runner:)`. Working directory and
/// sandbox tier are read from `TaskRequest.context`'s existing free-form
/// dictionary, so no changes to `AuraTasks` were needed for this phase.
public struct CodexTaskRunner: TaskRunner {
  /// `TaskRequest.context` key for the Codex run's working directory.
  public static let workingDirectoryContextKey = "codex.workingDirectory"
  /// `TaskRequest.context` key for the Codex sandbox tier
  /// (`CodexSandboxTier.rawValue`).
  public static let sandboxContextKey = "codex.sandbox"

  private let adapter: CodexAdapter
  private let actor: ActorID
  private let sessionID: UUID
  private let defaultWorkingDirectory: String
  private let defaultSandbox: CodexSandboxTier

  public init(
    adapter: CodexAdapter,
    actor: ActorID = .agentCodex,
    sessionID: UUID,
    defaultWorkingDirectory: String,
    defaultSandbox: CodexSandboxTier = .readOnly
  ) {
    self.adapter = adapter
    self.actor = actor
    self.sessionID = sessionID
    self.defaultWorkingDirectory = defaultWorkingDirectory
    self.defaultSandbox = defaultSandbox
  }

  /// A single `codex exec` turn is opaque ahead of time, so this always
  /// reports one step.
  public func plan(for task: TaskRequest) async throws(AuraError) -> TaskPlan {
    TaskPlan(totalSteps: 1, stepDescriptions: ["Run Codex CLI turn"])
  }

  public func execute(
    taskID: UUID,
    request: TaskRequest,
    plan: TaskPlan,
    context: TaskExecutionContext
  ) async throws(AuraError) {
    let workingDirectory =
      request.context[Self.workingDirectoryContextKey] ?? defaultWorkingDirectory
    let sandbox =
      request.context[Self.sandboxContextKey].flatMap(CodexSandboxTier.init(rawValue:))
      ?? defaultSandbox

    let runRequest = CodexRunRequest(
      prompt: request.objective,
      workingDirectory: workingDirectory,
      sandbox: sandbox
    )

    let stream = await adapter.run(
      request: runRequest,
      actor: actor,
      sessionID: sessionID,
      correlationID: taskID,
      causationID: taskID
    )

    var iterator = stream.makeAsyncIterator()
    while true {
      await context.checkCancellation()
      if await context.isCancelled {
        throw AuraError.taskCancelled(taskID)
      }

      let next: CodexNormalizedEvent?
      do {
        next = try await iterator.next()
      } catch let error as AuraError {
        throw error
      } catch {
        throw AuraError.codexError("codex stream failed: \(error)")
      }
      guard let event = next else { break }

      switch event {
      case .approvalDecision(_, let allowed, let reason):
        if !allowed {
          throw AuraError.codexError(reason ?? "codex run denied by policy")
        }
      case .agentText(let role, let text, _):
        await context.reportProgress(
          completedSteps: 0, totalSteps: plan.totalSteps,
          currentStepDescription: "\(role): \(text.prefix(120))"
        )
      case .turnFailed(let message):
        throw AuraError.codexError(message ?? "codex turn failed")
      case .codexError(let message):
        throw AuraError.codexError(message)
      case .budgetExceeded(let kind, let limit, let observed):
        throw AuraError.codexError(
          "codex budget exceeded: \(kind) limit=\(limit) observed=\(observed)")
      case .turnCompleted:
        await context.reportProgress(
          completedSteps: 1, totalSteps: plan.totalSteps,
          currentStepDescription: "Codex turn completed"
        )
      default:
        break
      }
    }
  }
}
