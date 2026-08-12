import AuraAgent
import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraTasks
import Foundation

/// Superseded by `CapabilityManifest`/`CapabilityRegistry`
/// (`CapabilityRegistry.swift`, `InitialCapabilitySet.swift`) as of R3 —
/// see `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s completion gate,
/// "the registry is the sole production source for user-reachable tools."

/// Pluggable presenter for a `PolicyConfirmationChallenge` `ToolRouter`
/// itself raises (for the capabilities it, not an adapter, evaluates).
/// Mirrors `CodexApprovalPresenting` exactly, including its two production
/// fixtures' shape and doc-comment convention.
public protocol IntentConfirmationPresenting: Sendable {
  func present(challenge: PolicyConfirmationChallenge) async -> PolicyConfirmationResponse
}

struct ToolExecutionContext {
  let actor: ActorID
  let sessionID: UUID
  let correlationID: UUID
  let causationID: UUID
}

/// Outcome of routing one classified intent to its tool.
public enum IntentExecutionOutcome: Sendable, Equatable {
  case executed(summary: String, hasSpokenResponse: Bool)
  /// A coding-agent run was enqueued but not awaited — see `ToolRouter
  /// .handleCodingAgentRun`'s doc comment for why a synchronous wait would
  /// exceed `Conversation`'s think-timeout.
  case acknowledgedAsync(summary: String)
  case blockedByPolicy(reason: String)
  case blockedPendingConfirmationDenied
  case ambiguous(clarifyingQuestion: String)
  case failed(reason: String)
}
