> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
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

## Enforced repository gate

`scripts/aura-test.sh` builds and executes all 18 Swift Testing bundles by
default. CI enables LLVM source coverage and rejects line coverage below the
70% ratchet established from the 2026-07-28 measured 70.63% baseline. Raising
the ratchet to 80% is the next coverage objective; it must follow real tests,
not exclusions or a weakened denominator. The clean-profile bootstrap and
confirmation fail-closed paths are covered by `AURAIntegrationTests`.

Native control semantics, labels, hints, keyboard shortcuts, permission state,
and minimum control sizing are implemented in SwiftUI. Live TCC onboarding for
Microphone, Speech Recognition, Accessibility, and Screen Recording passed on
the target Mac. Full VoiceOver reading order, contrast, Dynamic Type, and real
generated-input behavior remain manual release checks; deterministic tests do
not substitute for that evidence.
