import AuraCore
import Foundation

/// Adapts a typed `Command` into the policy framework's evaluation request.
public struct ShellPolicyAdapter: Sendable {
  public init() {}

  /// Build a `PolicyEvaluationRequest` for a typed shell command.
  public func request(
    command: Command,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) -> PolicyEvaluationRequest {
    PolicyEvaluationRequest(
      capability: .shellExec,
      actor: actor,
      target: PolicyTarget(
        command: command.executable,
        arguments: command.arguments,
        environmentKeys: Array(command.environment.keys)
      ),
      arguments: command.arguments,
      environment: command.environment,
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: causationID
    )
  }
}
