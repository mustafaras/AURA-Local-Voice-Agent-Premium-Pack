> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Claude Code Controller

## Integration
Use current Claude Code CLI or Agent SDK capabilities after verifying official documentation.

## Responsibilities
- Apply project settings, permissions, hooks, subagents, MCP, and session controls deliberately.
- Treat hooks as privileged code because they execute with user permissions.
- Normalize streaming output.
- Enforce allowed tools and deny rules in both Claude configuration and AURA policy.
- Record session and cost metadata where available.

## Review role
Claude may serve as architecture or security reviewer, but no model is a security boundary.
