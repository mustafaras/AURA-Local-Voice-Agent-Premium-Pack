import AuraCore
import Foundation

/// The fixed, harmless positional prompt passed to `claude -p`. The real
/// objective is delivered via `Command.standardInputText` instead — verified
/// against a real `claude -p` invocation (see
/// `Tests/AuraAgentTests/Fixtures/claude_smoke_success.jsonl`) to confirm
/// Claude Code treats piped stdin as the operative content even when the
/// positional prompt is only a generic wrapper.
public let claudeWrapperPrompt =
  "Follow the objective provided via standard input, then respond accordingly."

/// Builds the verified `claude -p` argument vector for a `ClaudeRunRequest`.
///
/// Pure and unit-testable without spawning a process, mirroring
/// `CodexArguments.make`. Invariants enforced structurally rather than by
/// convention:
/// - `--permission-mode dontAsk` is always present and never derived from
///   any parameter — `claude -p` has no TTY, and `dontAsk` is documented as
///   "the only safe choice" for unattended/CI runs (any other mode either
///   prompts, which blocks forever with no TTY, or bypasses checks entirely).
/// - `--dangerously-skip-permissions`/`--allow-dangerously-skip-permissions`
///   never appear — structurally absent, not just avoided.
/// - The real objective is never included here (see `claudeWrapperPrompt`).
public enum ClaudeArguments {
  /// Build the argument vector. Throws if a requested working directory or
  /// `--add-dir` target falls outside `configuration.allowedWorkingDirectories`.
  public static func make(
    request: ClaudeRunRequest,
    configuration: ClaudeConfiguration
  ) throws(AuraError) -> [String] {
    try WorkingDirectoryAllowlist.requireAllowed(
      request.workingDirectory, allowedWorkingDirectories: configuration.allowedWorkingDirectories,
      makeError: AuraError.claudeError)

    let tools =
      request.toolProfile == .readOnly
      ? configuration.readOnlyTools
      : configuration.workspaceWriteTools

    var args: [String] = [
      "-p",
      "--output-format", "stream-json",
      "--verbose",
      "--permission-mode", "dontAsk",
      "--tools", tools.joined(separator: ","),
    ]

    if !configuration.settingSources.isEmpty {
      args.append(contentsOf: [
        "--setting-sources", configuration.settingSources.sorted().joined(separator: ","),
      ])
    }

    for directory in request.additionalWritableDirectories {
      try WorkingDirectoryAllowlist.requireAllowed(
        directory, allowedWorkingDirectories: configuration.allowedWorkingDirectories,
        makeError: AuraError.claudeError)
      args.append(contentsOf: ["--add-dir", directory])
    }

    if configuration.ephemeralByDefault {
      args.append("--no-session-persistence")
    }
    if let budget = request.maxCostUSD ?? configuration.maxEstimatedCostUSD {
      args.append(contentsOf: ["--max-budget-usd", String(budget)])
    }
    if let model = request.model {
      args.append(contentsOf: ["--model", model])
    }

    args.append(claudeWrapperPrompt)
    return args
  }
}
