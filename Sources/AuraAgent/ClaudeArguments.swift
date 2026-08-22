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

/// Maps a tool profile to the `--permission-mode` value.
///
/// `.readOnly` → `dontAsk` (deny any write; fail closed), `.workspaceWrite` →
/// `acceptEdits` (auto-approve edits confined to the worktree). Never
/// `bypassPermissions`.
public func claudePermissionMode(for toolProfile: ClaudeToolProfile) -> String {
  toolProfile == .readOnly ? "dontAsk" : "acceptEdits"
}

/// Builds the verified `claude -p` argument vector for a `ClaudeRunRequest`.
///
/// Pure and unit-testable without spawning a process, mirroring
/// `CodexArguments.make`. Invitation enforced structurally rather than by
/// convention:
/// - The permission mode is derived from the tool profile:
///   `.readOnly` → `--permission-mode dontAsk` (deny any write; fail closed,
///   exactly the unattended/CI-safe default), `.workspaceWrite` →
///   `--permission-mode acceptEdits` (auto-approve edits — verified live to
///   run under `-p` and produce a real file write — so a write-capable task
///   can actually produce a diff). It is never `bypassPermissions`.
/// - `--dangerously-skip-permissions`/`--allow-dangerously-skip-permissions`
///   never appear — structurally absent, not just avoided.
/// - A write-capable run is kept safe by the surrounding SP-013/SP-014
///   boundary, not by the flag alone: it requires an explicit policy grant
///   (`.agentClaudeRun`, `.destructive`), runs in an isolated `git` worktree,
///   is verified by a non-empty `git diff` postcondition (false-backend-success
///   fails closed), and the delivery/commit/push surface is separately gated.
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

    let isReadOnly = request.toolProfile == .readOnly
    let tools = isReadOnly ? configuration.readOnlyTools : configuration.workspaceWriteTools
    let permissionMode = claudePermissionMode(for: request.toolProfile)

    var args: [String] = [
      "-p",
      "--output-format", "stream-json",
      "--verbose",
      "--permission-mode", permissionMode,
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
