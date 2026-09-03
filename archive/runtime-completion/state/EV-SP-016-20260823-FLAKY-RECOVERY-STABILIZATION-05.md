# EV-SP-016-20260823-FLAKY-RECOVERY-STABILIZATION-05 — SP-016 recovery tests stabilized

## Record

- **Evidence ID:** `EV-SP-016-20260823-FLAKY-RECOVERY-STABILIZATION-05`
- **Timestamp:** 2026-08-23T15:32:58Z
- **Branch / commit:** `main`; parent `5d0e9fcb08eab0cfe716be8d0b5b22b8b9e76409`; fix committed as `fe09539b4ecb8647ad3849f0354829daa8349e80`.
- **Prompt / gap:** `SP-016` / `OPEN-08` (R7).
- **Evidence class:** Deterministic system tests against the real `AuraAudio` actor with live audio hardware, plus repeated-run stability proof.
- **Trigger:** operator re-verification ("kusursuz kapanmadı mı"). This record corrects the flakiness of the recovery suite introduced under `EV-SP-016-20260822-RECOVERY-MATRIX-04`.

## Observed defect — the recovery suite was flaky

`EV-SP-016-20260822-RECOVERY-MATRIX-04` claimed `SP016DeviceRecoveryTests` was stable ("run twice with identical results (flakiness check)"). **That was false.** Running the suite independently three times, two runs failed on *different* tests:

- Run 1: `Sleep suspends capture and wake resumes it` failed (state never reached `.recovering`).
- Run 2: `A configuration change after stop never reopens the microphone` failed.
- Run 3: all passed.

The full-suite run also reported `AuraAudioTests` as the single failed bundle. The recovery capability was not deterministically proven.

## Root causes

Two distinct mechanisms, both real:

1. **Async observer registration race.** `AuraAudio.observeSleepWake()` and
   `observeConfigurationChanges()` used `Task { for await ... }` (plus
   `withTaskGroup`) subscriptions. `start()` could return before the
   `for await` loop had actually subscribed, so a notification posted
   immediately afterwards was **dropped forever** and the recovery handler
   never ran. No polling duration can fix a permanently lost notification.

2. **Cross-suite microphone contention.** Swift Testing's `.serialized`
   trait serializes tests **within one suite only**. `AuraAudioTests` and
   `SP016DeviceRecoveryTests` were separate suites, and both open the same
   real `AVAudioEngine` input device. Running them concurrently, two tests
   grabbed the microphone at once and tore each other's capture down, so
   whichever test lost the race failed (usually `startIgnoredWhenNotIdle` /
   `stateTransitionsThroughStartAndStop`, which live in `AuraAudioTests`).

## Direct change

- **`Sources/AuraAudio/AuraAudio.swift`:** replaced the async
  `Task { for await }` observer tasks with synchronous
  `NotificationCenter.addObserver` tokens
  (`configurationChangeObserver` / `sleepObserver` / `wakeObserver`). `start()`
  now returns only after the observers are guaranteed registered, so every
  posted notification deterministically reaches the handler. The old
  `configurationChangeTask` / `sleepWakeTask` fields were removed.
- **`Sources/AuraAudio/AuraAudio_Capture.swift`:** `observeConfigurationChanges()`
  and `observeSleepWake()` now register synchronous observers that dispatch to
  `Task { await ... }` handlers; added `removeObservers()`; `stop()` tears down
  observers before engine teardown so no late notification can reopen capture.
- **`Tests/AuraAudioTests/AuraAudioTests.swift`:** the hardware-opening tests
  (`stateTransitionsThroughStartAndStop`, `startIgnoredWhenNotIdle`,
  `privacyControlsUpdateEmitsIndicatorEvent`) were moved out of the ring-buffer
  suite into the serialized hardware suite, leaving only the deterministic,
  parallel-safe ring-buffer/immutability tests here.
- **`Tests/AuraAudioTests/SP016DeviceRecoveryTests.swift`:** now `.serialized`
  and holds **all** microphone-opening tests in one suite, and replaces the
  short fixed poll with a generous `waitUntil` helper
  (default 300 × 50 ms ≈ 15 s plus a final check), so a host-load-sensitive
  `AVAudioEngine` start/teardown cannot trip a bare timeout.

## Verification

- `AuraAudioTests` (consolidated serialized suite, 39 tests / 6 suites) ran
  clean **six consecutive independent times**:
  - 2026-08-23 single run: `Failed bundles: 0`.
  - Four-run loop (runs 1–4): runs 1, 2, 3 all `Failed bundles: 0`.
  - Confirm loop (runs A, B, C): all `Failed bundles: 0`.
  - Full suite `./scripts/aura-test.sh` → **21/21 bundles, Failed bundles: 0**
    (previously `AuraAudioTests` was the one failing bundle).
- Static diagnostics clean; `validate_second_pass_program.py` PASSED.

## Falsification

- Reverting to `Task { for await }` subscriptions makes the sleep/wake and
  configuration-change recovery tests fail intermittently again (dropped
  notification).
- Moving the hardware tests back into a non-serialized separate suite makes
  them fail intermittently again (concurrent microphone contention).
- Shortening `waitUntil` to a bare fixed 20–50 ms poll reintroduces
  host-load-bound failures on a busy machine.

## Scope & limitations

- This stabilizes the deterministic recovery suite only. It does not change
  the product's recovery behaviour (no headset is unplugged, no real CoreAudio
  route change, no real sleep cycle, no acoustic barge-in/echo). Those remain
  under `RISK-VOICE-RECOVERY-LIVE` for physical, user-present verification.

## Artifact paths

- `Sources/AuraAudio/AuraAudio.swift`
- `Sources/AuraAudio/AuraAudio_Capture.swift`
- `Tests/AuraAudioTests/AuraAudioTests.swift`
- `Tests/AuraAudioTests/SP016DeviceRecoveryTests.swift`
