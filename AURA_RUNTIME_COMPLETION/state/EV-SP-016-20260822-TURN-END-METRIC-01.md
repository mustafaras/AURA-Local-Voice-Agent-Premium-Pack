# EV-SP-016-20260822-TURN-END-METRIC-01 — SP-016 bilingual STT quality and voice recovery: deterministic metric/fail-closed slice

## Record

- **Evidence ID:** `EV-SP-016-20260822-TURN-END-METRIC-01`
- **Timestamp:** 2026-08-22T18:20:00Z
- **Branch / commit:** `main`; live `HEAD == origin/main == 94ee2be355046cab97189764e2a9dfb4f7efd57a` (SP-015). Working tree gains two intended edits; nothing committed or pushed (authority: edit-only for delivery).
- **Prompt / gap:** `SP-016` / `OPEN-08` (R7: Wake Word, STT/TTS Routing, and Resource Governor).
- **Command / procedure:**
  - `swift test --filter SP016TurnEndLatencyTests --build-path /tmp/aura-build-sp016` → **3/3 PASS**
  - `swift test --filter 'AuraSTTTests|AuraAudioTests' --build-path /tmp/aura-build-sp016` → AuraSTTTests 19/19, AuraAudioTests 35/35 PASS
  - `swift test --filter 'AURAIntegrationTests' --build-path /tmp/aura-build-sp016` → **78/78 PASS** (includes the new SP-016 suite)
  - `python3 scripts/validate_second_pass_program.py` → **SECOND-PASS VALIDATION PASSED**
- **Environment:** CommandLineTools Swift 6.4 on macOS (arm64), Swift Testing. No microphone, TCC, model, provider, signing, release, or delivery action performed.

## Symptom / missing postcondition observed

`STTPipeline.Metrics` recorded `firstPartialLatencySeconds` and `lastStableLatencySeconds` but exposed **no turn-end latency** — the elapsed time from activation to the first stable segment. The R7/R2 evaluation protocol explicitly requires a "turn-end latency" measurement (R7 prompt, Evaluation section), so the metric was absent even though the fail-closed gating logic (duplicate suppression via `consumedResultIDs`, error-never-stable, empty-never-stable) was already implemented.

## Mechanism / root cause

The `Metrics` struct simply lacked the field, and the stable-segment emission path (`STTPipeline.handleResult`) recorded `lastStableLatencySeconds` but not a dedicated turn-end value. No production behavior change was needed for correctness; the missing metric was a measurement gap.

## Direct change

- **`Sources/AuraSTT/STTPipeline.swift`:** added `turnEndLatencySeconds: TimeInterval` to `Metrics`, recorded it when a stable segment is emitted (set equal to `lastStableLatencySeconds`, i.e. `monotonicClock() - activationTime`), and reset it to `0` at the start of each new turn (matching `firstPartialLatencySeconds`).
- **`Tests/AURAIntegrationTests/SP016TurnEndLatencyTests.swift`:** new deterministic suite (3 tests) that proves (a) turn-end latency records activation→stable elapsed time, (b) it resets to zero at the start of a new turn, and (c) a non-stable/error transcript is never promoted to a stable (command-eligible) segment.

## Evidence class

- Deterministic system/contract tests (edit-only). NOT live WER/hardware evidence.

## Result

- SP016 suite 3/3 PASS; AuraSTTTests 19/19; AuraAudioTests 35/35; AURAIntegrationTests 78/78; validator PASSED. No regression.

## Falsification test

If a future change removes the `turnEndLatencySeconds` field or breaks the reset/record invariants, `SP016TurnEndLatencyTests` fails. If a bad transcript is ever emitted as a stable segment, the fail-closed test fails.

## Residual risks (why outside this prompt's deliverable here)

- **Live bilingual WER/entity corpus** (`RISK-STT-ROUTER-QUALITY`) is NOT closed: it requires Speech Recognition TCC authorization (`mutate_permissions:false` forbids it) and a bundled host carrying usage-description keys; the SwiftPM test helper is a bare binary (existing harness documents SIGABRT exit 134 if it requests authorization). The `BilingualSpeechRecognitionQualityTests` gate (`AURA_ENABLE_LIVE_SPEECH_TESTS=1`) remains opt-in/unrun.
- **Live hardware recovery matrix** (`RISK-VOICE-RECOVERY-LIVE`): barge-in, echo/self-transcription, headset/device switching, sleep/wake, interruption, permission revocation, and helper-crash recovery on release hardware remain unverified (live-manual, user-present). The user is speech-disabled; no speech-capable operator was authorized.
- **Neural-TTS/system-TTS scope, 16 GB soak, ADR-042 acceptance** remain open and belong to later R7 steps.

## Artifact path

- `Sources/AuraSTT/STTPipeline.swift`
- `Tests/AURAIntegrationTests/SP016TurnEndLatencyTests.swift`

## Limitations

- Deterministic metric/fail-closed slice only. This does **not** close `OPEN-08` or complete `SP-016`; it reduces a measurement gap and hardens the fail-closed invariant, while the live quality and recovery gates remain open. SP-016 must stay `in_progress`; SP-017 must not start until the completion gate is met or the affected capability is explicitly excluded.
