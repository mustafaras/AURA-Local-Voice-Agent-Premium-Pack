import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

private enum ShellExecutionPreparation {
  case ready(Command, ToolExecutionContext)
  case outcome(IntentExecutionOutcome)
}

extension ToolRouter {
  // MARK: - Handlers

  func handleConverse(
    _ intent: TypedIntent,
    executionContext: ToolExecutionContext,
    dialogueContext: [DialogueContextItem]
  ) async -> IntentExecutionOutcome {
    let context =
      intent.turnContext
      ?? TurnContext(
        sessionID: executionContext.sessionID,
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID,
        activationSource: .text,
        actor: executionContext.actor,
        authority: .userUtterance,
        sensitivity: .sensitive)
    let response = await dialogueEngine.respond(
      to: intent,
      context: context,
      contextItems: dialogueContext)
    return .executed(summary: response.text, hasSpokenResponse: !response.text.isEmpty)
  }

  func resolveContract(for kind: IntentKind) async -> CapabilityManifest? {
    guard let id = capabilityID(for: kind) else { return nil }
    guard let manifest = await capabilityRegistry.resolveLatest(id: id) else { return nil }
    if case .ready = await capabilityRegistry.availability(qualifiedID: manifest.qualifiedID) {
      return manifest
    }
    return nil
  }

  func handleAppLifecycle(
    _ intent: TypedIntent,
    contract: CapabilityManifest,
    terminate: Bool,
    executionContext: ToolExecutionContext
  ) async -> IntentExecutionOutcome {
    guard let bundleID = intent.slotValue(IntentSlotName.bundleIdentifier) else {
      return .failed(reason: "missing \(IntentSlotName.bundleIdentifier) slot")
    }

    switch await resolvePolicy(
      intent, capability: contract.requiredCapability, target: PolicyTarget(appID: bundleID),
      executionContext: executionContext
    ) {
    case .blocked(let outcome): return outcome
    case .allowed: break
    }

    await emit(
      ToolInvokedEvent(intentID: intent.id, toolID: contract.id),
      correlationID: executionContext.correlationID,
      causationID: executionContext.causationID)
    do {
      if terminate {
        try await automation.quitApplication(bundleIdentifier: bundleID)
      } else {
        try await automation.activateApplication(bundleIdentifier: bundleID)
      }
      let summary = terminate ? "Quit \(bundleID)." : "Activated \(bundleID)."
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: contract.id, succeeded: true, summary: summary),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .executed(summary: summary, hasSpokenResponse: true)
    } catch {
      let summary =
        "Failed to \(terminate ? "quit" : "activate") \(bundleID): \(error.localizedDescription)"
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: contract.id, succeeded: false, summary: summary),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .failed(reason: summary)
    }
  }

  func handleShellExecute(
    _ intent: TypedIntent,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> IntentExecutionOutcome {
    switch await prepareShellExecution(
      intent, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    {
    case .outcome(let outcome):
      return outcome
    case .ready(let command, let executionContext):
      return await executeShellCommand(
        intent, command: command, executionContext: executionContext)
    }
  }

  private func prepareShellExecution(
    _ intent: TypedIntent,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> ShellExecutionPreparation {
    let executionContext = ToolExecutionContext(
      actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID)
    guard let executable = intent.slotValue(IntentSlotName.executable) else {
      return .outcome(.failed(reason: "missing \(IntentSlotName.executable) slot"))
    }
    let argumentsText = intent.slotValue(IntentSlotName.arguments) ?? ""
    let arguments =
      argumentsText.isEmpty
      ? [] : argumentsText.split(separator: " ").map(String.init)
    let command = Command(executable: executable, arguments: arguments)
    let commandText = ([executable] + arguments).joined(separator: " ")
    let isDestructive = destructivePatternMatchers.contains { regex in
      regex.firstMatch(
        in: commandText, range: NSRange(commandText.startIndex..., in: commandText)) != nil
    }
    let effectiveIntent = isDestructive ? intent.escalated(to: .shellDestructive) : intent
    let capability: Capability = isDestructive ? .shellExecDestructive : .shellExec
    let target = PolicyTarget(
      command: command.executable, arguments: command.arguments,
      environmentKeys: Array(command.environment.keys))
    switch await resolvePolicy(
      effectiveIntent, capability: capability, target: target, executionContext: executionContext)
    {
    case .blocked(let outcome): return .outcome(outcome)
    case .allowed: return .ready(command, executionContext)
    }
  }

  private func executeShellCommand(
    _ intent: TypedIntent,
    command: Command,
    executionContext: ToolExecutionContext
  ) async -> IntentExecutionOutcome {
    await emit(
      ToolInvokedEvent(intentID: intent.id, toolID: "shell.execute"),
      correlationID: executionContext.correlationID, causationID: executionContext.causationID)
    let result = await shell.execute(
      command: command, actor: executionContext.actor, sessionID: executionContext.sessionID,
      correlationID: executionContext.correlationID, causationID: executionContext.causationID)
    switch result {
    case .success(let processResult):
      let summary = "Command completed with exit code \(processResult.exitCode)."
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: "shell.execute",
          succeeded: processResult.exitCode == 0, summary: summary),
        correlationID: executionContext.correlationID, causationID: executionContext.causationID)
      return .executed(summary: summary, hasSpokenResponse: true)
    case .failure(let error):
      let summary = "Command failed: \(error.localizedDescription)"
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: "shell.execute", succeeded: false, summary: summary),
        correlationID: executionContext.correlationID, causationID: executionContext.causationID)
      return .failed(reason: summary)
    }
  }

  /// A `.codingAgentRun` intent is delegated asynchronously. In production,
  /// the R6 coordinator must first resolve an explicit VS Code workspace,
  /// verify backend readiness, and establish write isolation before enqueueing
  /// the durable task. Test-only harnesses may omit the coordinator to retain
  /// the historical enqueue fixture.
  func handleCodingAgentRun(
    _ intent: TypedIntent,
    correlationID: UUID,
    causationID: UUID
  ) async -> IntentExecutionOutcome {
    guard let objective = intent.slotValue(IntentSlotName.objective) else {
      return .failed(reason: "missing \(IntentSlotName.objective) slot")
    }
    let backend =
      intent.slotValue(IntentSlotName.backend) ?? configuration.defaultCodingAgentBackend
    guard AgentBackendTaskRunner.supportedBackends.contains(backend) else {
      return .failed(reason: "unsupported coding-agent backend: \(backend)")
    }

    if codingTaskCoordinator != nil {
      return await enqueueCoordinatedRun(
        intent, objective: objective, backend: backend,
        correlationID: correlationID, causationID: causationID)
    }
    return await enqueueFallbackRun(
      intent, objective: objective, backend: backend,
      correlationID: correlationID, causationID: causationID)
  }

  private func enqueueCoordinatedRun(
    _ intent: TypedIntent,
    objective: String,
    backend: String,
    correlationID: UUID,
    causationID: UUID
  ) async -> IntentExecutionOutcome {
    guard let codingTaskCoordinator, let backendID = AgentBackendID(rawValue: backend) else {
      return .failed(reason: "unsupported coding-agent backend: \(backend)")
    }
    let request = CodingTaskRequest(
      objective: objective, backend: backendID, mode: .writeCapable,
      context: [AgentBackendTaskRunner.backendContextKey: backend])
    await emit(
      ToolInvokedEvent(intentID: intent.id, toolID: "agent.codingAgentRun"),
      correlationID: correlationID, causationID: causationID)
    do {
      _ = try await codingTaskCoordinator.enqueue(
        request, actor: .intent, sessionID: intent.turnContext?.sessionID ?? UUID())
      return await codingRunOutcome(
        intent, succeeded: true,
        summary: "Started a \(backend) run for: \(objective).",
        correlationID: correlationID, causationID: causationID)
    } catch {
      return await codingRunOutcome(
        intent, succeeded: false,
        summary: "Failed to start \(backend) run: \(error.localizedDescription)",
        correlationID: correlationID, causationID: causationID)
    }
  }

  private func enqueueFallbackRun(
    _ intent: TypedIntent,
    objective: String,
    backend: String,
    correlationID: UUID,
    causationID: UUID
  ) async -> IntentExecutionOutcome {
    let request = TaskRequest(
      objective: objective, context: [AgentBackendTaskRunner.backendContextKey: backend])
    await emit(
      ToolInvokedEvent(intentID: intent.id, toolID: "agent.codingAgentRun"),
      correlationID: correlationID, causationID: causationID)
    do {
      _ = try await taskEngine.enqueue(request: request, runner: agentTaskRunner)
      return await codingRunOutcome(
        intent, succeeded: true,
        summary: "Started a \(backend) run for: \(objective).",
        correlationID: correlationID, causationID: causationID)
    } catch {
      return await codingRunOutcome(
        intent, succeeded: false,
        summary: "Failed to start \(backend) run: \(error.localizedDescription)",
        correlationID: correlationID, causationID: causationID)
    }
  }

  private func codingRunOutcome(
    _ intent: TypedIntent,
    succeeded: Bool,
    summary: String,
    correlationID: UUID,
    causationID: UUID
  ) async -> IntentExecutionOutcome {
    await emit(
      ToolResultEvent(
        intentID: intent.id, toolID: "agent.codingAgentRun",
        succeeded: succeeded, summary: summary),
      correlationID: correlationID, causationID: causationID)
    return succeeded ? .acknowledgedAsync(summary: summary) : .failed(reason: summary)
  }
}
