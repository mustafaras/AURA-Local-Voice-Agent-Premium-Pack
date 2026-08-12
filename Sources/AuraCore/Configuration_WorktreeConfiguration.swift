import Foundation

/// Configuration for `WorktreeManager`'s isolated `git worktree` lifecycle,
/// used by `MultiAgentOrchestrator` to give each mutable orchestration task
/// its own working directory.
public struct WorktreeConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `git` executable.
  public var gitExecutablePath: String

  /// Default timeout in seconds for a single `git worktree`/`git diff`
  /// invocation.
  public var defaultTimeoutSeconds: Double

  /// Branch name prefix for orchestration-created branches; the task ID is
  /// appended to form the full branch name.
  public var branchPrefix: String

  /// Name of the directory (relative to a repository's root) under which
  /// per-task worktrees are created. Operators should add this to the
  /// repository's `.gitignore`.
  public var worktreeDirectoryName: String

  /// Directories a repository root or worktree path must fall under.
  ///
  /// Unlike `CodexConfiguration.allowedWorkingDirectories` (which is only
  /// ever compared against a literal repository root), worktree operations
  /// always operate on nested subdirectories (`<repositoryRoot>/
  /// <worktreeDirectoryName>/<taskID>`), and `Command.validate`'s own
  /// allowlist check (`ShellConfiguration.allowedWorkingDirectories`, applied
  /// via `derivedShellConfiguration()`) is exact-match unless a pattern ends
  /// in `*`. The defaults here therefore use trailing-wildcard patterns so a
  /// real project directory anywhere under `$HOME`/`$TMPDIR` — and its
  /// worktrees — are actually reachable, not just the literal home directory
  /// itself.
  public var allowedWorkingDirectories: Set<String>

  public init(
    gitExecutablePath: String = "/usr/bin/git",
    defaultTimeoutSeconds: Double = 60.0,
    branchPrefix: String = "aura/orchestration-",
    worktreeDirectoryName: String = ".aura-worktrees",
    allowedWorkingDirectories: Set<String> = [
      "$HOME/*",
      "$TMPDIR/*",
    ]
  ) {
    self.gitExecutablePath = gitExecutablePath
    self.defaultTimeoutSeconds = defaultTimeoutSeconds
    self.branchPrefix = branchPrefix
    self.worktreeDirectoryName = worktreeDirectoryName
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  /// The directory under which per-task worktrees for `repositoryRoot` are
  /// created: `<repositoryRoot>/<worktreeDirectoryName>`.
  public func worktreeRoot(for repositoryRoot: String) -> String {
    (repositoryRoot as NSString).appendingPathComponent(worktreeDirectoryName)
  }

  public func validate() throws(AuraError) {
    guard !gitExecutablePath.isEmpty else {
      throw AuraError.invalidConfiguration("worktree gitExecutablePath must not be empty")
    }
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("worktree defaultTimeoutSeconds must be positive")
    }
    guard !branchPrefix.isEmpty else {
      throw AuraError.invalidConfiguration("worktree branchPrefix must not be empty")
    }
    guard !worktreeDirectoryName.isEmpty else {
      throw AuraError.invalidConfiguration("worktree worktreeDirectoryName must not be empty")
    }
    guard !allowedWorkingDirectories.isEmpty else {
      throw AuraError.invalidConfiguration("worktree allowedWorkingDirectories must not be empty")
    }
  }

  /// A `ShellConfiguration` scoped to only ever launch the configured `git`
  /// binary, mirroring `CodexConfiguration.derivedShellConfiguration()`.
  public func derivedShellConfiguration() -> ShellConfiguration {
    ShellConfiguration(
      defaultTimeoutSeconds: defaultTimeoutSeconds,
      allowedExecutablePaths: [gitExecutablePath],
      allowedWorkingDirectories: allowedWorkingDirectories
    )
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> WorktreeConfiguration {
    WorktreeConfiguration(
      gitExecutablePath: self.gitExecutablePath.isEmpty
        ? WorktreeConfiguration().gitExecutablePath
        : self.gitExecutablePath,
      defaultTimeoutSeconds: self.defaultTimeoutSeconds <= 0
        ? WorktreeConfiguration().defaultTimeoutSeconds
        : self.defaultTimeoutSeconds,
      branchPrefix: self.branchPrefix.isEmpty
        ? WorktreeConfiguration().branchPrefix
        : self.branchPrefix,
      worktreeDirectoryName: self.worktreeDirectoryName.isEmpty
        ? WorktreeConfiguration().worktreeDirectoryName
        : self.worktreeDirectoryName,
      allowedWorkingDirectories: self.allowedWorkingDirectories.isEmpty
        ? WorktreeConfiguration().allowedWorkingDirectories
        : self.allowedWorkingDirectories
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    gitExecutablePath =
      try container.decodeIfPresent(String.self, forKey: .gitExecutablePath) ?? "/usr/bin/git"
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 60.0
    branchPrefix =
      try container.decodeIfPresent(String.self, forKey: .branchPrefix) ?? "aura/orchestration-"
    worktreeDirectoryName =
      try container.decodeIfPresent(String.self, forKey: .worktreeDirectoryName)
      ?? ".aura-worktrees"
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories) ?? [
        "$HOME/*", "$TMPDIR/*",
      ]
  }
}
