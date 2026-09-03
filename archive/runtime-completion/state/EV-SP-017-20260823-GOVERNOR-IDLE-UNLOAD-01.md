# EV-SP-017-20260823-GOVERNOR-IDLE-UNLOAD-01 — R7 resource governor idle-unload control

## Record

- **Evidence ID:** `EV-SP-017-20260823-GOVERNOR-IDLE-UNLOAD-01`
- **Timestamp:** 2026-08-23
- **Branch / commit:** `main` working tree (edits uncommitted; SP-017 commit/push NOT granted).
- **Prompt / gap:** `SP-017` / `OPEN-08` (R7: Wake Word, STT/TTS Routing, and Resource Governor).
- **Evidence class:** Deterministic unit/system tests over `VoiceResourceGovernor` and `OllamaAdapter` governor routing.

## Symptom / missing postcondition observed

`VoiceResourceGovernor` declared `idleUnloadAfterSeconds` (default 300 s) in its
`VoiceResourceGovernorConfiguration`, and the R7 prompt (Resource governor, G)
explicitly requires **idle unload** as a required control. But the governor
**never implemented idle unload**: the field was dead configuration — no
reservation was ever dropped for inactivity, so a stale STT or neural-TTS
reservation could hold budget indefinitely on the 16 GB profile. This is a
concrete R7-G gap.

Additionally, the R7 prompt (G) and OPEN-08 stated that NLU/reasoning workloads
were "not yet admitted through the governor". The local `OllamaAdapter` (the
reasoning/classification/summarization path) had its own
`maxResidentModelBytes` budget but was **not** routed through the shared
`VoiceResourceGovernor`, so it could not observe the same memory-pressure /
thermal / circuit controls as STT and neural TTS.

## Mechanism / root cause

1. `VoiceResourceGovernor` tracked `reservations` and, in `reserve`, admitted
   bounded reservations against the 6 GB resident budget. It had no
   `lastActiveAt` map and no idle-unload sweep, so the `idleUnloadAfterSeconds`
   configuration was never read by any code path other than `validate()`.
2. `OllamaAdapter.preflight` (the admission gate for every reasoning /
   classification / summarization request) ran its own thermal + memory-budget
   checks but never consulted the shared `VoiceResourceGovernor`, so STT and
   neural TTS could not preempt or observe it, and it could not fail closed on
   a shared resident-budget denial.

## Direct change

- **`Sources/AuraCore/VoiceResourceGovernor.swift`**
  - Added `lastActiveAt: [VoiceWorkload: Date]` to track the last reserve/release
    activity per workload.
  - `reserve(...)` records `lastActiveAt[workload] = now()` on admission;
    `release(...)` records it on partial release and clears it on full release.
  - Added `@discardableResult unloadIdleReservations() -> [VoiceWorkload]` that
    drops any reservation whose last activity is older than
    `idleUnloadAfterSeconds`, returning the unloaded workloads so callers can
    mark the model not-ready.
  - `start()` now spawns an `idleUnloadTask` polling every half-window (min
    0.5 s) and invoking `unloadIdleReservations()`; `stop()` cancels it and
    clears `lastActiveAt`.
- **`Sources/AuraAgent/OllamaAdapter.swift`** — added an optional shared
  `resourceGovernor: VoiceResourceGovernor?` and helpers
  `voiceWorkload(for:)` (maps classification/summarization/reasoning →
  `.reasoning`), `reserveSharedGovernor(capability:)`, and
  `releaseSharedGovernor(capability:)`.
- **`Sources/AuraAgent/OllamaAdapter_Preflight.swift`** — `preflight` now
  reserves the shared governor's `.reasoning` budget before model routing; on
  denial it emits a budget-exceeded audit event and returns
  `.degraded(.budgetExceeded)` (fail closed).
- **`Sources/AuraAgent/OllamaAdapter_API.swift`** — every terminal inference
  method (`classify`, `structuredNLU`, `summarize`, `reason`) releases the
  shared reservation on success **and** on failure/degraded.
- **`Sources/AURA/AuraKernel_ConstructionExtensions.swift`** — the production
  `OllamaAdapter` is now constructed with the kernel's shared
  `voiceResourceGovernor`.

## Evidence class

- Deterministic unit/system tests (edit-only). No live model, microphone, TCC,
  provider, signing, release, commit, or push performed.

## Result (commands run)

- `swift test --filter 'VoiceResourceGovernorTests' --build-path /tmp/aura-sp017-build`
  → **7/7 PASS** (added 3 tests: idle-window unload, recent reservation
  survives, reserve-refreshes-activity).
- `swift test --filter 'OllamaAdapterTests' --build-path /tmp/aura-sp017-build`
  → **18/18 PASS** (added 2 tests: reasoning reserves-and-releases shared
  governor; reasoning fails closed and opens a circuit when the shared governor
  rejects).
- `swift test --filter 'ChatterboxTTSEngineTests|STTRouterTests'` → PASS
  (governor-dependent TTS/STT paths intact).
- `swift build --build-path /tmp/aura-sp017-build` → **Build complete**.
- Full suite `./scripts/aura-test.sh` → see `EV-SP-017-20260823-FULL-SUITE-01`.

## Falsification test

- If a future change removes `lastActiveAt`/`unloadIdleReservations` or breaks
  the activity-refresh invariant, the three new `VoiceResourceGovernorTests`
  fail.
- If the Ollama reasoning path stops consulting the shared governor (or leaks
  a reservation), `ollamaReasoningReservesAndReleasesSharedGovernor` and
  `ollamaReasoningDeniedWhenSharedGovernorRejects` fail.

## Residual risks (why outside this prompt's deliverable here)

- **Measured co-resident 16 GB soak** (`RISK-MODEL-MEMORY-PRESSURE`) is still
  open: the 6 GB governor budget + Ollama's own budget + STT/TTS residency are
  not measured co-resident on release hardware; idle unload and circuit
  breaking are the deterministic controls, not a measured soak.
- **Neural-TTS live first-audio / MPS qualification** (`RISK-NEURAL-TTS-LATENCY`)
  stays open: CPU is the qualified default, MPS opt-in, no human listening
  acceptance in this pass.
- **`screenVision` and `codingAgent` workloads** remain explicitly **not**
  admitted through the shared governor (bounded per-capture screen and spawned
  CLI subprocesses); documented as exclusions in `ADR-042` and OPEN-08.
- Human listening and physical barge-in/echo on real hardware stay
  `RISK-VOICE-RECOVERY-LIVE` (user-present only).

## Artifact paths

- `Sources/AuraCore/VoiceResourceGovernor.swift`
- `Sources/AuraAgent/OllamaAdapter.swift`
- `Sources/AuraAgent/OllamaAdapter_Preflight.swift`
- `Sources/AuraAgent/OllamaAdapter_API.swift`
- `Sources/AURA/AuraKernel_ConstructionExtensions.swift`
- `Tests/AuraCoreTests/VoiceResourceGovernorTests.swift`
- `Tests/AuraAgentTests/OllamaAdapterTests.swift`
