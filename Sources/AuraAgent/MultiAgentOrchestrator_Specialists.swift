import AuraCore
import AuraPolicy
import AuraShell
import Foundation

struct SpecialistRunContext: Sendable {
  let repositoryRoot: String
  let baseRef: String
  let validationCommand: Command?
  let actor: ActorID
  let sessionID: UUID
}

extension MultiAgentOrchestrator {
  // MARK: - Specialist swarm

  /// Run separable tasks concurrently, each given its own isolated worktree
  /// and agent. There is no cross-task adjudication — worktree isolation is
  /// what makes this pattern safe to use in the first place, per the
  /// protocol spec ("use only when tasks are separable and worktrees
  /// prevent conflicts").
  public func runSpecialistSwarm(
    tasks: [SpecialistTask],
    repositoryRoot: String,
    baseRef: String = "HEAD",
    agentForTask: @escaping @Sendable (SpecialistTask) -> any OrchestratedAgentRunning,
    validationCommand: Command? = nil,
    actor: ActorID = .orchestrator,
    sessionID: UUID = UUID()
  ) async -> [SpecialistResult] {
    guard tasks.count <= configuration.maxSpecialistTasks else {
      let reason =
        "specialist swarm size \(tasks.count) exceeds configured maximum "
        + "\(configuration.maxSpecialistTasks)"
      return tasks.map {
        SpecialistResult(taskID: $0.taskID, outcome: .budgetExceeded(reason: reason))
      }
    }

    let runContext = SpecialistRunContext(
      repositoryRoot: repositoryRoot,
      baseRef: baseRef,
      validationCommand: validationCommand,
      actor: actor,
      sessionID: sessionID)
    return await withTaskGroup(of: SpecialistResult.self) { group in
      for task in tasks {
        group.addTask {
          let agent = agentForTask(task)
          let outcome = await self.runSingleSpecialistTask(
            task: task, agent: agent, context: runContext)
          return SpecialistResult(taskID: task.taskID, outcome: outcome)
        }
      }
      var results: [SpecialistResult] = []
      for await result in group {
        results.append(result)
      }
      return results
    }
  }

  func runSingleSpecialistTask(
    task: SpecialistTask,
    agent: any OrchestratedAgentRunning,
    context: SpecialistRunContext
  ) async -> OrchestrationOutcome {
    await emit(
      OrchestrationRunStartedEvent(
        runID: task.taskID, pattern: .specialistSwarm, objective: task.objective,
        repositoryRoot: context.repositoryRoot),
      actor: context.actor, correlationID: task.taskID, causationID: task.taskID)

    let handle: WorktreeHandle
    do {
      handle = try await worktreeManager.prepareWorktree(
        taskID: task.taskID, repositoryRoot: context.repositoryRoot, baseRef: context.baseRef,
        actor: context.actor, sessionID: context.sessionID)
    } catch {
      let outcome = OrchestrationOutcome.failed(
        reason: "worktree preparation failed: \(error.localizedDescription)")
      await completeRun(runID: task.taskID, outcome: outcome, iterations: 0, actor: context.actor)
      return outcome
    }

    await emit(
      OrchestrationAgentInvokedEvent(
        runID: task.taskID, role: .specialist, backendName: agent.backendName,
        invocationNumber: 1),
      actor: context.actor, correlationID: task.taskID, causationID: task.taskID)

    let outcome = await specialistOutcome(
      task: task, agent: agent, context: context, handle: handle)

    await completeRun(runID: task.taskID, outcome: outcome, iterations: 1, actor: context.actor)
    return outcome
  }

  private func specialistOutcome(
    task: SpecialistTask,
    agent: any OrchestratedAgentRunning,
    context: SpecialistRunContext,
    handle: WorktreeHandle
  ) async -> OrchestrationOutcome {
    let result = await Self.runToCompletion(
      agent: agent,
      request: OrchestratedAgentRunRequest(
        objective: task.objective, workingDirectory: handle.path, writable: true,
        actor: context.actor, sessionID: context.sessionID,
        correlationID: task.taskID, causationID: task.taskID))
    guard case .succeeded = result else {
      if case .failed(let reason) = result { return .failed(reason: reason) }
      return .failed(reason: "specialist agent ended without success")
    }
    let validationPassed: Bool
    if let validationCommand = context.validationCommand {
      let validation = await runValidation(
        command: validationCommand, workingDirectory: handle.path, actor: context.actor,
        sessionID: context.sessionID, correlationID: task.taskID)
      validationPassed = validation?.passed ?? true
    } else {
      validationPassed = true
    }
    return validationPassed
      ? .approved(worktreePath: handle.path, branch: handle.branch, iterations: 1)
      : .failed(reason: "validation command failed")
  }

  // MARK: - Budget guard

  func checkBudget(
    runID: UUID, invocationCount: Int, actor: ActorID
  ) async -> OrchestrationOutcome? {
    guard invocationCount < configuration.maxTotalAgentInvocations else {
      await emit(
        OrchestrationBudgetExceededEvent(
          runID: runID, limit: configuration.maxTotalAgentInvocations, observed: invocationCount),
        actor: actor, correlationID: runID, causationID: runID)
      return .budgetExceeded(
        reason:
          "agent invocation budget (\(configuration.maxTotalAgentInvocations)) exhausted")
    }
    return nil
  }
}
