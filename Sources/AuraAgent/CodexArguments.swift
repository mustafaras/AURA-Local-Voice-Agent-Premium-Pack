import AuraCore
import Foundation

/// Builds the verified `codex exec` argument vector for a `CodexRunRequest`.
///
/// Pure and unit-testable without spawning a process, mirroring
/// `VSCodeCLI.makeArguments(for:)`. Two invariants are enforced structurally
/// rather than by convention:
/// - `-a never` is always present and is never derived from any parameter —
///   `codex exec` has no TTY, so any other approval policy could block
///   forever waiting for input that can never arrive.
/// - The prompt is never included here. It is delivered via
///   `Command.standardInputText`, because `Command.validate()` rejects
///   arguments containing shell metacharacters (`;`, `|`, `&&`), which
///   ordinary natural-language prompts routinely contain.
public enum CodexArguments {
  /// Build the argument vector. Throws if a requested working directory or
  /// `--add-dir` target falls outside `configuration.allowedWorkingDirectories`.
  public static func make(
    request: CodexRunRequest,
    configuration: CodexConfiguration
  ) throws(AuraError) -> [String] {
    try WorkingDirectoryAllowlist.requireAllowed(
      request.workingDirectory, allowedWorkingDirectories: configuration.allowedWorkingDirectories,
      makeError: AuraError.codexError)

    var args: [String] = ["--json", "-a", "never", "-s", request.sandbox.cliValue]
    args.append(contentsOf: ["-C", request.workingDirectory])

    for directory in request.additionalWritableDirectories {
      try WorkingDirectoryAllowlist.requireAllowed(
        directory, allowedWorkingDirectories: configuration.allowedWorkingDirectories,
        makeError: AuraError.codexError)
      args.append(contentsOf: ["--add-dir", directory])
    }

    if configuration.ephemeralByDefault {
      args.append("--ephemeral")
    }
    if configuration.skipGitRepoCheckByDefault {
      args.append("--skip-git-repo-check")
    }
    if configuration.ignoreUserConfigByDefault {
      args.append("--ignore-user-config")
    }
    if let model = request.model {
      args.append(contentsOf: ["-m", model])
    }

    return args
  }
}
