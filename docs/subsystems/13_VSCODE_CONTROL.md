> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Visual Studio Code Adapter

## Preferred mechanisms
- `code` CLI for opening folders, files, workspaces, and extensions.
- VS Code extension API for editor state and commands.
- Integrated terminal PTY adapter for command execution.
- Accessibility only for unsupported UI actions.

## Capabilities
- Detect active workspace and repository.
- Open files and reveal symbols.
- Start tasks and tests.
- Read diagnostics through an extension bridge.
- Start or focus integrated terminal.
- Present agent diffs and task status.
- Preserve unsaved user changes.

## Restrictions
- Never close dirty editors without confirmation.
- Never assume the visible terminal working directory.
- Never inject commands into a terminal without verifying the target shell and workspace.

## R6 local policy, bridge, and bounded coding slice

The current local implementation passes the real `PolicyEngine` into
`VSCodeAdapter` and awaits the decision before any CLI, shell, or bridge route.
Missing policy, denial, and confirmation-required outcomes fail closed; a
confirmation transaction is not auto-approved by the adapter and must be
completed by the caller before retrying.

The file bridge now has an authenticated mode using a versioned envelope,
expected extension identity, HMAC-SHA256 integrity, nonce replay protection,
freshness bounds, and a maximum payload size. The default production bridge is
unavailable until authenticated configuration is supplied. The legacy plain
snapshot path exists only as an explicitly selected compatibility fixture for
tests.

Workspace resolution now fails closed on invalid or ambiguous candidates, with
precedence explicit target → active VS Code workspace → active durable task /
worktree → project candidate. Typed task/test bridge commands are bounded and
policy-mapped. Coding-agent backend health distinguishes executable/version/
interface evidence from authentication and model readiness; the production
coding route now enters the workspace/backend/worktree/durable-task coordinator
instead of bypassing it. Durable task execution has deadline and inactivity
watchdogs and latest-checkpoint recovery binding.

This remains integration-simulated, not live extension evidence. Extension
packaging, secret provisioning, complete live routes, backend authentication/
model readiness, user-facing progress/review, restart/resume acceptance, and
user-present acceptance remain open. ADR-041 therefore remains Proposed.
