> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
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
