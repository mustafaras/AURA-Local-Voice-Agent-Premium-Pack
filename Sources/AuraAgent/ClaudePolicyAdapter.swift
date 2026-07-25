import AuraCore
import Foundation

/// Maps a `ClaudeRunRequest` to a typed policy request.
///
/// Pure: it does not execute commands or read filesystem state. Deliberately
/// excludes the raw objective text from the policy target/audit summary,
/// mirroring `CodexPolicyAdapter` — the policy layer only needs to know
/// where a run is allowed to touch, not the free-form content of the task.
public enum ClaudePolicyAdapter {
  public static func request(
    for request: ClaudeRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) -> PolicyEvaluationRequest {
    let capability: Capability
    switch request.toolProfile {
    case .readOnly:
      capability = .agentClaudeReadOnly
    case .workspaceWrite:
      capability = .agentClaudeRun
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
