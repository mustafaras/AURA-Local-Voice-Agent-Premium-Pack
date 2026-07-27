import Foundation

/// Semantic category of a classified user intent, used to derive a fixed
/// policy risk tier — mirrors `ComputerUseSemanticIntent` (`ComputerUseTypes
/// .swift`) exactly: a step's *meaning*, not a raw action verb or free-text
/// utterance, drives its capability and confirmation requirement.
public enum IntentSemanticCategory: String, Codable, Sendable, Equatable, CaseIterable {
  /// Plain conversational turn with no tool dispatch.
  case converse
  /// Bring an already-running or launchable application to the foreground.
  case appActivate
  /// Quit an application.
  case appTerminate
  /// Execute a shell command that does not match a destructive pattern.
  case shellExecute
  /// A shell command matched a conservative destructive-pattern denylist
  /// (e.g. `rm -rf`-style, `diskutil erase`, `dd ... of=/dev/`) — escalated
  /// from `.shellExecute`, never a distinct classifier output.
  case shellDestructive
  /// Delegate an objective to a coding-agent CLI backend (Codex/Claude/
  /// Copilot). The backend evaluates its own policy internally; see
  /// `Capability.forIntent(_:)`'s doc comment for why this category maps to
  /// a placeholder capability the router never actually acts on.
  case codingAgentRun
  /// Classification confidence too low, or more than one candidate scored
  /// comparably — never dispatched, always surfaced as ambiguous.
  case unknown

  /// Pure, deterministic mapping from semantic category to policy risk
  /// tier — never independently guessed by a caller.
  public var riskTier: PermissionRiskTier {
    switch self {
    case .converse, .unknown:
      return .observation
    case .appActivate:
      return .reversible
    case .appTerminate, .shellExecute:
      return .mutation
    case .shellDestructive, .codingAgentRun:
      return .destructive
    }
  }

  /// Categories that can never execute on a bare `.allow` decision, even
  /// via a permissive grant — checked by `ToolRouter` immediately after
  /// `PolicyEngine.evaluate`, mirroring `ComputerUseSemanticIntent
  /// .mandatoryConfirmationIntents` / `ComputerUseControlLoop`'s hard
  /// post-allow guard.
  public static let mandatoryConfirmationCategories: Set<IntentSemanticCategory> = [
    .shellDestructive
  ]

  public var requiresMandatoryConfirmation: Bool {
    Self.mandatoryConfirmationCategories.contains(self)
  }
}
