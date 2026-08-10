import AuraCore
import AuraPolicy
import AuraShell
import Foundation

/// Drives bounded multi-agent collaboration patterns over isolated `git
/// worktree`s, per the Multi-Agent Collaboration Protocol specification
/// (`docs/subsystems/16_MULTI_AGENT_PROTOCOL.md`).
///
/// Implements two of the four named patterns:
/// - **Planner → Implementer → Reviewer**, with a bounded review/correct
///   loop and evidence-based adjudication (reviewer verdict *and*, when
///   supplied, a real validation command — never the reviewer's verdict
///   alone, and never the implementer's own summary).
/// - **Specialist swarm**, running separable tasks concurrently, each in its
///   own worktree.
///
/// "Parallel proposals → adjudicator" and "Implementer → independent
/// reviewer → corrector" are named follow-ups, not implemented here — see
/// ADR-015. This orchestrator only ever spawns `OrchestratedAgentRunning`
/// role agents, never another orchestrator, so recursive orchestrator
/// spawning is unreachable by construction; the configured total
/// agent-invocation budget additionally bounds how many role agents any
/// single run may spawn.
public actor MultiAgentOrchestrator {
  public struct Configuration: Sendable, Equatable {
    /// Maximum number of review iterations (reviewer + corrector pass) before
    /// escalating instead of approving.
    public var maxReviewIterations: Int
    /// Hard ceiling on the total number of role-agent invocations a single
    /// run may make, across planner/implementer/reviewer/corrector passes —
    /// the recursive-spawn-prevention guard.
    public var maxTotalAgentInvocations: Int
    /// Hard ceiling on the number of tasks a single specialist-swarm call may
    /// run, independent of `maxTotalAgentInvocations`.
    public var maxSpecialistTasks: Int

    public init(
      maxReviewIterations: Int = 3,
      maxTotalAgentInvocations: Int = 20,
      maxSpecialistTasks: Int = 8
    ) {
      self.maxReviewIterations = maxReviewIterations
      self.maxTotalAgentInvocations = maxTotalAgentInvocations
      self.maxSpecialistTasks = maxSpecialistTasks
    }
  }

  private let worktreeManager: WorktreeManager
  private let policyEngine: PolicyEngine
  private let configuration: Configuration
  private let validationShell: AuraShell?
  private let eventBus: AuraEventBus

  public init(
    worktreeManager: WorktreeManager,
    policyEngine: PolicyEngine,
    configuration: Configuration = Configuration(),
    validationShell: AuraShell? = nil,
    eventBus: AuraEventBus = .shared
  ) {
    self.worktreeManager = worktreeManager
    self.policyEngine = policyEngine
    self.configuration = configuration
    self.validationShell = validationShell
    self.eventBus = eventBus
  }

  // MARK: - Planner → Implementer → Reviewer

  public func runPlannerImplementerReviewer(
    objective: String,
    acceptanceCriteria: [String] = [],
    repositoryRoot: String,
    baseRef: String = "HEAD",
    planner: any OrchestratedAgentRunning,
    implementer: any OrchestratedAgentRunning,
    reviewer: any OrchestratedAgentRunning,
    validationCommand: Command? = nil,
    actor: ActorID = .orchestrator,
    sessionID: UUID = UUID()
  ) async -> OrchestrationOutcome {
    let runID = UUID()
    var invocationCount = 0

    await emit(
      OrchestrationRunStartedEvent(
        runID: runID, pattern: .plannerImplementerReviewer, objective: objective,
        repositoryRoot: repositoryRoot),
      actor: actor, correlationID: runID, causationID: runID)

    if let budgetOutcome = await checkBudget(
      runID: runID, invocationCount: invocationCount, actor: actor)
    {
      await completeRun(runID: runID, outcome: budgetOutcome, iterations: 0, actor: actor)
      return budgetOutcome
    }

    // 1. Planner — read-only, against the repository root itself.
    invocationCount += 1
    await emit(
      OrchestrationAgentInvokedEvent(
        runID: runID, role: .planner, backendName: planner.backendName,
        invocationNumber: invocationCount),
      actor: actor, correlationID: runID, causationID: runID)

    let plannerResult = await Self.runToCompletion(
      agent: planner,
      objective: Self.plannerPrompt(objective: objective, acceptanceCriteria: acceptanceCriteria),
      workingDirectory: repositoryRoot, writable: false, actor: actor, sessionID: sessionID,
      correlationID: runID, causationID: runID)

    let planText: String
    switch plannerResult {
    case .failed(let reason):
      let outcome = OrchestrationOutcome.failed(reason: "planner: \(reason)")
      await completeRun(runID: runID, outcome: outcome, iterations: 0, actor: actor)
      return outcome
    case .succeeded(let text):
      planText = text
    }

    if Task.isCancelled {
      let outcome = OrchestrationOutcome.failed(reason: "orchestration run cancelled")
      await completeRun(runID: runID, outcome: outcome, iterations: 0, actor: actor)
      return outcome
    }

    // 2. Prepare an isolated worktree for the implementer/reviewer/corrector.
    let handle: WorktreeHandle
    do {
      handle = try await worktreeManager.prepareWorktree(
        taskID: runID, repositoryRoot: repositoryRoot, baseRef: baseRef, actor: actor,
        sessionID: sessionID)
    } catch {
      let outcome = OrchestrationOutcome.failed(
        reason: "worktree preparation failed: \(error.localizedDescription)")
      await completeRun(runID: runID, outcome: outcome, iterations: 0, actor: actor)
      return outcome
    }

    // 3. Implementer — writable, inside the worktree.
    if let budgetOutcome = await checkBudget(
      runID: runID, invocationCount: invocationCount, actor: actor)
    {
      await completeRun(runID: runID, outcome: budgetOutcome, iterations: 0, actor: actor)
      return budgetOutcome
    }
    invocationCount += 1
    await emit(
      OrchestrationAgentInvokedEvent(
        runID: runID, role: .implementer, backendName: implementer.backendName,
        invocationNumber: invocationCount),
      actor: actor, correlationID: runID, causationID: runID)

    let firstImplementResult = await Self.runToCompletion(
      agent: implementer,
      objective: Self.implementerPrompt(
        objective: objective, plan: planText, acceptanceCriteria: acceptanceCriteria),
      workingDirectory: handle.path, writable: true, actor: actor, sessionID: sessionID,
      correlationID: runID, causationID: runID)

    if case .failed(let reason) = firstImplementResult {
      let outcome = OrchestrationOutcome.failed(
        reason: Self.failureReason("implementer: \(reason)", handle: handle))
      await completeRun(runID: runID, outcome: outcome, iterations: 0, actor: actor)
      return outcome
    }

    // 4. Bounded review / correct loop, evidence-based adjudication.
    var conflicts: [OrchestrationConflict] = []
    var iteration = 0

    while iteration < configuration.maxReviewIterations {
      iteration += 1

      if Task.isCancelled {
        let outcome = OrchestrationOutcome.failed(
          reason: Self.failureReason("orchestration run cancelled", handle: handle))
        await completeRun(runID: runID, outcome: outcome, iterations: iteration, actor: actor)
        return outcome
      }

      let diffText =
        (try? await worktreeManager.diff(
          taskID: runID, actor: actor, sessionID: sessionID)) ?? "(diff unavailable)"

      var validation: ValidationOutcome?
      if let validationCommand {
        validation = await runValidation(
          command: validationCommand, workingDirectory: handle.path, actor: actor,
          sessionID: sessionID, correlationID: runID)
      }

      if let budgetOutcome = await checkBudget(
        runID: runID, invocationCount: invocationCount, actor: actor)
      {
        await completeRun(runID: runID, outcome: budgetOutcome, iterations: iteration, actor: actor)
        return budgetOutcome
      }
      invocationCount += 1
      await emit(
        OrchestrationAgentInvokedEvent(
          runID: runID, role: .reviewer, backendName: reviewer.backendName,
          invocationNumber: invocationCount),
        actor: actor, correlationID: runID, causationID: runID)

      let reviewResult = await Self.runToCompletion(
        agent: reviewer,
        objective: Self.reviewerPrompt(
          objective: objective, acceptanceCriteria: acceptanceCriteria, diff: diffText,
          validation: validation),
        workingDirectory: handle.path, writable: false, actor: actor, sessionID: sessionID,
        correlationID: runID, causationID: runID)

      switch reviewResult {
      case .failed(let reason):
        let outcome = OrchestrationOutcome.failed(
          reason: Self.failureReason("reviewer: \(reason)", handle: handle))
        await completeRun(runID: runID, outcome: outcome, iterations: iteration, actor: actor)
        return outcome

      case .succeeded(let reviewText):
        let verdict = ReviewVerdictParser.parse(reviewText)
        let reviewerApproved: Bool
        if case .approve = verdict { reviewerApproved = true } else { reviewerApproved = false }
        let evidenceApproved = reviewerApproved && (validation?.passed ?? true)

        if evidenceApproved {
          let outcome = OrchestrationOutcome.approved(
            worktreePath: handle.path, branch: handle.branch, iterations: iteration)
          await completeRun(runID: runID, outcome: outcome, iterations: iteration, actor: actor)
          return outcome
        }

        conflicts.append(
          OrchestrationConflict(
            iteration: iteration, verdict: verdict, validationPassed: validation?.passed))
        await emit(
          OrchestrationConflictRecordedEvent(
            runID: runID, iteration: iteration, reviewerApproved: reviewerApproved,
            reviewerReason: Self.reasonText(for: verdict), validationPassed: validation?.passed),
          actor: actor, correlationID: runID, causationID: runID)

        guard iteration < configuration.maxReviewIterations else {
          break
        }

        // Corrector pass: address reviewer feedback, then loop back to review.
        if let budgetOutcome = await checkBudget(
          runID: runID, invocationCount: invocationCount, actor: actor)
        {
          await completeRun(
            runID: runID, outcome: budgetOutcome, iterations: iteration, actor: actor)
          return budgetOutcome
        }
        invocationCount += 1
        await emit(
          OrchestrationAgentInvokedEvent(
            runID: runID, role: .implementer, backendName: implementer.backendName,
            invocationNumber: invocationCount),
          actor: actor, correlationID: runID, causationID: runID)

        let correctorResult = await Self.runToCompletion(
          agent: implementer,
          objective: Self.correctorPrompt(
            objective: objective, feedback: Self.reasonText(for: verdict), validation: validation),
          workingDirectory: handle.path, writable: true, actor: actor, sessionID: sessionID,
          correlationID: runID, causationID: runID)

        if case .failed(let reason) = correctorResult {
          let outcome = OrchestrationOutcome.failed(
            reason: Self.failureReason("corrector: \(reason)", handle: handle))
          await completeRun(runID: runID, outcome: outcome, iterations: iteration, actor: actor)
          return outcome
        }
      }
    }

    let outcome = OrchestrationOutcome.escalated(
      worktreePath: handle.path, branch: handle.branch, iterations: iteration,
      conflicts: conflicts)
    await emit(
      OrchestrationEscalatedEvent(
        runID: runID, iterations: iteration, conflictCount: conflicts.count),
      actor: actor, correlationID: runID, causationID: runID)
    await completeRun(runID: runID, outcome: outcome, iterations: iteration, actor: actor)
    return outcome
  }

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
        "specialist swarm size \(tasks.count) exceeds configured maximum \(configuration.maxSpecialistTasks)"
      return tasks.map {
        SpecialistResult(taskID: $0.taskID, outcome: .budgetExceeded(reason: reason))
      }
    }

    return await withTaskGroup(of: SpecialistResult.self) { group in
      for task in tasks {
        group.addTask {
          let agent = agentForTask(task)
          let outcome = await self.runSingleSpecialistTask(
            task: task, agent: agent, repositoryRoot: repositoryRoot, baseRef: baseRef,
            validationCommand: validationCommand, actor: actor, sessionID: sessionID)
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

  private func runSingleSpecialistTask(
    task: SpecialistTask,
    agent: any OrchestratedAgentRunning,
    repositoryRoot: String,
    baseRef: String,
    validationCommand: Command?,
    actor: ActorID,
    sessionID: UUID
  ) async -> OrchestrationOutcome {
    await emit(
      OrchestrationRunStartedEvent(
        runID: task.taskID, pattern: .specialistSwarm, objective: task.objective,
        repositoryRoot: repositoryRoot),
      actor: actor, correlationID: task.taskID, causationID: task.taskID)

    let handle: WorktreeHandle
    do {
      handle = try await worktreeManager.prepareWorktree(
        taskID: task.taskID, repositoryRoot: repositoryRoot, baseRef: baseRef, actor: actor,
        sessionID: sessionID)
    } catch {
      let outcome = OrchestrationOutcome.failed(
        reason: "worktree preparation failed: \(error.localizedDescription)")
      await completeRun(runID: task.taskID, outcome: outcome, iterations: 0, actor: actor)
      return outcome
    }

    await emit(
      OrchestrationAgentInvokedEvent(
        runID: task.taskID, role: .specialist, backendName: agent.backendName,
        invocationNumber: 1),
      actor: actor, correlationID: task.taskID, causationID: task.taskID)

    let result = await Self.runToCompletion(
      agent: agent, objective: task.objective, workingDirectory: handle.path, writable: true,
      actor: actor, sessionID: sessionID, correlationID: task.taskID, causationID: task.taskID)

    let outcome: OrchestrationOutcome
    switch result {
    case .failed(let reason):
      outcome = .failed(reason: reason)
    case .succeeded:
      var validationPassed = true
      if let validationCommand {
        let validation = await runValidation(
          command: validationCommand, workingDirectory: handle.path, actor: actor,
          sessionID: sessionID, correlationID: task.taskID)
        validationPassed = validation?.passed ?? true
      }
      outcome =
        validationPassed
        ? .approved(worktreePath: handle.path, branch: handle.branch, iterations: 1)
        : .failed(reason: "validation command failed")
    }

    await completeRun(runID: task.taskID, outcome: outcome, iterations: 1, actor: actor)
    return outcome
  }

  // MARK: - Budget guard

  private func checkBudget(
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

  // MARK: - Validation command

  private func runValidation(
    command: Command,
    workingDirectory: String,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID
  ) async -> ValidationOutcome? {
    guard let validationShell else { return nil }

    let policyRequest = PolicyEvaluationRequest(
      capability: .shellExec,
      actor: actor,
      target: PolicyTarget(
        directoryPath: workingDirectory, command: command.executable,
        arguments: command.arguments),
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: correlationID
    )
    let decision = await policyEngine.evaluate(policyRequest)
    guard case .allow = decision else {
      return ValidationOutcome(passed: false, exitCode: -1, outputTail: "denied by policy")
    }

    let scoped = Command(
      executable: command.executable,
      arguments: command.arguments,
      workingDirectory: workingDirectory,
      environment: command.environment,
      timeoutSeconds: command.timeoutSeconds,
      expectedExitCodes: command.expectedExitCodes,
      riskTier: command.riskTier,
      standardInputText: command.standardInputText,
      trailingArgument: command.trailingArgument
    )
    let result = await validationShell.execute(
      command: scoped, actor: actor, sessionID: sessionID, correlationID: correlationID,
      causationID: correlationID)

    switch result {
    case .success(let processResult):
      let combined = processResult.stdout + "\n" + processResult.stderr
      return ValidationOutcome(
        passed: processResult.exitCode == 0,
        exitCode: processResult.exitCode,
        outputTail: String(combined.suffix(2000)))
    case .failure(let error):
      return ValidationOutcome(passed: false, exitCode: -1, outputTail: error.localizedDescription)
    }
  }

  // MARK: - Prompts

  private static func plannerPrompt(objective: String, acceptanceCriteria: [String]) -> String {
    """
    You are the PLANNER in a bounded multi-agent workflow. You are read-only \
    — do not write or modify any files. Produce a concise, concrete \
    implementation plan for the following objective.

    Objective: \(objective)

    Acceptance criteria:
    \(bulletList(acceptanceCriteria))

    Respond with the plan only.
    """
  }

  private static func implementerPrompt(
    objective: String, plan: String, acceptanceCriteria: [String]
  ) -> String {
    """
    You are the IMPLEMENTER in a bounded multi-agent workflow. Make the \
    necessary changes directly in the current working directory to satisfy \
    the objective below, following the plan.

    Objective: \(objective)

    Plan:
    \(plan)

    Acceptance criteria:
    \(bulletList(acceptanceCriteria))
    """
  }

  private static func reviewerPrompt(
    objective: String, acceptanceCriteria: [String], diff: String, validation: ValidationOutcome?
  ) -> String {
    let validationSection: String
    if let validation {
      validationSection = """
        Validation command result: \(validation.passed ? "PASSED" : "FAILED") (exit code \(validation.exitCode))
        \(validation.outputTail)
        """
    } else {
      validationSection = "No validation command was run."
    }

    return """
      You are the REVIEWER in a bounded multi-agent workflow. You are \
      read-only — do not modify any files. Adjudicate based on tests, \
      security, specification compliance, simplicity, and maintainability. \
      Do not rely on any summary from the implementer — base your verdict \
      only on the diff and validation result shown below.

      Objective: \(objective)

      Acceptance criteria:
      \(bulletList(acceptanceCriteria))

      Diff:
      \(diff)

      \(validationSection)

      End your response with exactly one line, and nothing after it:
      "VERDICT: APPROVE" if the change satisfies the objective and acceptance \
      criteria, or "VERDICT: REQUEST_CHANGES: <reason>" otherwise.
      """
  }

  private static func correctorPrompt(
    objective: String, feedback: String?, validation: ValidationOutcome?
  ) -> String {
    let validationSection =
      validation.map { "Validation command output:\n\($0.outputTail)" } ?? ""
    return """
      You are the IMPLEMENTER addressing reviewer feedback in a bounded \
      multi-agent workflow. Make the necessary changes directly in the \
      current working directory.

      Objective: \(objective)

      Reviewer feedback: \(feedback ?? "no reason given")

      \(validationSection)
      """
  }

  /// Embeds the worktree path/branch in a failure reason so a caller can
  /// still find and inspect (or clean up) work already done by the time a
  /// later role fails — a `.failed` outcome loses this otherwise, since only
  /// `.approved`/`.escalated` carry `worktreePath`/`branch`.
  private static func failureReason(_ reason: String, handle: WorktreeHandle) -> String {
    "\(reason) (worktree: \(handle.path), branch: \(handle.branch))"
  }

  private static func bulletList(_ items: [String]) -> String {
    items.isEmpty ? "(none specified)" : items.map { "- \($0)" }.joined(separator: "\n")
  }

  private static func reasonText(for verdict: ReviewVerdict) -> String? {
    switch verdict {
    case .approve:
      return nil
    case .requestChanges(let reason):
      return reason
    case .unparseable:
      return "reviewer response did not contain a recognizable VERDICT marker"
    }
  }

  // MARK: - Role agent execution

  private enum RoleRunResult {
    case succeeded(text: String)
    case failed(reason: String)
  }

  private static func runToCompletion(
    agent: any OrchestratedAgentRunning,
    objective: String,
    workingDirectory: String,
    writable: Bool,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> RoleRunResult {
    let stream = await agent.run(
      objective: objective, workingDirectory: workingDirectory, writable: writable, actor: actor,
      sessionID: sessionID, correlationID: correlationID, causationID: causationID)

    var textParts: [String] = []
    var failureReason: String?
    var sawTurnCompleted = false

    do {
      for try await event in stream {
        switch event {
        case .text(_, let content):
          textParts.append(content)
        case .approvalDenied(let reason):
          failureReason = "denied by policy: \(reason ?? "no reason given")"
        case .turnCompleted:
          sawTurnCompleted = true
        case .turnFailed(let message):
          failureReason = message ?? "turn failed"
        case .budgetExceeded(let kind, let limit, let observed):
          failureReason = "budget exceeded: \(kind) limit=\(limit) observed=\(observed)"
        }
      }
    } catch {
      failureReason = "\(error)"
    }

    if let failureReason {
      return .failed(reason: failureReason)
    }
    guard sawTurnCompleted else {
      return .failed(reason: "agent stream ended without a completion signal")
    }
    return .succeeded(text: textParts.joined(separator: "\n"))
  }

  // MARK: - Completion audit

  private func completeRun(
    runID: UUID, outcome: OrchestrationOutcome, iterations: Int, actor: ActorID
  ) async {
    let outcomeType: OrchestrationRunCompletedEvent.Outcome
    let summary: String
    switch outcome {
    case .approved(let path, let branch, _):
      outcomeType = .approved
      summary = "approved: \(path) (\(branch))"
    case .escalated(let path, let branch, _, let conflicts):
      outcomeType = .escalated
      summary = "escalated after \(conflicts.count) conflict(s): \(path) (\(branch))"
    case .failed(let reason):
      outcomeType = .failed
      summary = reason
    case .budgetExceeded(let reason):
      outcomeType = .budgetExceeded
      summary = reason
    }
    await emit(
      OrchestrationRunCompletedEvent(
        runID: runID, outcome: outcomeType, iterations: iterations, summary: summary),
      actor: actor, correlationID: runID, causationID: runID)
  }

  private func emit<Payload: EventPayload>(
    _ payload: Payload,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}
