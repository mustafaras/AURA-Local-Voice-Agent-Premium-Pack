import Foundation

/// Configuration for typed shell / process execution.
public struct ShellConfiguration: Codable, Sendable, Equatable {
  /// Default timeout for any shell command unless overridden by the command.
  public var defaultTimeoutSeconds: Double

  /// Maximum bytes captured from combined stdout and stderr for a single command.
  public var maxOutputBytes: Int

  /// Maximum lines captured from combined stdout and stderr for a single command.
  public var maxOutputLines: Int

  /// Environment variable keys that may be forwarded to child processes.
  public var allowedEnvironmentKeys: Set<String>

  /// Regex patterns that, when matched in output, are replaced with `<redacted>`.
  public var redactionPatterns: [String]

  /// Absolute paths or path globs that commands are allowed to execute.
  public var allowedExecutablePaths: Set<String>

  /// Directories that may be used as working directories.
  public var allowedWorkingDirectories: Set<String>

  public init(
    defaultTimeoutSeconds: Double = 30.0,
    maxOutputBytes: Int = 1_048_576,
    maxOutputLines: Int = 10_000,
    allowedEnvironmentKeys: Set<String> = [
      "HOME",
      "USER",
      "LANG",
      "PATH",
    ],
    redactionPatterns: [String] = [
      "\\b[0-9a-fA-F]{40}\\b",
      "sk-[a-zA-Z0-9]{48}",
    ],
    allowedExecutablePaths: Set<String> = [
      "/bin/*",
      "/usr/bin/*",
      "/usr/local/bin/*",
      "/Library/Developer/CommandLineTools/usr/bin/*",
    ],
    allowedWorkingDirectories: Set<String> = [
      "$HOME",
      "$TMPDIR",
    ]
  ) {
    self.defaultTimeoutSeconds = defaultTimeoutSeconds
    self.maxOutputBytes = maxOutputBytes
    self.maxOutputLines = maxOutputLines
    self.allowedEnvironmentKeys = allowedEnvironmentKeys
    self.redactionPatterns = redactionPatterns
    self.allowedExecutablePaths = allowedExecutablePaths
    self.allowedWorkingDirectories = allowedWorkingDirectories
  }

  public func validate() throws(AuraError) {
    guard defaultTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("shell defaultTimeoutSeconds must be positive")
    }
    guard maxOutputBytes > 0 else {
      throw AuraError.invalidConfiguration("shell maxOutputBytes must be positive")
    }
    guard maxOutputLines > 0 else {
      throw AuraError.invalidConfiguration("shell maxOutputLines must be positive")
    }
    for pattern in redactionPatterns {
      guard !pattern.isEmpty else {
        throw AuraError.invalidConfiguration(
          "shell redactionPatterns must not contain empty patterns")
      }
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    defaultTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .defaultTimeoutSeconds) ?? 30.0
    maxOutputBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? 1_048_576
    maxOutputLines =
      try container.decodeIfPresent(Int.self, forKey: .maxOutputLines) ?? 10_000
    allowedEnvironmentKeys =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedEnvironmentKeys)
      ?? [
        "HOME",
        "USER",
        "LANG",
        "PATH",
      ]
    redactionPatterns =
      try container.decodeIfPresent([String].self, forKey: .redactionPatterns)
      ?? [
        "\\b[0-9a-fA-F]{40}\\b",
        "sk-[a-zA-Z0-9]{48}",
      ]
    allowedExecutablePaths =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedExecutablePaths)
      ?? [
        "/bin/*",
        "/usr/bin/*",
        "/usr/local/bin/*",
        "/Library/Developer/CommandLineTools/usr/bin/*",
      ]
    allowedWorkingDirectories =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedWorkingDirectories)
      ?? [
        "$HOME",
        "$TMPDIR",
      ]
  }
}
