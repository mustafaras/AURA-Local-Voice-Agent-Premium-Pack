import AuraCore
import Foundation

public struct OllamaPolicyContext: Sendable {
  public let actor: ActorID
  public let sessionID: UUID
  public let correlationID: UUID
  public let causationID: UUID

  public init(actor: ActorID, sessionID: UUID, correlationID: UUID, causationID: UUID) {
    self.actor = actor
    self.sessionID = sessionID
    self.correlationID = correlationID
    self.causationID = causationID
  }
}

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
    context: OllamaPolicyContext
  ) -> PolicyEvaluationRequest {
    PolicyEvaluationRequest(
      capability: model.isLocal ? .agentOllamaLocalInference : .agentOllamaCloudInference,
      actor: context.actor,
      target: PolicyTarget(
        command: model.name,
        arguments: [capability.rawValue]
      ),
      sessionID: context.sessionID,
      correlationID: context.correlationID,
      causationID: context.causationID
    )
  }
}
