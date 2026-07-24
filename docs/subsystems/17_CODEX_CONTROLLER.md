> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Codex Controller

## Integration
Use the current supported Codex CLI or programmatic interface after verifying installed version and official documentation.

## Responsibilities
- Authenticate through supported user configuration.
- Start tasks with explicit working directory and sandbox policy.
- Capture structured events when available.
- Map approvals into the AURA permission engine.
- Support cancellation and resume only when backend semantics permit.
- Record model, version, configuration, and task budget.

## Safety
Do not use dangerous bypass flags. Do not expose the full home directory when repository-scoped access is sufficient.
