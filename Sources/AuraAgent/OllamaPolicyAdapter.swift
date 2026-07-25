import AuraCore
import Foundation

/// Maps a routed Ollama model + capability to a typed policy request.
///
/// Pure: it does not perform inference or network I/O. Deliberately
/// excludes the raw prompt text from the policy target/audit summary,
/// mirroring `CodexPolicyAdapter`/`ClaudePolicyAdapter`/`CopilotPolicyAdapter`.
/// The policy-relevant distinction here is not "read vs. write" (this phase
/// never executes tools) but local vs. cloud-proxied — whether the prompt
/// leaves the device.
public enum OllamaPolicyAdapter {
  public static func request(
    model: OllamaRegisteredModel,
    capability: OllamaTaskCapability,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) -> PolicyEvaluationRequest {
    PolicyEvaluationRequest(
      capability: model.isLocal ? .agentOllamaLocalInference : .agentOllamaCloudInference,
      actor: actor,
      target: PolicyTarget(
        command: model.name,
        arguments: [capability.rawValue]
      ),
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: causationID
    )
  }
}
