> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Coding-Agent Orchestrator

## Supported backends
- Codex
- Claude Code / Claude Agent SDK
- GitHub Copilot CLI or cloud agent where appropriate
- Ollama local models

## Common task contract
- task ID
- repository and worktree
- objective
- constraints
- acceptance criteria
- allowed tools
- write scope
- budget
- deadline
- context bundle
- permission profile
- validation commands
- cancellation token

## Execution
- Prepare an isolated worktree for parallel write tasks.
- Stream structured events into a normalized event model.
- Enforce budgets and inactivity timeouts.
- Preserve complete raw backend logs in restricted local storage where configured.
- Convert outcomes into evidence-backed summaries.
- Never let backend-specific output bypass policy.
