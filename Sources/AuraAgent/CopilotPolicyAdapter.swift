import AuraCore
import Foundation

/// Maps a `CopilotRunRequest` to a typed policy request.
///
/// Pure: it does not execute commands or read filesystem state. Deliberately
/// excludes the raw objective text from the policy target/audit summary,
/// mirroring `CodexPolicyAdapter`/`ClaudePolicyAdapter`.
public enum CopilotPolicyAdapter {
  public static func request(
    for request: CopilotRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) -> PolicyEvaluationRequest {
    let capability: Capability
    switch request.toolProfile {
    case .readOnly:
      capability = .agentCopilotReadOnly
    case .workspaceWrite:
      capability = .agentCopilotRun
    }

    return PolicyEvaluationRequest(
      capability: capability,
      actor: actor,
      target: PolicyTarget(
        directoryPath: request.workingDirectory,
        arguments: request.additionalWritableDirectories
      ),
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: causationID
    )
  }
}
