import Foundation

/// Configuration for `IntentEngine`/`ToolRouter` (`AuraIntent`) — the
/// classifier's confidence gate, the default coding-agent backend/working
/// directory a `.codingAgentRun` intent uses, and the conservative
/// destructive-shell pattern denylist `ToolRouter` checks before a
/// `.shellExecute` intent is allowed to remain at that (non-destructive)
/// tier.
public struct IntentEngineConfiguration: Codable, Sendable, Equatable {
  /// Below this classification confidence, an intent is forced to
  /// `.unknown`/`isAmbiguous` regardless of what the classifier proposed.
  public var minimumClassificationConfidence: Double

  /// Which `AgentBackendTaskRunner`-registered backend a `.codingAgentRun`
  /// intent uses when the utterance does not name one explicitly.
  public var defaultCodingAgentBackend: String

  /// Working directory a `.codingAgentRun` task is enqueued against when
  /// the utterance does not name one explicitly.
  public var defaultCodingAgentWorkingDirectory: String

  /// Seconds a clarification slot remains eligible for a follow-up answer.
  public var clarificationExpirySeconds: Double

  /// Regex patterns that, when matched against a shell intent's executable
  /// plus arguments, escalate it from `.shellExecute` to `.shellDestructive`
  /// (`Capability.shellExecDestructive`, no grant seeded by default). A
  /// deliberately small, conservative, defense-in-depth list — never the
  /// only thing standing between a shell intent and execution, since plain
  /// `.shellExecute` already requires `.always` confirmation by default.
  public var destructiveShellPatterns: [String]

  public init(
    minimumClassificationConfidence: Double = 0.6,
    defaultCodingAgentBackend: String = "codex",
    defaultCodingAgentWorkingDirectory: String = "$HOME",
    clarificationExpirySeconds: Double = 60,
    destructiveShellPatterns: [String] = [
      "rm\\s+-[a-zA-Z]*[rf][a-zA-Z]*[rf]",
      "diskutil\\s+(erase|reformat|partitionDisk)",
      "dd\\s+.*of=/dev/",
      ":\\(\\)\\s*\\{\\s*:\\|:&\\s*\\}\\s*;\\s*:",
    ]
  ) {
    self.minimumClassificationConfidence = minimumClassificationConfidence
    self.defaultCodingAgentBackend = defaultCodingAgentBackend
    self.defaultCodingAgentWorkingDirectory = defaultCodingAgentWorkingDirectory
    self.clarificationExpirySeconds = clarificationExpirySeconds
    self.destructiveShellPatterns = destructiveShellPatterns
  }

  public func validate() throws(AuraError) {
    guard minimumClassificationConfidence >= 0, minimumClassificationConfidence <= 1 else {
      throw AuraError.invalidConfiguration(
        "intent minimumClassificationConfidence must be in [0, 1]")
    }
    guard !defaultCodingAgentBackend.isEmpty else {
      throw AuraError.invalidConfiguration("intent defaultCodingAgentBackend must not be empty")
    }
    guard !defaultCodingAgentWorkingDirectory.isEmpty else {
      throw AuraError.invalidConfiguration(
        "intent defaultCodingAgentWorkingDirectory must not be empty")
    }
    guard clarificationExpirySeconds > 0 else {
      throw AuraError.invalidConfiguration("intent clarificationExpirySeconds must be positive")
    }
    for pattern in destructiveShellPatterns {
      guard !pattern.isEmpty else {
        throw AuraError.invalidConfiguration(
          "intent destructiveShellPatterns must not contain empty patterns")
      }
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> IntentEngineConfiguration {
    IntentEngineConfiguration(
      minimumClassificationConfidence: (self.minimumClassificationConfidence < 0
        || self.minimumClassificationConfidence > 1)
        ? IntentEngineConfiguration().minimumClassificationConfidence
        : self.minimumClassificationConfidence,
      defaultCodingAgentBackend: self.defaultCodingAgentBackend.isEmpty
        ? IntentEngineConfiguration().defaultCodingAgentBackend
        : self.defaultCodingAgentBackend,
      defaultCodingAgentWorkingDirectory: self.defaultCodingAgentWorkingDirectory.isEmpty
        ? IntentEngineConfiguration().defaultCodingAgentWorkingDirectory
        : self.defaultCodingAgentWorkingDirectory,
      clarificationExpirySeconds: self.clarificationExpirySeconds <= 0
        ? IntentEngineConfiguration().clarificationExpirySeconds
        : self.clarificationExpirySeconds,
      destructiveShellPatterns: self.destructiveShellPatterns.isEmpty
        ? IntentEngineConfiguration().destructiveShellPatterns
        : self.destructiveShellPatterns
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = IntentEngineConfiguration()
    minimumClassificationConfidence =
      try container.decodeIfPresent(Double.self, forKey: .minimumClassificationConfidence)
      ?? defaults.minimumClassificationConfidence
    defaultCodingAgentBackend =
      try container.decodeIfPresent(String.self, forKey: .defaultCodingAgentBackend)
      ?? defaults.defaultCodingAgentBackend
    defaultCodingAgentWorkingDirectory =
      try container.decodeIfPresent(String.self, forKey: .defaultCodingAgentWorkingDirectory)
      ?? defaults.defaultCodingAgentWorkingDirectory
    clarificationExpirySeconds =
      try container.decodeIfPresent(Double.self, forKey: .clarificationExpirySeconds)
      ?? defaults.clarificationExpirySeconds
    destructiveShellPatterns =
      try container.decodeIfPresent([String].self, forKey: .destructiveShellPatterns)
      ?? defaults.destructiveShellPatterns
  }
}
