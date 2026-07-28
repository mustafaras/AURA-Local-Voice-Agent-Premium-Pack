> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Multi-Agent Collaboration Protocol

## Patterns
### Planner → Implementer → Reviewer
Use for architecture-sensitive features.

### Parallel proposals → Adjudicator
Use for uncertain designs; proposals are read-only until selected.

### Implementer → Independent reviewer → Corrector
Use for substantial code changes.

### Specialist swarm
Use only when tasks are separable and worktrees prevent conflicts.

## Rules
- Every agent receives a bounded role.
- Reviewer must not rely solely on implementer's summary.
- Adjudication prioritizes tests, security, specification compliance, simplicity, and maintainability.
- Agents may disagree; the orchestrator records the disagreement.
- No infinite review loops; use bounded iterations and escalate unresolved conflict.
