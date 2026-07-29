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
70% ratchet established from the 2026-07-28 measured 70.97% baseline. Raising
the ratchet to 80% is the next coverage objective; it must follow real tests,
not exclusions or a weakened denominator. The clean-profile bootstrap and
confirmation fail-closed paths are covered by `AURAIntegrationTests`.

Native control semantics, labels, hints, keyboard shortcuts, permission state,
and minimum control sizing are implemented in SwiftUI. Live TCC onboarding for
Microphone, Speech Recognition, Accessibility, and Screen Recording passed on
the target Mac. Full VoiceOver reading order, contrast, Dynamic Type, and real
generated-input behavior remain manual release checks; deterministic tests do
not substitute for that evidence.

The runtime integration bundle deterministically proves speech-to-silence
finalization, silent-session hard timeout, two consecutive stable STT turns,
exact retained-frame delivery without empty placeholder ingestion, propagation
of recognition failures into the conversation error state, and rejection of
recognition errors as user intent. Live human speech remains a target-Mac
acceptance check because synthesized system output is not a reliable
microphone source.

Chatterbox V3 has two additional local gates:

- `AuraAudioTests` injects a fake helper and playback boundary to prove Yelda
  fallback, asynchronous warm-up, prompt bounds, private output containment,
  artifact deletion, and stop behavior without producing audible test output.
- `PYTHONPATH=Runtime/chatterbox python3 -m unittest discover -s
  Runtime/chatterbox/tests -v` proves pinned model-manifest identity and hash
  enforcement plus bounded PCM reference validation. Python sources also pass
  `py_compile`.

Those deterministic gates do not establish perceptual quality. A complete
pinned snapshot, measured local diagnostic synthesis, owned/consented female
reference, and one human-listened Turkish turn are separate acceptance gates.
