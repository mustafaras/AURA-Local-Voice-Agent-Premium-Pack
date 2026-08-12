import AuraCore
import Foundation

/// A normalized event from any backend running as an orchestration role
/// (planner, implementer, or reviewer).
///
/// Reduces the four backend-specific normalized event enums
/// (`CodexNormalizedEvent`, `ClaudeNormalizedEvent`, `CopilotNormalizedEvent`)
/// to exactly the information `MultiAgentOrchestrator` needs to drive a
/// role-based workflow: accumulated text, approval denial, completion,
/// failure, and budget exhaustion. Every case here already exists,
/// verified, on the wrapped backend's own normalized event type — nothing is
/// synthesized or fabricated.
public enum OrchestrationAgentEvent: Sendable, Equatable {
  /// The model's visible reasoning or answer text (`agentText`/`message` on
  /// the wrapped backend).
  case text(role: String, content: String)
  /// The backend's upfront policy confirmation was declined.
  case approvalDenied(reason: String?)
  /// The turn completed successfully.
  case turnCompleted
  /// The turn failed (backend-reported error or process-level failure).
  case turnFailed(message: String?)
  /// A configured budget (file writes, tokens, cost) was exceeded mid-run.
  case budgetExceeded(kind: String, limit: Double, observed: Double)
}

/// Inputs shared by every backend wrapper for one orchestration turn.
public struct OrchestratedAgentRunRequest: Sendable, Equatable {
  public let objective: String
  public let workingDirectory: String
  public let writable: Bool
  public let actor: ActorID
  public let sessionID: UUID
  public let correlationID: UUID
  public let causationID: UUID

  public init(
    objective: String,
    workingDirectory: String,
    writable: Bool,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) {
    self.objective = objective
    self.workingDirectory = workingDirectory
    self.writable = writable
    self.actor = actor
    self.sessionID = sessionID
    self.correlationID = correlationID
    self.causationID = causationID
  }
}

/// A single backend an orchestration role can run against.
///
/// Concrete conformers (`CodexOrchestratedAgent`, `ClaudeOrchestratedAgent`,
/// `CopilotOrchestratedAgent`) each wrap an already-policy-gated CLI adapter;
/// this protocol lets `MultiAgentOrchestrator` drive any of them uniformly
/// without knowing which backend a given role uses.
public protocol OrchestratedAgentRunning: Sendable {
  /// A short, stable identifier for audit events (`"codex"`, `"claude"`,
  /// `"copilot"`).
  var backendName: String { get }

  /// Run one turn. `writable` selects the backend's write-capable tool
  /// profile/sandbox when `true`, or its read-only profile when `false` —
  /// the same two-tier distinction every wrapped adapter already enforces
  /// through its own `PolicyEngine.evaluate` call.
  func run(
    _ request: OrchestratedAgentRunRequest
  ) async -> AsyncThrowingStream<OrchestrationAgentEvent, Error>

  /// Cancel an in-flight run by correlation ID.
  func cancel(correlationID: UUID) async
}
