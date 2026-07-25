import AuraCore
import Foundation

/// Maps a `CodexRunRequest` to a typed policy request.
///
/// Pure: it does not execute commands or read filesystem state. Deliberately
/// excludes the raw prompt text from the policy target/audit summary — the
/// prompt is free-form natural language that may contain sensitive content,
/// and the policy layer only needs to know where the run is allowed to touch,
/// not what the user asked for.
public enum CodexPolicyAdapter {
  public static func request(
    for request: CodexRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) -> PolicyEvaluationRequest {
    let capability: Capability
    switch request.sandbox {
    case .readOnly:
      capability = .agentCodexReadOnly
    case .workspaceWrite:
      capability = .agentCodexRun
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
