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
  /// The typed planner, on the production path.
  ///
  /// SP-006 proved the seven live scenarios, but its closeout recorded that
  /// `CapabilityPlanner` was constructed only in tests — no production site
  /// built a plan, so "only a manifest-validated step ever becomes a
  /// `PlanStep`" was a test-only property. It is now the seam every routed
  /// intent passes through (`route`) and the executor behind `routePlan`, so
  /// a plan is built, validated, and fingerprinted in production rather than
  /// only under test.
  let capabilityPlanner: CapabilityPlanner
  let confirmationPresenter: any IntentConfirmationPresenting
  let eventBus: AuraEventBus
  let configuration: IntentEngineConfiguration
  let dialogueEngine: DialogueEngine
  let destructivePatternMatchers: [NSRegularExpression]
  /// SP-010's read-first productivity port, supplied by the composition root.
  ///
  /// Optional because the router must build in fixtures and tests that wire
  /// no integrations at all. `nil` is not a soft failure: the four read
  /// handlers refuse with a truthful reason rather than answering as though
  /// the mailbox, calendar, or address book were empty.
  let productivityReader: (any ProductivityReading)?

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
    codingTaskCoordinator: CodingTaskCoordinator? = nil,
    productivityReader: (any ProductivityReading)? = nil
  ) {
    self.policyEngine = policyEngine
    self.automation = automation
    self.shell = shell
    self.taskEngine = taskEngine
    self.agentTaskRunner = agentTaskRunner
    self.codingTaskCoordinator = codingTaskCoordinator
    self.capabilityRegistry = capabilityRegistry
    self.capabilityPlanner = CapabilityPlanner(registry: capabilityRegistry)
    self.confirmationPresenter = confirmationPresenter
    self.eventBus = eventBus
    self.configuration = configuration
    self.dialogueEngine = dialogueEngine
    self.productivityReader = productivityReader
    self.destructivePatternMatchers = configuration.destructiveShellPatterns.compactMap {
      try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
    }
  }

}
