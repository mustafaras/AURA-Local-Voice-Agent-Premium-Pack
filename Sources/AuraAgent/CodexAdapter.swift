import AuraCore
import AuraPolicy
import AuraShell
import Foundation

/// Coordinates a single Codex CLI run: policy gate, upfront approval,
/// process execution, JSONL normalization, budget enforcement, and
/// cancellation.
///
/// `codex exec` has no `-a/--ask-for-approval` flag (verified via
/// `codex exec --help` — that flag exists only on the top-level interactive
/// `codex` command) and is always run without any config-driven mid-run
/// approval prompt. Authorization instead happens once, upfront, through
/// `PolicyEngine.evaluate` before a process is ever spawned; the resulting
/// `-s` sandbox tier is exactly the tier that was evaluated. See ADR-011.
public actor CodexAdapter {
  let configuration: CodexConfiguration
  let policyEngine: PolicyEngine
  let approvalPresenter: any CodexApprovalPresenting
  let processExecutor: any AdapterProcessExecuting
  let eventBus: AuraEventBus

  public init(
    configuration: CodexConfiguration,
    policyEngine: PolicyEngine,
    approvalPresenter: any CodexApprovalPresenting = CodexAlwaysDenyApprovalPresenter(),
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
