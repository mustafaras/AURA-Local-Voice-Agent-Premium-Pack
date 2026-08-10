import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

/// Superseded by `CapabilityManifest`/`CapabilityRegistry`
/// (`CapabilityRegistry.swift`, `InitialCapabilitySet.swift`) as of R3 —
/// see `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s completion gate,
/// "the registry is the sole production source for user-reachable tools."

/// Pluggable presenter for a `PolicyConfirmationChallenge` `ToolRouter`
/// itself raises (for the capabilities it, not an adapter, evaluates).
/// Mirrors `CodexApprovalPresenting` exactly, including its two production
/// fixtures' shape and doc-comment convention.
public protocol IntentConfirmationPresenting: Sendable {
  func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse
}

/// Confirmation presenter that always denies (safe default — this phase
/// has no real interactive voice/UI confirmation surface yet).
public struct IntentAlwaysDenyConfirmationPresenter: IntentConfirmationPresenting {
  public init() {}

  public func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse {
    PolicyConfirmationResponse(
      requestID: challenge.requestID, nonce: challenge.nonce, responseHash: challenge.expectedHash,
      accepted: false)
  }
}

/// Confirmation presenter that always allows — deterministic test fixture
/// only, never the production default.
public struct IntentAlwaysAllowConfirmationPresenter: IntentConfirmationPresenting {
  public init() {}

  public func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse {
    PolicyConfirmationResponse(
      requestID: challenge.requestID, nonce: challenge.nonce, responseHash: challenge.expectedHash,
      accepted: true)
  }
}

/// Outcome of routing one classified intent to its tool.
public enum IntentExecutionOutcome: Sendable, Equatable {
  case executed(summary: String, hasSpokenResponse: Bool)
  /// A coding-agent run was enqueued but not awaited — see `ToolRouter
  /// .handleCodingAgentRun`'s doc comment for why a synchronous wait would
  /// exceed `Conversation`'s think-timeout.
  case acknowledgedAsync(summary: String)
  case blockedByPolicy(reason: String)
  case blockedPendingConfirmationDenied
  case ambiguous(clarifyingQuestion: String)
  case failed(reason: String)
}

extension IntentExecutionOutcome {
  fileprivate var isVerifiedExecution: Bool {
    if case .executed = self { return true }
    return false
  }

  fileprivate var summaryForVerification: String {
    switch self {
    case .executed(let summary, _): return summary
    case .acknowledgedAsync(let summary): return summary
    case .blockedByPolicy(let reason): return reason
    case .blockedPendingConfirmationDenied: return "confirmation denied"
    case .ambiguous(let question): return question
    case .failed(let reason): return reason
    }
  }
}

/// Implements steps 7–8 of `docs/subsystems/08_INTENT_ENGINE.md`'s pipeline
/// ("select handler," "produce an inspectable execution plan") plus `09_
/// TOOL_ROUTER.md`'s router behaviors (evaluate policy, record proposal/
/// result). Every branch that does not `enforcesPolicyInternally` calls
/// `PolicyEngine.evaluate` itself before touching a backend subsystem —
/// `AuraShell`/`AuraAutomation` never do this on their own.
public actor ToolRouter {
  private let policyEngine: PolicyEngine
  private let automation: AuraAutomation
  private let shell: AuraShell
  private let taskEngine: AuraTaskEngine
  private let agentTaskRunner: AgentBackendTaskRunner
  private let codingTaskCoordinator: CodingTaskCoordinator?
  /// The sole production source of capability contracts — replaces the
  /// prior phase's static `ToolRegistry` per `04_R3_CAPABILITY_REGISTRY_AND
  /// _PLANNER.prompt.md`'s completion gate. `IntentKind` still identifies
  /// what the classifier/dialogue layer produced; `capabilityID(for:)`
  /// below is the only place that maps a kind to the registry's namespaced
  /// capability ID, so adding a capability never requires widening this
  /// router's own dispatch switch.
  private let capabilityRegistry: CapabilityRegistry
  private let confirmationPresenter: any IntentConfirmationPresenting
  private let eventBus: AuraEventBus
  private let configuration: IntentEngineConfiguration
  private let dialogueEngine: DialogueEngine
  private let destructivePatternMatchers: [NSRegularExpression]

  public init(
    policyEngine: PolicyEngine,
    automation: AuraAutomation,
    shell: AuraShell,
    taskEngine: AuraTaskEngine,
    agentTaskRunner: AgentBackendTaskRunner,
    capabilityRegistry: CapabilityRegistry,
    confirmationPresenter: any IntentConfirmationPresenting,
    eventBus: AuraEventBus,
    configuration: IntentEngineConfiguration,
    dialogueEngine: DialogueEngine = DialogueEngine(),
    codingTaskCoordinator: CodingTaskCoordinator? = nil
  ) {
    self.policyEngine = policyEngine
    self.automation = automation
    self.shell = shell
    self.taskEngine = taskEngine
    self.agentTaskRunner = agentTaskRunner
    self.codingTaskCoordinator = codingTaskCoordinator
    self.capabilityRegistry = capabilityRegistry
    self.confirmationPresenter = confirmationPresenter
    self.eventBus = eventBus
    self.configuration = configuration
    self.dialogueEngine = dialogueEngine
    self.destructivePatternMatchers = configuration.destructiveShellPatterns.compactMap {
      try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
    }
  }

  /// The one place an `IntentKind` maps to a registry capability ID.
  private func capabilityID(for kind: IntentKind) -> String? {
    switch kind {
    case .converse: return InitialCapabilitySet.converse.id
    case .appActivate: return InitialCapabilitySet.appActivate.id
    case .appTerminate: return InitialCapabilitySet.appTerminate.id
    case .shellExecute: return InitialCapabilitySet.shellExecuteTyped.id
    case .codingAgentRun: return InitialCapabilitySet.codingAgentRun.id
    case .unknown: return nil
    }
  }

  /// Route using the immutable turn context so every backend call inherits
  /// the original session, actor, correlation, and causation metadata.
  public func route(
    _ intent: TypedIntent,
    context: TurnContext, dialogueContext: [DialogueContextItem] = []
  ) async -> IntentExecutionOutcome {
    let contract = await resolveContract(for: intent.kind)
    let routingContext = context.withBackendIDs(
      TurnBackendIDs(
        stt: context.backendIDs.stt,
        tts: context.backendIDs.tts,
        model: context.backendIDs.model,
        tool: contract?.id))
    let outcome = await route(
      intent.withTurnContext(routingContext),
      actor: context.actor,
      sessionID: context.sessionID,
      correlationID: routingContext.correlationID,
      causationID: routingContext.causationID,
      dialogueContext: dialogueContext)
    let verified = outcome.isVerifiedExecution
    _ = await policyEngine.completeAuthorizedExecution(
      context: routingContext,
      verified: verified,
      summary: outcome.summaryForVerification)
    return outcome
  }

  public func route(
    _ intent: TypedIntent,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    dialogueContext: [DialogueContextItem] = []
  ) async -> IntentExecutionOutcome {
    guard !intent.isAmbiguous, intent.kind != .unknown else {
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "ambiguous"), correlationID: correlationID,
        causationID: causationID)
      return .ambiguous(clarifyingQuestion: clarifyingQuestion(for: intent))
    }

    guard let contract = await resolveContract(for: intent.kind) else {
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "noToolRegistered"),
        correlationID: correlationID, causationID: causationID)
      return .failed(reason: "no tool registered for \(intent.kind.rawValue)")
    }

    await emit(
      IntentPlanGeneratedEvent(
        intentID: intent.id, toolID: contract.id,
        capabilityIdentifier: contract.requiredCapability.identifier),
      correlationID: correlationID, causationID: causationID)

    switch intent.kind {
    case .converse:
      return await handleConverse(
        intent,
        actor: actor,
        sessionID: sessionID,
        correlationID: correlationID,
        causationID: causationID,
        dialogueContext: dialogueContext)
    case .appActivate:
      return await handleAppLifecycle(
        intent, contract: contract, terminate: false, actor: actor, sessionID: sessionID,
        correlationID: correlationID, causationID: causationID)
    case .appTerminate:
      return await handleAppLifecycle(
        intent, contract: contract, terminate: true, actor: actor, sessionID: sessionID,
        correlationID: correlationID, causationID: causationID)
    case .shellExecute:
      return await handleShellExecute(
        intent, actor: actor, sessionID: sessionID, correlationID: correlationID,
        causationID: causationID)
    case .codingAgentRun:
      return await handleCodingAgentRun(
        intent, correlationID: correlationID, causationID: causationID)
    case .unknown:
      return .ambiguous(clarifyingQuestion: clarifyingQuestion(for: intent))
    }
  }

  // MARK: - Handlers

  private func handleConverse(
    _ intent: TypedIntent,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    dialogueContext: [DialogueContextItem]
  ) async -> IntentExecutionOutcome {
    let context =
      intent.turnContext
      ?? TurnContext(
        sessionID: sessionID,
        correlationID: correlationID,
        causationID: causationID,
        activationSource: .text,
        actor: actor,
        authority: .userUtterance,
        sensitivity: .sensitive)
    let response = await dialogueEngine.respond(
      to: intent,
      context: context,
      contextItems: dialogueContext)
    return .executed(summary: response.text, hasSpokenResponse: !response.text.isEmpty)
  }

  private func resolveContract(for kind: IntentKind) async -> CapabilityManifest? {
    guard let id = capabilityID(for: kind) else { return nil }
    guard let manifest = await capabilityRegistry.resolveLatest(id: id) else { return nil }
    if case .ready = await capabilityRegistry.availability(qualifiedID: manifest.qualifiedID) {
      return manifest
    }
    return nil
  }

  private func handleAppLifecycle(
    _ intent: TypedIntent,
    contract: CapabilityManifest,
    terminate: Bool,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> IntentExecutionOutcome {
    guard let bundleID = intent.slotValue(IntentSlotName.bundleIdentifier) else {
      return .failed(reason: "missing \(IntentSlotName.bundleIdentifier) slot")
    }

    switch await resolvePolicy(
      intent, capability: contract.requiredCapability, target: PolicyTarget(appID: bundleID),
      actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID
    ) {
    case .blocked(let outcome): return outcome
    case .allowed: break
    }

    await emit(
      ToolInvokedEvent(intentID: intent.id, toolID: contract.id), correlationID: correlationID,
      causationID: causationID)
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
        correlationID: correlationID, causationID: causationID)
      return .executed(summary: summary, hasSpokenResponse: true)
    } catch {
      let summary =
        "Failed to \(terminate ? "quit" : "activate") \(bundleID): \(error.localizedDescription)"
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: contract.id, succeeded: false, summary: summary),
        correlationID: correlationID, causationID: causationID)
      return .failed(reason: summary)
    }
  }

  private func handleShellExecute(
    _ intent: TypedIntent,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> IntentExecutionOutcome {
    guard let executable = intent.slotValue(IntentSlotName.executable) else {
      return .failed(reason: "missing \(IntentSlotName.executable) slot")
    }
    let argumentsText = intent.slotValue(IntentSlotName.arguments) ?? ""
    let arguments =
      argumentsText.isEmpty ? [] : argumentsText.split(separator: " ").map(String.init)
    let command = Command(executable: executable, arguments: arguments)

    let commandText = ([executable] + arguments).joined(separator: " ")
    let isDestructive = destructivePatternMatchers.contains { regex in
      regex.firstMatch(
        in: commandText, range: NSRange(commandText.startIndex..., in: commandText)) != nil
    }
    let effectiveIntent = isDestructive ? intent.escalated(to: .shellDestructive) : intent
    let capability: Capability = isDestructive ? .shellExecDestructive : .shellExec

    // Mirrors ShellPolicyAdapter.request's target shape; built directly
    // (not via ShellPolicyAdapter, which always hardcodes `.shellExec`)
    // since a destructive match must evaluate under a different capability.
    let target = PolicyTarget(
      command: command.executable, arguments: command.arguments,
      environmentKeys: Array(command.environment.keys))

    switch await resolvePolicy(
      effectiveIntent, capability: capability, target: target, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID
    ) {
    case .blocked(let outcome): return outcome
    case .allowed: break
    }

    await emit(
      ToolInvokedEvent(intentID: intent.id, toolID: "shell.execute"), correlationID: correlationID,
      causationID: causationID)
    let result = await shell.execute(
      command: command, actor: actor, sessionID: sessionID, correlationID: correlationID,
      causationID: causationID)
    switch result {
    case .success(let processResult):
      let summary = "Command completed with exit code \(processResult.exitCode)."
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: "shell.execute",
          succeeded: processResult.exitCode == 0, summary: summary),
        correlationID: correlationID, causationID: causationID)
      return .executed(summary: summary, hasSpokenResponse: true)
    case .failure(let error):
      let summary = "Command failed: \(error.localizedDescription)"
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: "shell.execute", succeeded: false, summary: summary),
        correlationID: correlationID, causationID: causationID)
      return .failed(reason: summary)
    }
  }

  /// A `.codingAgentRun` intent is delegated asynchronously. In production,
  /// the R6 coordinator must first resolve an explicit VS Code workspace,
  /// verify backend readiness, and establish write isolation before enqueueing
  /// the durable task. Test-only harnesses may omit the coordinator to retain
  /// the historical enqueue fixture.
  private func handleCodingAgentRun(
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

    if let codingTaskCoordinator {
      guard let backendID = AgentBackendID(rawValue: backend) else {
        return .failed(reason: "unsupported coding-agent backend: \(backend)")
      }
      let request = CodingTaskRequest(
        objective: objective,
        backend: backendID,
        mode: .writeCapable,
        context: [AgentBackendTaskRunner.backendContextKey: backend])

      await emit(
        ToolInvokedEvent(intentID: intent.id, toolID: "agent.codingAgentRun"),
        correlationID: correlationID, causationID: causationID)
      do {
        _ = try await codingTaskCoordinator.enqueue(
          request, actor: .intent, sessionID: intent.turnContext?.sessionID ?? UUID())
        let summary = "Started a " + backend + " run for: " + objective + "."
        await emit(
          ToolResultEvent(
            intentID: intent.id, toolID: "agent.codingAgentRun", succeeded: true, summary: summary),
          correlationID: correlationID, causationID: causationID)
        return .acknowledgedAsync(summary: summary)
      } catch {
        let summary = "Failed to start " + backend + " run: " + error.localizedDescription
        await emit(
          ToolResultEvent(
            intentID: intent.id, toolID: "agent.codingAgentRun", succeeded: false, summary: summary),
          correlationID: correlationID, causationID: causationID)
        return .failed(reason: summary)
      }
    }

    // No working-directory context key is set here: each per-backend
    // `TaskRunner` (`CodexTaskRunner`/etc.) already falls back to its own
    // `defaultWorkingDirectory`, constructed from this same configuration
    // value in `AuraKernel` — setting it again here would be inert.
    let request = TaskRequest(
      objective: objective,
      context: [AgentBackendTaskRunner.backendContextKey: backend]
    )

    await emit(
      ToolInvokedEvent(intentID: intent.id, toolID: "agent.codingAgentRun"),
      correlationID: correlationID, causationID: causationID)
    do {
      _ = try await taskEngine.enqueue(request: request, runner: agentTaskRunner)
      let summary = "Started a \(backend) run for: \(objective)."
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: "agent.codingAgentRun", succeeded: true, summary: summary),
        correlationID: correlationID, causationID: causationID)
      return .acknowledgedAsync(summary: summary)
    } catch {
      let summary = "Failed to start \(backend) run: \(error.localizedDescription)"
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: "agent.codingAgentRun", succeeded: false, summary: summary),
        correlationID: correlationID, causationID: causationID)
      return .failed(reason: summary)
    }
  }

  // MARK: - Shared policy resolution

  private enum PolicyResolution {
    case allowed
    case blocked(IntentExecutionOutcome)
  }

  /// Evaluate policy for one router-enforced branch, resolve a `.confirm`
  /// challenge through `confirmationPresenter`, and — regardless of how
  /// `.allow` was reached — apply the hard, non-bypassable mandatory-
  /// confirmation guard. Mirrors `ComputerUseControlLoop`'s placement of
  /// `step.semanticIntent.requiresMandatoryConfirmation` immediately after
  /// receiving `.allow` (`ComputerUseControlLoop.swift:280`).
  private func resolvePolicy(
    _ intent: TypedIntent,
    capability: Capability,
    target: PolicyTarget,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> PolicyResolution {
    let turnContext =
      intent.turnContext
      ?? TurnContext(
        sessionID: sessionID,
        correlationID: correlationID,
        causationID: causationID,
        activationSource: .text,
        actor: actor,
        authority: .userUtterance,
        sensitivity: .sensitive)
    let request = PolicyEvaluationRequest(
      capability: capability, actor: actor, target: target, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID,
      turnContext: turnContext)
    let decision = await policyEngine.evaluate(request)
    var confirmationSatisfied = false

    switch decision {
    case .allow:
      break
    case .deny(let reason, _):
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "policyDenied: \(reason)"),
        correlationID: correlationID, causationID: causationID)
      return .blocked(.blockedByPolicy(reason: reason))
    case .confirm(let challenge, _):
      let response = await confirmationPresenter.present(challenge: challenge)
      let resolved = await policyEngine.submitConfirmation(response)
      guard case .allow = resolved else {
        await emit(
          IntentBlockedEvent(intentID: intent.id, reason: "confirmationDenied"),
          correlationID: correlationID, causationID: causationID)
        return .blocked(.blockedPendingConfirmationDenied)
      }
      confirmationSatisfied = true
    }

    if intent.requiresMandatoryConfirmation && !confirmationSatisfied {
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "mandatoryConfirmationRequired"),
        correlationID: correlationID, causationID: causationID)
      return .blocked(.blockedPendingConfirmationDenied)
    }

    if let context = intent.turnContext {
      let planHash = PolicyPlanHasher.hash(
        capability: capability,
        actor: actor,
        target: target)
      _ = await policyEngine.beginAuthorizedExecution(context: context, planHash: planHash)
    }

    return .allowed
  }

  // MARK: - Helpers

  private func clarifyingQuestion(for intent: TypedIntent) -> String {
    let language = intent.language
    if let unresolvedApp = intent.slotValue(IntentSlotName.unresolvedAppName) {
      if language == .turkish {
        return "\(unresolvedApp) uygulamasını tanımıyorum. Hangi uygulamayı kastettiniz?"
      }
      if language == .mixed {
        return "\(unresolvedApp) app’i tanımıyorum. Which application did you mean?"
      }
      return
        "I don't know an application called \"\(unresolvedApp)\". Which application did you mean?"
    }
    if let unresolvedExecutable = intent.slotValue(IntentSlotName.executable) {
      if language == .turkish {
        return "\(unresolvedExecutable) komutunu tanımıyorum. Tam yolu paylaşır mısınız?"
      }
      if language == .mixed {
        return "\(unresolvedExecutable) executable’ı tanımıyorum. Could you give me the full path?"
      }
      return
        "I don't recognize the command \"\(unresolvedExecutable)\". Could you give me the full path?"
    }
    if language == .turkish {
      return "Ne yapmak istediğinizden emin değilim. Lütfen yeniden ifade eder misiniz?"
    }
    if language == .mixed {
      return "I'm not sure what you'd like me to do. Lütfen yeniden ifade eder misiniz?"
    }
    return "I'm not sure what you'd like me to do. Could you rephrase that?"
  }

  private func emit<P: EventPayload>(_ payload: P, correlationID: UUID, causationID: UUID) async {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: causationID, actor: .intent,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }
}
