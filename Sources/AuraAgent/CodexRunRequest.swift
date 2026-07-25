import AuraCore
import Foundation

/// Sandbox tier requested for a Codex run.
///
/// Only the two tiers AURA is willing to grant automatically are
/// representable here. `danger-full-access` (a real, documented `codex exec`
/// flag) has no case — it is unreachable by construction, not merely avoided
/// by convention.
public enum CodexSandboxTier: String, Codable, Sendable, Equatable, CaseIterable {
  case readOnly
  case workspaceWrite

  /// The verified `codex exec -s` flag value for this tier.
  var cliValue: String {
    switch self {
    case .readOnly: return "read-only"
    case .workspaceWrite: return "workspace-write"
    }
  }
}

/// A request to run a single Codex CLI turn.
///
/// There is no `resumeSessionID` field: `codex exec resume` is explicitly out
/// of scope for this phase (see ADR-011).
public struct CodexRunRequest: Sendable, Equatable {
  public let prompt: String
  public let workingDirectory: String
  public let sandbox: CodexSandboxTier
  public let additionalWritableDirectories: [String]
  public let model: String?
  public let timeoutSeconds: Double?

  public init(
    prompt: String,
    workingDirectory: String,
    sandbox: CodexSandboxTier,
    additionalWritableDirectories: [String] = [],
    model: String? = nil,
    timeoutSeconds: Double? = nil
  ) {
    self.prompt = prompt
    self.workingDirectory = workingDirectory
    self.sandbox = sandbox
    self.additionalWritableDirectories = additionalWritableDirectories
    self.model = model
    self.timeoutSeconds = timeoutSeconds
  }
}
