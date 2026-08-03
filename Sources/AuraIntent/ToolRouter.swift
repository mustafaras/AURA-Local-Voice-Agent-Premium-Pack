import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

/// A tool's declared contract — `docs/subsystems/09_TOOL_ROUTER.md`'s
/// required fields, plus one AURA-specific addition
/// (`enforcesPolicyInternally`) capturing a real architectural split
/// discovered while wiring this router: the CLI coding-agent adapters
/// already call `PolicyEngine.evaluate` themselves before running, while
/// `AuraAutomation`/`AuraShell` construct but never evaluate a policy
/// request (`AuraShell.execute`'s own doc comment says so explicitly) —
/// those must be gated by the router itself.
public struct ToolContract: Sendable, Equatable {
  public let id: String
  public let version: String
  public let inputSchemaDescription: String
  public let requiredCapability: Capability
  public let riskTier: PermissionRiskTier
  public let isIdempotent: Bool
  public let preconditions: [String]
  public let sideEffects: [String]
  public let timeoutSeconds: Double
  public let supportsRollback: Bool
  public let verificationMethod: String
  public let sensitiveFieldKeys: [String]
  public let enforcesPolicyInternally: Bool

  public init(
    id: String,
    version: String,
    inputSchemaDescription: String,
    requiredCapability: Capability,
    riskTier: PermissionRiskTier,
    isIdempotent: Bool,
    preconditions: [String] = [],
    sideEffects: [String] = [],
    timeoutSeconds: Double,
    supportsRollback: Bool,
    verificationMethod: String,
    sensitiveFieldKeys: [String] = [],
    enforcesPolicyInternally: Bool
  ) {
    self.id = id
    self.version = version
    self.inputSchemaDescription = inputSchemaDescription
    self.requiredCapability = requiredCapability
    self.riskTier = riskTier
    self.isIdempotent = isIdempotent
    self.preconditions = preconditions
    self.sideEffects = sideEffects
    self.timeoutSeconds = timeoutSeconds
    self.supportsRollback = supportsRollback
    self.verificationMethod = verificationMethod
    self.sensitiveFieldKeys = sensitiveFieldKeys
    self.enforcesPolicyInternally = enforcesPolicyInternally
  }
}

/// One `ToolContract` per `IntentKind` in the closed v1 vocabulary.
public struct ToolRegistry: Sendable {
  private let contractsByKind: [IntentKind: ToolContract]

  public init(contracts: [IntentKind: ToolContract]) {
    self.contractsByKind = contracts
  }

  public func contract(for kind: IntentKind) -> ToolContract? {
    contractsByKind[kind]
  }

  /// The standard v1 registry — one contract per real backend this phase
  /// wires up. `.unknown` deliberately has no contract; `ToolRouter.route`
  /// never reaches the registry lookup for it (ambiguity is checked first).
  public static func defaultRegistry() -> ToolRegistry {
    ToolRegistry(contracts: [
      .converse: ToolContract(
        id: "aura.converse", version: "1.0.0",
        inputSchemaDescription: "utterance text; no side effects",
        requiredCapability: .intentConverse, riskTier: .observation, isIdempotent: true,
        timeoutSeconds: 1, supportsRollback: false, verificationMethod: "none",
        enforcesPolicyInternally: false),
      .appActivate: ToolContract(
        id: "automation.appActivate", version: "1.0.0",
        inputSchemaDescription: "bundleIdentifier: String",
        requiredCapability: .appActivate, riskTier: .reversible, isIdempotent: true,
        preconditions: ["target application installed"],
        sideEffects: ["brings the target application to the foreground"],
        timeoutSeconds: 10, supportsRollback: false,
        verificationMethod: "AuraAutomation reports the activated bundle identifier",
        enforcesPolicyInternally: false),
      .appTerminate: ToolContract(
        id: "automation.appTerminate", version: "1.0.0",
        inputSchemaDescription: "bundleIdentifier: String",
        requiredCapability: .appTerminate, riskTier: .mutation, isIdempotent: true,
        preconditions: ["target application running"],
        sideEffects: ["quits the target application; may discard unsaved state"],
        timeoutSeconds: 10, supportsRollback: false,
        verificationMethod: "AuraAutomation reports the terminated bundle identifier",
        enforcesPolicyInternally: false),
      .shellExecute: ToolContract(
        id: "shell.execute", version: "1.0.0",
        inputSchemaDescription: "executable: String, arguments: [String]",
        requiredCapability: .shellExec, riskTier: .mutation, isIdempotent: false,
        preconditions: ["executable resolvable within the closed v1 lookup table"],
        sideEffects: ["arbitrary process side effects, bounded by AuraShell's own allowlist"],
        timeoutSeconds: 30, supportsRollback: false,
        verificationMethod: "process exit code and captured stdout/stderr",
        enforcesPolicyInternally: false),
      .codingAgentRun: ToolContract(
        id: "agent.codingAgentRun", version: "1.0.0",
        inputSchemaDescription: "backend: String, objective: String",
        // The adapter performs the authoritative backend-specific policy check;
        // this generic capability keeps the contract's risk metadata honest.
        requiredCapability: .agentRun, riskTier: .destructive, isIdempotent: false,
        preconditions: ["chosen backend CLI available and authorized"],
        sideEffects: ["delegates to a coding-agent CLI run; may write files"],
        timeoutSeconds: 1800, supportsRollback: false,
        verificationMethod: "AuraTaskEngine status polling",
        enforcesPolicyInternally: true),
    ])
  }
}

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
  private let registry: ToolRegistry
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
    registry: ToolRegistry,
    confirmationPresenter: any IntentConfirmationPresenting,
    eventBus: AuraEventBus,
    configuration: IntentEngineConfiguration,
    dialogueEngine: DialogueEngine = DialogueEngine()
  ) {
    self.policyEngine = policyEngine
    self.automation = automation
    self.shell = shell
    self.taskEngine = taskEngine
    self.agentTaskRunner = agentTaskRunner
    self.registry = registry
    self.confirmationPresenter = confirmationPresenter
    self.eventBus = eventBus
    self.configuration = configuration
    self.dialogueEngine = dialogueEngine
    self.destructivePatternMatchers = configuration.destructiveShellPatterns.compactMap {
      try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
    }
  }

  /// Route using the immutable turn context so every backend call inherits
  /// the original session, actor, correlation, and causation metadata.
  public func route(
    _ intent: TypedIntent,
    context: TurnContext
    , dialogueContext: [DialogueContextItem] = []
  ) async -> IntentExecutionOutcome {
    let contract = registry.contract(for: intent.kind)
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

    guard let contract = registry.contract(for: intent.kind) else {
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
    let context = intent.turnContext ?? TurnContext(
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

  private func handleAppLifecycle(
    _ intent: TypedIntent,
    contract: ToolContract,
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
        ToolResultEvent(intentID: intent.id, toolID: contract.id, succeeded: true, summary: summary),
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
    let arguments = argumentsText.isEmpty ? [] : argumentsText.split(separator: " ").map(String.init)
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

  /// A `.codingAgentRun` intent is delegated wholesale to `AgentBackendTask
  /// Runner`/`AuraTaskEngine` and never awaited here: `Conversation`'s
  /// `thinkTimeoutSeconds` (default 30s) bounds how long `IntentDispatch
  /// Coordinator` can take to produce a `ResponsePlanEvent`, and a real
  /// coding-agent CLI turn routinely takes far longer than that. The chosen
  /// CLI adapter (`CodexAdapter`/`ClaudeAdapter`/`CopilotAdapter`, wrapped
  /// by `AgentBackendTaskRunner`) evaluates its own policy internally
  /// before running — this method never calls `PolicyEngine.evaluate`.
  private func handleCodingAgentRun(
    _ intent: TypedIntent,
    correlationID: UUID,
    causationID: UUID
  ) async -> IntentExecutionOutcome {
    guard let objective = intent.slotValue(IntentSlotName.objective) else {
      return .failed(reason: "missing \(IntentSlotName.objective) slot")
    }
    let backend = intent.slotValue(IntentSlotName.backend) ?? configuration.defaultCodingAgentBackend
    guard AgentBackendTaskRunner.supportedBackends.contains(backend) else {
      return .failed(reason: "unsupported coding-agent backend: \(backend)")
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
    let turnContext = intent.turnContext ?? TurnContext(
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
      return "I don't know an application called \"\(unresolvedApp)\". Which application did you mean?"
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
