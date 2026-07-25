import AuraCore
import Foundation

/// Shared working-directory allowlist check used by `CodexArguments` and
/// `ClaudeArguments` to validate a run's working directory and any
/// `--add-dir`-style extra writable directories before they reach argv.
enum WorkingDirectoryAllowlist {
  static func requireAllowed(
    _ path: String,
    allowedWorkingDirectories: Set<String>,
    makeError: (String) -> AuraError
  ) throws(AuraError) {
    let expanded = expandPathVariables(path)
    let allowed = allowedWorkingDirectories.contains { pattern in
      let expandedPattern = expandPathVariables(pattern)
      return expanded == expandedPattern || expanded.hasPrefix(expandedPattern + "/")
    }
    guard allowed else {
      throw makeError("directory \(path) is not under an allowed working directory")
    }
  }

  static func expandPathVariables(_ path: String) -> String {
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
}
