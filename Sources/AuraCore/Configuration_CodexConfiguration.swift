import Foundation

/// Configuration for the Codex CLI adapter.
///
/// `codex exec` is always invoked with `-a never` (hardcoded in `CodexArguments`,
/// never derived from configuration) since non-interactive runs have no TTY to
/// answer an approval prompt; this configuration only controls sandboxing,
/// timeouts, output bounds, and soft budgets.
public struct CodexConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `codex` CLI executable.
  public var executablePath: String

  /// Default timeout in seconds for a `codex exec` invocation.
  public var defaultTimeoutSeconds: Double

  /// Hard ceiling on `timeoutSeconds` a caller may request for a single run.
  public var maxTimeoutSeconds: Double

  /// Maximum bytes captured from combined stdout/stderr for a single run.
  public var maxOutputBytes: Int

  /// Maximum lines captured from combined stdout/stderr for a single run.
  public var maxOutputLines: Int

  /// Maximum number of file-change items tolerated before a run is cancelled.
  public var maxFileWritesPerRun: Int

  /// Soft token budget. `nil` disables token-budget enforcement (default,
  /// since `usage` field names are unverified pending live observation).
  public var maxTokensPerRun: Int?

  /// Soft estimated-cost budget in USD. `nil` disables cost enforcement.
  public var maxEstimatedCostUSD: Double?

  /// Price per token used to estimate cost from observed usage. `nil` means
  /// cost is never estimated, only raw token counts are reported.
  public var costPerTokenUSD: Double?

  /// Whether `--ephemeral` (skip session persistence) is passed by default.
  public var ephemeralByDefault: Bool

  /// Whether `--skip-git-repo-check` is passed by default.
  public var skipGitRepoCheckByDefault: Bool

  /// Whether `--ignore-user-config` (skip `~/.codex/config.toml`) is passed
  /// by default, favoring reproducibility over ambient user configuration.
  public var ignoreUserConfigByDefault: Bool

  /// Directories a run's working directory or `--add-dir` targets must fall
  /// under.
  public var allowedWorkingDirectories: Set<String>

  public init(
    executablePath: String = "/opt/homebrew/bin/codex",
    defaultTimeoutSeconds: Double = 300.0,
    maxTimeoutSeconds: Double = 1800.0,
    maxOutputBytes: Int = 4_194_304,
    maxOutputLines: Int = 50_000,
    maxFileWritesPerRun: Int = 20,
    maxTokensPerRun: Int? = nil,
    maxEstimatedCostUSD: Double? = nil,
    costPerTokenUSD: Double? = nil,
    ephemeralByDefault: Bool = true,
    skipGitRepoCheckByDefault: Bool = false,
    ignoreUserConfigByDefault: Bool = true,
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
    self.maxFileWritesPerRun = maxFileWritesPerRun
    self.maxTokensPerRun = maxTokensPerRun
    self.maxEstimatedCostUSD = maxEstimatedCostUSD
    self.costPerTokenUSD = costPerTokenUSD
    self.ephemeralByDefault = ephemeralByDefault
    self.skipGitRepoCheckByDefault = skipGitRepoCheckByDefault
    self.ignoreUserConfigByDefault = ignoreUserConfigByDefault
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  public func validate() throws(AuraError) {
    try validateRequiredValues()
    try validateOptionalValues()
  }

  private func validateRequiredValues() throws(AuraError) {
    guard !executablePath.isEmpty else {
      throw AuraError.invalidConfiguration("codex executablePath must not be empty")
    }
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("codex defaultTimeoutSeconds must be positive")
    }
    guard maxTimeoutSeconds >= defaultTimeoutSeconds else {
      throw AuraError.invalidConfiguration(
        "codex maxTimeoutSeconds must be at least defaultTimeoutSeconds")
    }
    guard maxOutputBytes > 0 else {
      throw AuraError.invalidConfiguration("codex maxOutputBytes must be positive")
    }
    guard maxOutputLines > 0 else {
      throw AuraError.invalidConfiguration("codex maxOutputLines must be positive")
    }
    guard maxFileWritesPerRun > 0 else {
      throw AuraError.invalidConfiguration("codex maxFileWritesPerRun must be positive")
    }
    guard !allowedWorkingDirectories.isEmpty else {
      throw AuraError.invalidConfiguration("codex allowedWorkingDirectories must not be empty")
    }
  }

  private func validateOptionalValues() throws(AuraError) {
    if let maxTokensPerRun {
      guard maxTokensPerRun > 0 else {
        throw AuraError.invalidConfiguration("codex maxTokensPerRun must be positive when set")
      }
    }
    if let maxEstimatedCostUSD {
      guard maxEstimatedCostUSD > 0 else {
        throw AuraError.invalidConfiguration("codex maxEstimatedCostUSD must be positive when set")
      }
    }
    if let costPerTokenUSD {
      guard costPerTokenUSD > 0 else {
        throw AuraError.invalidConfiguration("codex costPerTokenUSD must be positive when set")
      }
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> CodexConfiguration {
    let defaults = CodexConfiguration()
    return CodexConfiguration(
      executablePath: executablePath.isEmpty ? defaults.executablePath : executablePath,
      defaultTimeoutSeconds: Self.positive(
        defaultTimeoutSeconds, default: defaults.defaultTimeoutSeconds),
      maxTimeoutSeconds: Self.positive(maxTimeoutSeconds, default: defaults.maxTimeoutSeconds),
      maxOutputBytes: Self.positive(maxOutputBytes, default: defaults.maxOutputBytes),
      maxOutputLines: Self.positive(maxOutputLines, default: defaults.maxOutputLines),
      maxFileWritesPerRun: Self.positive(
        maxFileWritesPerRun, default: defaults.maxFileWritesPerRun),
      maxTokensPerRun: self.maxTokensPerRun,
      maxEstimatedCostUSD: self.maxEstimatedCostUSD,
      costPerTokenUSD: self.costPerTokenUSD,
      ephemeralByDefault: self.ephemeralByDefault,
      skipGitRepoCheckByDefault: self.skipGitRepoCheckByDefault,
      ignoreUserConfigByDefault: self.ignoreUserConfigByDefault,
      allowedWorkingDirectories: allowedWorkingDirectories.isEmpty
        ? defaults.allowedWorkingDirectories : allowedWorkingDirectories
    )
  }

  private static func positive(_ value: Double, default defaultValue: Double) -> Double {
    value > 0 ? value : defaultValue
  }

  private static func positive(_ value: Int, default defaultValue: Int) -> Int {
    value > 0 ? value : defaultValue
  }

  /// A `ShellConfiguration` scoped to only ever launch the configured Codex
  /// binary. `ShellConfiguration`'s own defaults do not include
  /// `/opt/homebrew/bin`, so callers must not widen the shared default
  /// configuration just to accommodate Codex; a dedicated `AuraShell`
  /// built from this narrow configuration is used instead.
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
      ?? "/opt/homebrew/bin/codex"
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 300.0
    maxTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .maxTimeoutSeconds) ?? 1800.0
    maxOutputBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 4_194_304
    maxOutputLines =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputLines) ?? 50_000
    maxFileWritesPerRun =
      try container.decodeIfPresent(Int.self, forKey: .maxFileWritesPerRun) ?? 20
    maxTokensPerRun = try container.decodeIfPresent(Int.self, forKey: .maxTokensPerRun)
    maxEstimatedCostUSD =
      try container.decodeIfPresent(Double.self, forKey: .maxEstimatedCostUSD)
    costPerTokenUSD = try container.decodeIfPresent(Double.self, forKey: .costPerTokenUSD)
    ephemeralByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .ephemeralByDefault) ?? true
    skipGitRepoCheckByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .skipGitRepoCheckByDefault) ?? false
    ignoreUserConfigByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .ignoreUserConfigByDefault) ?? true
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories)
      ?? [
        "$HOME",
        "$TMPDIR",
      ]
  }
}
