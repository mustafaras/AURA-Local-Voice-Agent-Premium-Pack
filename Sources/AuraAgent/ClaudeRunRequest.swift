import AuraCore
import Foundation

/// Tool profile requested for a Claude Code run.
///
/// Only the two tiers AURA is willing to grant automatically are
/// representable here, mirroring `CodexSandboxTier`. There is no case for
/// "all built-in tools" or `--dangerously-skip-permissions` /
/// `--allow-dangerously-skip-permissions` — unreachable by construction.
public enum ClaudeToolProfile: String, Codable, Sendable, Equatable, CaseIterable {
  case readOnly
  case workspaceWrite
}

/// A request to run a single Claude Code turn.
///
/// There is no `resumeSessionID` field — `--resume`/`--continue` (multi-turn
/// session persistence) is explicitly out of scope for this phase, matching
/// the Codex adapter's `codex exec resume` scoping decision.
public struct ClaudeRunRequest: Sendable, Equatable {
  public let objective: String
  public let workingDirectory: String
  public let toolProfile: ClaudeToolProfile
  public let additionalWritableDirectories: [String]
  public let model: String?
  public let timeoutSeconds: Double?
  public let maxCostUSD: Double?

  public init(
    objective: String,
    workingDirectory: String,
    toolProfile: ClaudeToolProfile,
    additionalWritableDirectories: [String] = [],
    model: String? = nil,
    timeoutSeconds: Double? = nil,
    maxCostUSD: Double? = nil
  ) {
    self.objective = objective
    self.workingDirectory = workingDirectory
    self.toolProfile = toolProfile
    self.additionalWritableDirectories = additionalWritableDirectories
    self.model = model
    self.timeoutSeconds = timeoutSeconds
    self.maxCostUSD = maxCostUSD
  }
}
