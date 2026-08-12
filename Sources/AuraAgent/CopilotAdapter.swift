import AuraCore
import AuraPolicy
import AuraShell
import Foundation

/// Coordinates a single Copilot CLI run: repository-instructions secret
/// scan, policy gate, upfront approval, process execution, JSONL
/// normalization, budget observation, and cancellation.
///
/// `copilot -p` (non-interactive mode) requires tool approval to be granted
/// before spawning — verified via `copilot help permissions`: unlisted tools
/// either block on a confirmation prompt with no TTY to answer it, or
/// (`--allow-all-tools`) run without per-call confirmation. Authorization
/// happens once, upfront, through `PolicyEngine.evaluate`; the resulting
/// tool profile is exactly the profile that was evaluated. This adapter
/// drives only the local `copilot` CLI — GitHub's separate cloud-hosted
/// coding agent is out of scope; see ADR-013.
public actor CopilotAdapter {
  let configuration: CopilotConfiguration
  let policyEngine: PolicyEngine
  let approvalPresenter: any CopilotApprovalPresenting
  let processExecutor: any AdapterProcessExecuting
  let eventBus: AuraEventBus

  public init(
    configuration: CopilotConfiguration,
    policyEngine: PolicyEngine,
    approvalPresenter: any CopilotApprovalPresenting = CopilotAlwaysDenyApprovalPresenter(),
    processExecutor: (any AdapterProcessExecuting)? = nil,
    eventBus: AuraEventBus = .shared
  ) {
    self.configuration = configuration
    self.policyEngine = policyEngine
    self.approvalPresenter = approvalPresenter
    self.eventBus = eventBus
    self.processExecutor =
      processExecutor
      ?? ShellAdapterProcessExecutor(
        shell: AuraShell(configuration: configuration.derivedShellConfiguration()))
  }

}
