import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

/// Implements steps 7–8 of `docs/subsystems/08_INTENT_ENGINE.md`'s pipeline
/// ("select handler," "produce an inspectable execution plan") plus `09_
/// TOOL_ROUTER.md`'s router behaviors (evaluate policy, record proposal/
/// result). Every branch that does not `enforcesPolicyInternally` calls
/// `PolicyEngine.evaluate` itself before touching a backend subsystem —
/// `AuraShell`/`AuraAutomation` never do this on their own.
public actor ToolRouter {
  let policyEngine: PolicyEngine
  let automation: AuraAutomation
  let shell: AuraShell
  let taskEngine: AuraTaskEngine
  let agentTaskRunner: AgentBackendTaskRunner
  let codingTaskCoordinator: CodingTaskCoordinator?
  /// The sole production source of capability contracts — replaces the
  /// prior phase's static `ToolRegistry` per `04_R3_CAPABILITY_REGISTRY_AND
  /// _PLANNER.prompt.md`'s completion gate. `IntentKind` still identifies
  /// what the classifier/dialogue layer produced; `capabilityID(for:)`
  /// below is the only place that maps a kind to the registry's namespaced
  /// capability ID, so adding a capability never requires widening this
  /// router's own dispatch switch.
  let capabilityRegistry: CapabilityRegistry
  let confirmationPresenter: any IntentConfirmationPresenting
  let eventBus: AuraEventBus
  let configuration: IntentEngineConfiguration
  let dialogueEngine: DialogueEngine
  let destructivePatternMatchers: [NSRegularExpression]

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

}
