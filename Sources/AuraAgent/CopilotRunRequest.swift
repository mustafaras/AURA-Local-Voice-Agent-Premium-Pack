import AuraCore
import Foundation

/// Tool profile requested for a Copilot run.
///
/// Only the two tiers AURA is willing to grant automatically are
/// representable here, mirroring `CodexSandboxTier`/`ClaudeToolProfile`.
/// There is no case mapping to `--allow-all`/`--yolo`/`--allow-all-paths`/
/// `--allow-all-urls` — unreachable by construction.
public enum CopilotToolProfile: String, Codable, Sendable, Equatable, CaseIterable {
  case readOnly
  case workspaceWrite
}

/// A request to run a single Copilot CLI turn.
///
/// There is no `resumeSessionID`/`--continue`/`--resume` support — explicitly
/// out of scope for this phase, matching the Codex/Claude adapters' session
/// scoping decision. There is likewise no field representing GitHub's
/// separate cloud-hosted "Copilot coding agent" (issue-assignment-triggered,
/// runs on GitHub's infrastructure) — this adapter only drives the local
/// `copilot` CLI; see ADR-013.
public struct CopilotRunRequest: Sendable, Equatable {
  public let objective: String
  public let workingDirectory: String
  public let toolProfile: CopilotToolProfile
  public let additionalWritableDirectories: [String]
  public let model: String?
  public let timeoutSeconds: Double?
  public let maxAICredits: Int?

  public init(
    objective: String,
    workingDirectory: String,
    toolProfile: CopilotToolProfile,
    additionalWritableDirectories: [String] = [],
    model: String? = nil,
    timeoutSeconds: Double? = nil,
    maxAICredits: Int? = nil
  ) {
    self.objective = objective
    self.workingDirectory = workingDirectory
    self.toolProfile = toolProfile
    self.additionalWritableDirectories = additionalWritableDirectories
    self.model = model
    self.timeoutSeconds = timeoutSeconds
    self.maxAICredits = maxAICredits
  }
}
