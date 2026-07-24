> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Test Strategy

## Layers
- Pure unit tests for policies, schemas, parsers, state machines, and memory ranking.
- Contract tests for every adapter.
- Integration tests using temporary accounts, repositories, worktrees, and databases.
- UI tests for onboarding, permissions, confirmation, and emergency stop.
- Audio tests with synthetic, recorded, noisy, accented, Turkish, English, and code-switched samples.
- End-to-end golden scenarios.
- Adversarial security tests.
- Soak, performance, energy, and recovery tests.

## Determinism
Mock clocks, random sources, model outputs, process runners, and application adapters.
