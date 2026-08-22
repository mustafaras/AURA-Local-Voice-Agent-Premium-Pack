import Foundation

/// Configuration for the Claude Code CLI adapter.
///
/// `claude -p` is invoked with a `--permission-mode` derived from the tool
/// profile (in `ClaudeArguments`): `.readOnly` uses `dontAsk` (deny-and-
/// continue, fail closed — the unattended-safe default), and `.workspaceWrite`
/// uses `acceptEdits` (auto-approve edits confined to the isolated worktree,
/// so a write-capable task can actually produce a diff). This configuration
/// controls tool availability, hooks/settings scoping, timeouts, output
/// bounds, and budgets.
public struct ClaudeConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `claude` CLI executable.
  public var executablePath: String

  /// Default timeout in seconds for a `claude -p` invocation.
  public var defaultTimeoutSeconds: Double

  /// Hard ceiling on `timeoutSeconds` a caller may request for a single run.
  public var maxTimeoutSeconds: Double

  /// Maximum bytes captured from combined stdout/stderr for a single run.
  public var maxOutputBytes: Int

  /// Maximum lines captured from combined stdout/stderr for a single run.
  public var maxOutputLines: Int

  /// Estimated-cost budget in USD, enforced natively by the CLI via
  /// `--max-budget-usd` when set. `nil` disables cost enforcement.
  ///
  /// Unlike `CodexConfiguration`, there is no `maxFileWritesPerRun`: the
  /// authorized smoke test ran with `--tools ""`, so `tool_use`/`tool_result`
  /// content-block field names were never observed and are not fabricated
  /// here. `.readOnly` tool profile prevents writes by construction (no
  /// write-capable tool exists in that tier) instead of by counting after
  /// the fact — see ADR-012.
  public var maxEstimatedCostUSD: Double?

  /// Whether `--no-session-persistence` is passed by default.
  public var ephemeralByDefault: Bool

  /// Which settings layers (`user`, `project`, `local`) `--setting-sources`
  /// loads. Defaults to `["user"]` only — excluding `project`/`local` means
  /// a target repository's own `.claude/settings.json`/`settings.local.json`
  /// (where hooks and `.mcp.json`-referenced servers are configured) never
  /// loads, while the operating user's own trusted `~/.claude/settings.json`
  /// still does. `--bare` (which also skips OAuth/keychain auth) is
  /// deliberately not the default; see ADR-012.
  public var settingSources: Set<String>

  /// Built-in tool names available in the read-only tier (`--tools`).
  public var readOnlyTools: [String]

  /// Built-in tool names available in the workspace-write tier (`--tools`).
  public var workspaceWriteTools: [String]

  /// Directories a run's working directory or `--add-dir` targets must fall
  /// under.
  public var allowedWorkingDirectories: Set<String>

  public init(
    executablePath: String = "/opt/homebrew/bin/claude",
    defaultTimeoutSeconds: Double = 300.0,
    maxTimeoutSeconds: Double = 1800.0,
    maxOutputBytes: Int = 4_194_304,
    maxOutputLines: Int = 50_000,
    maxEstimatedCostUSD: Double? = nil,
    ephemeralByDefault: Bool = true,
    settingSources: Set<String> = ["user"],
    readOnlyTools: [String] = ["Read", "Grep", "Glob"],
    workspaceWriteTools: [String] = ["Bash", "Read", "Edit", "Write", "Grep", "Glob"],
    allowedWorkingDirectories: Set<String> = [
      "$HOME",
      "$TMPDIR",
    ]
  ) {
    self.executablePath = executablePath
    self.defaultTimeoutSeconds = defaultTimeoutSeconds
    self.maxTimeoutSeconds = maxTimeoutSeconds
    self.maxOutputBytes = maxOutputBytes
    self.maxOutputLines = maxOutputLines
    self.maxEstimatedCostUSD = maxEstimatedCostUSD
    self.ephemeralByDefault = ephemeralByDefault
    self.settingSources = settingSources
    self.readOnlyTools = readOnlyTools
    self.workspaceWriteTools = workspaceWriteTools
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  public func validate() throws(AuraError) {
    guard !executablePath.isEmpty else {
      throw AuraError.invalidConfiguration("claude executablePath must not be empty")
    }
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("claude defaultTimeoutSeconds must be positive")
    }
    guard maxTimeoutSeconds >= defaultTimeoutSeconds else {
      throw AuraError.invalidConfiguration(
        "claude maxTimeoutSeconds must be at least defaultTimeoutSeconds")
    }
    guard maxOutputBytes > 0 else {
      throw AuraError.invalidConfiguration("claude maxOutputBytes must be positive")
    }
    guard maxOutputLines > 0 else {
      throw AuraError.invalidConfiguration("claude maxOutputLines must be positive")
    }
    if let maxEstimatedCostUSD {
      guard maxEstimatedCostUSD > 0 else {
        throw AuraError.invalidConfiguration("claude maxEstimatedCostUSD must be positive when set")
      }
    }
    guard !readOnlyTools.isEmpty else {
      throw AuraError.invalidConfiguration("claude readOnlyTools must not be empty")
    }
    guard !workspaceWriteTools.isEmpty else {
      throw AuraError.invalidConfiguration("claude workspaceWriteTools must not be empty")
    }
    guard !allowedWorkingDirectories.isEmpty else {
      throw AuraError.invalidConfiguration("claude allowedWorkingDirectories must not be empty")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> ClaudeConfiguration {
    ClaudeConfiguration(
      executablePath: self.executablePath.isEmpty
        ? ClaudeConfiguration().executablePath
        : self.executablePath,
      defaultTimeoutSeconds: self.defaultTimeoutSeconds <= 0
        ? ClaudeConfiguration().defaultTimeoutSeconds
        : self.defaultTimeoutSeconds,
      maxTimeoutSeconds: self.maxTimeoutSeconds <= 0
        ? ClaudeConfiguration().maxTimeoutSeconds
        : self.maxTimeoutSeconds,
      maxOutputBytes: self.maxOutputBytes <= 0
        ? ClaudeConfiguration().maxOutputBytes
        : self.maxOutputBytes,
      maxOutputLines: self.maxOutputLines <= 0
        ? ClaudeConfiguration().maxOutputLines
        : self.maxOutputLines,
      maxEstimatedCostUSD: self.maxEstimatedCostUSD,
      ephemeralByDefault: self.ephemeralByDefault,
      settingSources: self.settingSources.isEmpty
        ? ClaudeConfiguration().settingSources
        : self.settingSources,
      readOnlyTools: self.readOnlyTools.isEmpty
        ? ClaudeConfiguration().readOnlyTools
        : self.readOnlyTools,
      workspaceWriteTools: self.workspaceWriteTools.isEmpty
        ? ClaudeConfiguration().workspaceWriteTools
        : self.workspaceWriteTools,
      allowedWorkingDirectories: self.allowedWorkingDirectories.isEmpty
        ? ClaudeConfiguration().allowedWorkingDirectories
        : self.allowedWorkingDirectories
    )
  }

  /// A `ShellConfiguration` scoped to only ever launch the configured Claude
  /// binary. `ShellConfiguration`'s own defaults do not include
  /// `/opt/homebrew/bin`, so callers must not widen the shared default
  /// configuration just to accommodate Claude; a dedicated `AuraShell` built
  /// from this narrow configuration is used instead.
  public func derivedShellConfiguration() -> ShellConfiguration {
    ShellConfiguration(
      defaultTimeoutSeconds: defaultTimeoutSeconds,
      maxOutputBytes: maxOutputBytes,
      maxOutputLines: maxOutputLines,
      allowedExecutablePaths: [executablePath],
      allowedWorkingDirectories: allowedWorkingDirectories
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    executablePath =
      try container.decodeIfPresent(String.self, forKey: .executablePath)
      ?? "/opt/homebrew/bin/claude"
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 300.0
    maxTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .maxTimeoutSeconds) ?? 1800.0
    maxOutputBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 4_194_304
    maxOutputLines =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputLines) ?? 50_000
    maxEstimatedCostUSD =
      try container.decodeIfPresent(Double.self, forKey: .maxEstimatedCostUSD)
    ephemeralByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .ephemeralByDefault) ?? true
    settingSources =
      try container.decodeIfPresent(Set<String>.self, forKey: .settingSources) ?? ["user"]
    readOnlyTools =
      try container.decodeIfPresent([String].self, forKey: .readOnlyTools)
      ?? ["Read", "Grep", "Glob"]
    workspaceWriteTools =
      try container.decodeIfPresent([String].self, forKey: .workspaceWriteTools)
      ?? ["Bash", "Read", "Edit", "Write", "Grep", "Glob"]
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories)
      ?? [
        "$HOME",
        "$TMPDIR",
      ]
  }
}
