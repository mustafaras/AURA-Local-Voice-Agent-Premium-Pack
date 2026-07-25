import AuraCore
import Foundation

/// A typed, policy-ready shell command.
///
/// `Command` carries an executable path and an argument array. It never
/// contains a raw shell string, so model-generated text cannot be directly
/// interpolated into a shell invocation.
public struct Command: Codable, Sendable, Equatable {
  public let executable: String
  public let arguments: [String]
  public let workingDirectory: String?
  public let environment: [String: String]
  public let timeoutSeconds: Double
  public let expectedExitCodes: Set<Int>
  public let riskTier: PermissionRiskTier
  public let ptyRequested: Bool
  public let filesystemEvidencePaths: [String]
  public let redactor: OutputRedactor

  /// Text delivered to the process's standard input, then closed for EOF.
  ///
  /// Use this instead of appending free-text (e.g. a model prompt) as a
  /// positional argument: `validate()` rejects arguments containing shell
  /// metacharacters (`;`, `|`, `&&`), which ordinary natural-language text
  /// routinely contains.
  public let standardInputText: String?

  /// A single free-text value appended as the final argv element, exempt
  /// from `validate()`'s metacharacter scan.
  ///
  /// Some CLIs (verified: GitHub Copilot CLI's `-p`) require a free-text
  /// value as a genuine CLI argument, not stdin — `standardInputText` alone
  /// cannot help. `Process`/`execve`-based spawning never invokes a shell to
  /// interpret argv, so a `;`/`|`/`&&` embedded in a single argv element is
  /// inert here; `validate()`'s scan over `arguments` is deliberate
  /// defense-in-depth for a threat model (shell reinterpretation) that does
  /// not apply to this one designated trailing value.
  public let trailingArgument: String?

  public init(
    executable: String,
    arguments: [String] = [],
    workingDirectory: String? = nil,
    environment: [String: String] = [:],
    timeoutSeconds: Double? = nil,
    expectedExitCodes: Set<Int> = [0],
    riskTier: PermissionRiskTier = .mutation,
    ptyRequested: Bool = false,
    filesystemEvidencePaths: [String] = [],
    redactor: OutputRedactor = .default,
    standardInputText: String? = nil,
    trailingArgument: String? = nil
  ) {
    self.executable = executable
    self.arguments = arguments
    self.workingDirectory = workingDirectory
    self.environment = environment
    self.timeoutSeconds = timeoutSeconds ?? 30.0
    self.expectedExitCodes = expectedExitCodes
    self.riskTier = riskTier
    self.ptyRequested = ptyRequested
    self.filesystemEvidencePaths = filesystemEvidencePaths
    self.redactor = redactor
    self.standardInputText = standardInputText
    self.trailingArgument = trailingArgument
  }

  /// The full argv array actually passed to the process: `arguments` plus
  /// `trailingArgument` if set.
  public var effectiveArguments: [String] {
    trailingArgument.map { arguments + [$0] } ?? arguments
  }

  /// Validate the command against configuration and safety rules.
  public func validate(configuration: ShellConfiguration) throws(AuraError) {
    guard !executable.isEmpty else {
      throw AuraError.shellError("executable must not be empty")
    }
    guard !executable.contains(" ") else {
      throw AuraError.shellError("executable must be a single path, not a shell command string")
    }
    guard !executable.contains(";") else {
      throw AuraError.shellError("executable path may not contain shell metacharacters")
    }
    guard timeoutSeconds > 0 else {
      throw AuraError.shellError("timeoutSeconds must be positive")
    }
    guard timeoutSeconds <= configuration.defaultTimeoutSeconds * 4 else {
      throw AuraError.shellError(
        "timeoutSeconds \(timeoutSeconds) exceeds maximum allowed \(configuration.defaultTimeoutSeconds * 4)"
      )
    }
    guard !arguments.contains(where: { $0.contains(";") || $0.contains("|") || $0.contains("&&") })
    else {
      throw AuraError.shellError("arguments may not contain shell metacharacters")
    }
    let disallowedEnvKeys = Set(environment.keys).subtracting(configuration.allowedEnvironmentKeys)
    guard disallowedEnvKeys.isEmpty else {
      throw AuraError.shellError(
        "environment keys \(Array(disallowedEnvKeys).sorted()) are not in the allowlist")
    }
    guard filesystemEvidencePaths.allSatisfy({ !$0.contains("..") }) else {
      throw AuraError.shellError(
        "filesystemEvidencePaths may not contain parent-directory references")
    }
    if !configuration.allowedExecutablePaths.isEmpty {
      guard
        configuration.allowedExecutablePaths.contains(where: {
          pathMatches(executable, pattern: $0)
        })
      else {
        throw AuraError.shellError("executable \(executable) is not in the allowlist")
      }
    }
    if let cwd = workingDirectory, !configuration.allowedWorkingDirectories.isEmpty {
      let expandedCWD = Self.expandPathVariables(cwd)
      guard
        configuration.allowedWorkingDirectories.contains(where: {
          pathMatches(expandedCWD, pattern: Self.expandPathVariables($0))
        })
      else {
        throw AuraError.shellError("working directory \(cwd) is not in the allowlist")
      }
    }
  }

  private static func expandPathVariables(_ path: String) -> String {
    var result = path
    let environment = ProcessInfo.processInfo.environment
    for (key, value) in environment where result.contains("$\(key)") {
      result = result.replacingOccurrences(of: "$\(key)", with: value)
    }
    if result.hasPrefix("~") {
      result = (environment["HOME"] ?? "/") + String(result.dropFirst())
    }
    return result
  }

  private func pathMatches(_ path: String, pattern: String) -> Bool {
    if pattern.hasSuffix("*") {
      return path.hasPrefix(String(pattern.dropLast()))
    }
    if pattern.hasPrefix("*") {
      return path.hasSuffix(String(pattern.dropFirst()))
    }
    return path == pattern
  }
}
