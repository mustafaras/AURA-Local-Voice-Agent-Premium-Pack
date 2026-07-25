import AuraCore
import Foundation

/// Builds the verified `copilot -p` argument vector for a `CopilotRunRequest`.
///
/// Pure and unit-testable without spawning a process, mirroring
/// `CodexArguments.make`/`ClaudeArguments.make`. Invariants enforced
/// structurally rather than by convention:
/// - `--allow-all`/`--yolo`/`--allow-all-paths`/`--allow-all-urls` never
///   appear — structurally absent, not just avoided. Tool approval is
///   granted only via `--available-tools=`/`--allow-all-tools`, which (unlike
///   `--allow-all`/`--yolo`) leaves path and URL restrictions in force.
/// - `--remote`/`--remote-export`/`--share`/`--share-gist`/`--connect` never
///   appear — this adapter drives the local CLI only; see ADR-013 for why
///   cloud-agent execution is out of scope for this phase.
/// - The real objective is delivered via `Command.trailingArgument`, not
///   here: verified that `copilot -p` does not consume piped stdin as prompt
///   content (a real invocation's `user.message.content` never included
///   piped stdin text), so — unlike Codex/Claude — there is no wrapper-prompt
///   trick available; the objective must be the actual `-p` argument value.
public enum CopilotArguments {
  /// Build the argument vector (excluding the trailing objective value —
  /// callers set that via `Command.trailingArgument`). Throws if a requested
  /// working directory or `--add-dir` target falls outside
  /// `configuration.allowedWorkingDirectories`.
  public static func make(
    request: CopilotRunRequest,
    configuration: CopilotConfiguration
  ) throws(AuraError) -> [String] {
    try WorkingDirectoryAllowlist.requireAllowed(
      request.workingDirectory, allowedWorkingDirectories: configuration.allowedWorkingDirectories,
      makeError: AuraError.copilotError)

    var args: [String] = ["-C", request.workingDirectory]

    switch request.toolProfile {
    case .readOnly:
      args.append("--available-tools=")
    case .workspaceWrite:
      args.append("--allow-all-tools")
    }

    args.append("--disable-builtin-mcps")
    if !configuration.loadCustomInstructionsByDefault {
      args.append("--no-custom-instructions")
    }

    for directory in request.additionalWritableDirectories {
      try WorkingDirectoryAllowlist.requireAllowed(
        directory, allowedWorkingDirectories: configuration.allowedWorkingDirectories,
        makeError: AuraError.copilotError)
      args.append(contentsOf: ["--add-dir", directory])
    }

    if let credits = request.maxAICredits ?? configuration.maxAICredits {
      args.append(contentsOf: ["--max-ai-credits", String(credits)])
    }
    if let model = request.model {
      args.append(contentsOf: ["--model", model])
    }

    args.append(contentsOf: ["--output-format", "json", "--silent", "-p"])
    return args
  }
}
