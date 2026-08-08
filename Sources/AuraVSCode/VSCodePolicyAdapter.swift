import AuraCore
import Foundation

/// Maps a `VSCodeCommand` to a typed policy request.
///
/// The adapter is pure: it does not read filesystem state or execute commands.
/// It produces `PolicyEvaluationRequest` values that the policy engine can
/// evaluate against grants and deny rules.
public enum VSCodePolicyAdapter {

  /// Build a policy request for `command` initiated by `actor` in context
  /// `correlationID`.
  public static func request(
    for command: VSCodeCommand,
    actor: ActorID,
    correlationID: String
  ) -> PolicyEvaluationRequest {
    let executionID = UUID(uuidString: correlationID) ?? UUID()
    switch command {
    case .openWorkspace(let path, _):
      return openRequest(for: path, actor: actor, executionID: executionID)
    case .openFolder(let path, _, _):
      return openRequest(for: path, actor: actor, executionID: executionID)
    case .openFile(let path, _, _, _):
      return openRequest(for: path, actor: actor, executionID: executionID)
    case .addFolder(let path):
      return openRequest(for: path, actor: actor, executionID: executionID)
    case .openDiff(let left, let right):
      return PolicyEvaluationRequest(
        capability: .vscodeOpen,
        actor: actor,
        target: PolicyTarget(filePath: left, directoryPath: right),
        sessionID: executionID,
        correlationID: executionID,
        causationID: executionID
      )

    case .manageExtension(let extensionID, let action):
      return PolicyEvaluationRequest(
        capability: .vscodeManageExtension,
        actor: actor,
        target: PolicyTarget(
          filePath: extensionID,
          arguments: [action.rawValue]
        ),
        sessionID: executionID,
        correlationID: executionID,
        causationID: executionID
      )

    case .runTask(let name, _):
      return PolicyEvaluationRequest(
        capability: .vscodeRunTask,
        actor: actor,
        target: PolicyTarget(
          filePath: "vscode-task://\(name)",
          arguments: [name]
        ),
        sessionID: executionID,
        correlationID: executionID,
        causationID: executionID
      )

    case .runTests(let target, _):
      return PolicyEvaluationRequest(
        capability: .vscodeRunTests,
        actor: actor,
        target: PolicyTarget(
          filePath: "vscode-tests://\(target ?? "default")",
          arguments: target.map { [$0] } ?? []
        ),
        sessionID: executionID,
        correlationID: executionID,
        causationID: executionID
      )

    case .terminalCommand(let command, _, _):
      return PolicyEvaluationRequest(
        capability: .vscodeInjectTerminal,
        actor: actor,
        target: PolicyTarget(
          command: command.executable,
          arguments: command.arguments,
          environmentKeys: Array(command.environment.keys)
        ),
        sessionID: executionID,
        correlationID: executionID,
        causationID: executionID
      )

    case .openAgents:
      return PolicyEvaluationRequest(
        capability: .vscodeOpen,
        actor: actor,
        target: PolicyTarget(filePath: "agents"),
        sessionID: executionID,
        correlationID: executionID,
        causationID: executionID
      )
    }
  }

  /// Build a policy request for an allowlisted extension command.
  public static func request(
    for command: VSCodeBridgeCommand,
    actor: ActorID,
    correlationID: String
  ) -> PolicyEvaluationRequest {
    let executionID = UUID(uuidString: correlationID) ?? UUID()
    let capability: Capability
    let target: PolicyTarget
    switch command.kind {
    case .health:
      capability = .vscodeBridgeHealth
      target = PolicyTarget(filePath: "vscode-bridge://health")
    case .workspace:
      capability = .vscodeWorkspaceStatus
      target = PolicyTarget(filePath: "vscode-workspace://active")
    case .editor:
      capability = .vscodeObserveState
      target = PolicyTarget(filePath: "vscode-editor://active")
    case .diagnostics:
      capability = .vscodeDiagnostics
      target = PolicyTarget(filePath: "vscode-diagnostics://workspace")
    case .tasks:
      capability = .vscodeObserveState
      target = PolicyTarget(filePath: "vscode-tasks://list")
    case .tests:
      capability = .vscodeObserveState
      target = PolicyTarget(filePath: "vscode-tests://list")
    case .terminalSessions:
      capability = .vscodeObserveState
      target = PolicyTarget(filePath: "vscode-terminals://list")
    case .runTask:
      capability = .vscodeRunTask
      target = PolicyTarget(
        filePath: "vscode-task://" + (command.name ?? ""),
        arguments: [command.name ?? ""].filter { !$0.isEmpty })
    case .cancelTask:
      capability = .vscodeCancelTask
      target = PolicyTarget(filePath: "vscode-task-cancel://" + (command.taskID ?? ""))
    case .runTests:
      capability = .vscodeRunTests
      target = PolicyTarget(
        filePath: "vscode-tests://" + (command.target ?? "default"),
        arguments: command.target.map { [$0] } ?? [])
    case .cancelTests:
      capability = .vscodeCancelTests
      target = PolicyTarget(filePath: "vscode-tests-cancel://" + (command.testID ?? ""))
    }
    return PolicyEvaluationRequest(
      capability: capability,
      actor: actor,
      target: target,
      sessionID: executionID,
      correlationID: executionID,
      causationID: executionID
    )
  }

  private static func openRequest(
    for path: String,
    actor: ActorID,
    executionID: UUID
  ) -> PolicyEvaluationRequest {
    PolicyEvaluationRequest(
      capability: .vscodeOpen,
      actor: actor,
      target: PolicyTarget(filePath: path),
      sessionID: executionID,
      correlationID: executionID,
      causationID: executionID
    )
  }
}
