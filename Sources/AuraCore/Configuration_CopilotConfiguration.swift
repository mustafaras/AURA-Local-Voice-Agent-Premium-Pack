import Foundation

/// Configuration for the GitHub Copilot CLI adapter.
///
/// `copilot -p` (non-interactive mode) always runs with `--disable-builtin-mcps`
/// (the built-in `github-mcp-server` can create real, team-visible GitHub API
/// side effects — out of scope for local execution) and never with
/// `--allow-all`/`--yolo`/`--allow-all-paths`/`--allow-all-urls`/`--remote`/
/// `--remote-export`/`--share`/`--share-gist` (all unreachable by
/// construction). See ADR-013.
public struct CopilotConfiguration: Codable, Sendable, Equatable {
  /// Absolute path to the `copilot` CLI executable.
  public var executablePath: String

  /// Default timeout in seconds for a `copilot -p` invocation.
  public var defaultTimeoutSeconds: Double

  /// Hard ceiling on `timeoutSeconds` a caller may request for a single run.
  public var maxTimeoutSeconds: Double

  /// Maximum bytes captured from combined stdout/stderr for a single run.
  public var maxOutputBytes: Int

  /// Maximum lines captured from combined stdout/stderr for a single run.
  public var maxOutputLines: Int

  /// Soft AI-credit budget, enforced natively by the CLI via
  /// `--max-ai-credits` when set. `nil` disables credit-budget enforcement.
  public var maxAICredits: Int?

  /// Maximum number of files the CLI's own `result.usage.codeChanges
  /// .filesModified` may report before a run is flagged as having exceeded
  /// its file-write budget. This is a post-hoc observability check (the run
  /// has already finished by the time the final `result` is known), not a
  /// live pre-emptive cancel — the CLI does not stream a per-file-write event
  /// this phase's normalizer decodes.
  public var maxFileWritesPerRun: Int

  /// Whether repository custom instructions (`.github/copilot-instructions.md`,
  /// `AGENTS.md`, etc.) are loaded by default. When `true`, `CopilotAdapter`
  /// still scans them for secret patterns before every run regardless of
  /// `scanRepositoryInstructionsForSecrets`.
  public var loadCustomInstructionsByDefault: Bool

  /// Whether repository-customization files are scanned for secret-looking
  /// content before a run; a match causes the run to be refused.
  public var scanRepositoryInstructionsForSecrets: Bool

  /// Directories a run's working directory or `--add-dir` targets must fall
  /// under.
  public var allowedWorkingDirectories: Set<String>

  public init(
    executablePath: String = "/opt/homebrew/bin/copilot",
    defaultTimeoutSeconds: Double = 300.0,
    maxTimeoutSeconds: Double = 1800.0,
    maxOutputBytes: Int = 4_194_304,
    maxOutputLines: Int = 50_000,
    maxAICredits: Int? = nil,
    maxFileWritesPerRun: Int = 20,
    loadCustomInstructionsByDefault: Bool = true,
    scanRepositoryInstructionsForSecrets: Bool = true,
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
    self.maxAICredits = maxAICredits
    self.maxFileWritesPerRun = maxFileWritesPerRun
    self.loadCustomInstructionsByDefault = loadCustomInstructionsByDefault
    self.scanRepositoryInstructionsForSecrets = scanRepositoryInstructionsForSecrets
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  public func validate() throws(AuraError) {
    guard !executablePath.isEmpty else {
      throw AuraError.invalidConfiguration("copilot executablePath must not be empty")
    }
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("copilot defaultTimeoutSeconds must be positive")
    }
    guard maxTimeoutSeconds >= defaultTimeoutSeconds else {
      throw AuraError.invalidConfiguration(
        "copilot maxTimeoutSeconds must be at least defaultTimeoutSeconds")
    }
    guard maxOutputBytes > 0 else {
      throw AuraError.invalidConfiguration("copilot maxOutputBytes must be positive")
    }
    guard maxOutputLines > 0 else {
      throw AuraError.invalidConfiguration("copilot maxOutputLines must be positive")
    }
    if let maxAICredits {
      guard maxAICredits > 0 else {
        throw AuraError.invalidConfiguration("copilot maxAICredits must be positive when set")
      }
    }
    guard maxFileWritesPerRun > 0 else {
      throw AuraError.invalidConfiguration("copilot maxFileWritesPerRun must be positive")
    }
    guard !allowedWorkingDirectories.isEmpty else {
      throw AuraError.invalidConfiguration("copilot allowedWorkingDirectories must not be empty")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> CopilotConfiguration {
    CopilotConfiguration(
      executablePath: self.executablePath.isEmpty
        ? CopilotConfiguration().executablePath
        : self.executablePath,
      defaultTimeoutSeconds: self.defaultTimeoutSeconds <= 0
        ? CopilotConfiguration().defaultTimeoutSeconds
        : self.defaultTimeoutSeconds,
      maxTimeoutSeconds: self.maxTimeoutSeconds <= 0
        ? CopilotConfiguration().maxTimeoutSeconds
        : self.maxTimeoutSeconds,
      maxOutputBytes: self.maxOutputBytes <= 0
        ? CopilotConfiguration().maxOutputBytes
        : self.maxOutputBytes,
      maxOutputLines: self.maxOutputLines <= 0
        ? CopilotConfiguration().maxOutputLines
        : self.maxOutputLines,
      maxAICredits: self.maxAICredits,
      maxFileWritesPerRun: self.maxFileWritesPerRun <= 0
        ? CopilotConfiguration().maxFileWritesPerRun
        : self.maxFileWritesPerRun,
      loadCustomInstructionsByDefault: self.loadCustomInstructionsByDefault,
      scanRepositoryInstructionsForSecrets: self.scanRepositoryInstructionsForSecrets,
      allowedWorkingDirectories: self.allowedWorkingDirectories.isEmpty
        ? CopilotConfiguration().allowedWorkingDirectories
        : self.allowedWorkingDirectories
    )
  }

  /// A `ShellConfiguration` scoped to only ever launch the configured
  /// Copilot binary. `ShellConfiguration`'s own defaults do not include
  /// `/opt/homebrew/bin`, so callers must not widen the shared default
  /// configuration just to accommodate Copilot; a dedicated `AuraShell`
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
      ?? "/opt/homebrew/bin/copilot"
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 300.0
    maxTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .maxTimeoutSeconds) ?? 1800.0
    maxOutputBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 4_194_304
    maxOutputLines =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputLines) ?? 50_000
    maxAICredits = try container.decodeIfPresent(Int.self, forKey: .maxAICredits)
    maxFileWritesPerRun =
      try container.decodeIfPresent(Int.self, forKey: .maxFileWritesPerRun) ?? 20
    loadCustomInstructionsByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .loadCustomInstructionsByDefault) ?? true
    scanRepositoryInstructionsForSecrets =
      try container.decodeIfPresent(Bool.self, forKey: .scanRepositoryInstructionsForSecrets)
      ?? true
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories)
      ?? [
        "$HOME",
        "$TMPDIR",
      ]
  }
}
