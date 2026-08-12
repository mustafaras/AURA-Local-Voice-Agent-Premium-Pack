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
    let (capability, target) = commandTarget(for: command)
    return PolicyEvaluationRequest(
      capability: capability,
      actor: actor,
      target: target,
      sessionID: executionID,
      correlationID: executionID,
      causationID: executionID)
  }

  private static func commandTarget(
    for command: VSCodeCommand
  ) -> (Capability, PolicyTarget) {
    switch command {
    case .openWorkspace(let path, _), .openFolder(let path, _, _),
      .openFile(let path, _, _, _), .addFolder(let path):
      return (.vscodeOpen, PolicyTarget(filePath: path))
    case .openDiff(let left, let right):
      return (.vscodeOpen, PolicyTarget(filePath: left, directoryPath: right))
    case .manageExtension(let extensionID, let action):
      return (
        .vscodeManageExtension,
        PolicyTarget(
          filePath: extensionID, arguments: [action.rawValue])
      )
    case .runTask(let name, _):
      return (.vscodeRunTask, PolicyTarget(filePath: "vscode-task://\(name)", arguments: [name]))
    case .runTests(let target, _):
      return (
        .vscodeRunTests,
        PolicyTarget(
          filePath: "vscode-tests://\(target ?? "default")",
          arguments: target.map { [$0] } ?? [])
      )
    case .terminalCommand(let command, _, _):
      return (
        .vscodeInjectTerminal,
        PolicyTarget(
          command: command.executable,
          arguments: command.arguments,
          environmentKeys: Array(command.environment.keys))
      )
    case .openAgents:
      return (.vscodeOpen, PolicyTarget(filePath: "agents"))
    }
  }

  /// Build a policy request for an allowlisted extension command.
  public static func request(
    for command: VSCodeBridgeCommand,
    actor: ActorID,
    correlationID: String
  ) -> PolicyEvaluationRequest {
    let executionID = UUID(uuidString: correlationID) ?? UUID()
    let (capability, target) = bridgeTarget(for: command)
    return PolicyEvaluationRequest(
      capability: capability,
      actor: actor,
      target: target,
      sessionID: executionID,
      correlationID: executionID,
      causationID: executionID
    )
  }

  private static func bridgeTarget(
    for command: VSCodeBridgeCommand
  ) -> (Capability, PolicyTarget) {
    switch command.kind {
    case .health, .workspace, .editor, .diagnostics, .tasks, .tests, .terminalSessions:
      return observationTarget(for: command.kind)
    case .runTask, .cancelTask, .runTests, .cancelTests:
      return operationTarget(for: command)
    }
  }

  private static func observationTarget(
    for kind: VSCodeBridgeCommand.Kind
  ) -> (Capability, PolicyTarget) {
    switch kind {
    case .health:
      return (.vscodeBridgeHealth, PolicyTarget(filePath: "vscode-bridge://health"))
    case .workspace:
      return (.vscodeWorkspaceStatus, PolicyTarget(filePath: "vscode-workspace://active"))
    case .editor:
      return (.vscodeObserveState, PolicyTarget(filePath: "vscode-editor://active"))
    case .diagnostics:
      return (.vscodeDiagnostics, PolicyTarget(filePath: "vscode-diagnostics://workspace"))
    case .tasks:
      return (.vscodeObserveState, PolicyTarget(filePath: "vscode-tasks://list"))
    case .tests:
      return (.vscodeObserveState, PolicyTarget(filePath: "vscode-tests://list"))
    case .terminalSessions:
      return (.vscodeObserveState, PolicyTarget(filePath: "vscode-terminals://list"))
    default:
      return (.vscodeObserveState, PolicyTarget(filePath: "vscode-bridge://invalid"))
    }
  }

  private static func operationTarget(
    for command: VSCodeBridgeCommand
  ) -> (Capability, PolicyTarget) {
    switch command.kind {
    case .runTask:
      return (
        .vscodeRunTask,
        PolicyTarget(
          filePath: "vscode-task://" + (command.name ?? ""),
          arguments: [command.name ?? ""].filter { !$0.isEmpty })
      )
    case .cancelTask:
      return (
        .vscodeCancelTask,
        PolicyTarget(
          filePath: "vscode-task-cancel://" + (command.taskID ?? ""))
      )
    case .runTests:
      return (
        .vscodeRunTests,
        PolicyTarget(
          filePath: "vscode-tests://" + (command.target ?? "default"),
          arguments: command.target.map { [$0] } ?? [])
      )
    case .cancelTests:
      return (
        .vscodeCancelTests,
        PolicyTarget(
          filePath: "vscode-tests-cancel://" + (command.testID ?? ""))
      )
    default:
      return (.vscodeObserveState, PolicyTarget(filePath: "vscode-bridge://invalid"))
    }
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
