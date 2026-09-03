# EV-SP-022-20260826-LIVE-TASK-CONTROLS-04

- **Evidence ID:** `EV-SP-022-20260826-LIVE-TASK-CONTROLS-04`
- **Prompt / gap:** SP-022 / OPEN-10 / R9
- **Timestamp:** 2026-08-26T02:30:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == 4d6022fa83c5b880d3544234d62cab6ef78d674e`; working tree dirty (SP-022 slice + records + this live test, uncommitted at capture time)
- **Class:** Live backend-turn durable-task state-transition evidence (real claude CLI, user present / all authority granted)
- **Environment:** `AURA.app`/production source with the SP-022 Task Center slice; live `claude` CLI 2.1.246 at `/opt/homebrew/bin/claude`; approved scratch repo `~/.aura-sp014/approved-repo` (HEAD `d234839`); macOS 27 / Apple Silicon / Swift 6.4

## What was exercised live

Added and ran a focused SP-022 live test (`livePauseResumeTask`) in
`Tests/AuraAgentTests/SP014LiveAcceptanceTests.swift`, env-gated on the same
production path SP-014 already proves:
`AURA_SP014_LIVE_ACCEPTANCE=1 AURA_SP014_REPO=/Users/m_ras/.aura-sp014/approved-repo`.

It enqueues a real read-only coding task through the production
`CodingTaskCoordinator` → real `ClaudeAdapter` → real `claude` CLI, then drives
the durable-task state transitions on the live engine:

1. **Enqueue** → task reaches **`running`** (engine dequeues and starts the real
   claude turn). Asserted via `#expect(reachedRunning, ...)` — a hard failure if
   the backend never ran, so this is not a silent skip.
2. **Pause** → task transitions **`running` → `paused`**. Asserted:
   `#expect(paused?.state == .paused)`.
3. **Resume** → task re-enqueued with the same runner, transitions
   **`paused` → `pending`/`running`**. Asserted.

## Result (live run)

`AuraAgentTests` **238/238 passed**, including:
- `SP-022: live durable-task pause/resume state transitions on a real claude task` — **passed**
- `P1: read-only claude task` — passed (5.5 s real turn)
- `P2: write-capable task in isolated worktree produces a real diff` — passed (26 s real turn + diff)
- `P4: no commit/push/merge` — passed (approved repo HEAD unchanged)

`./scripts/aura-test.sh` → **Done. Failed bundles: 0**. The P1/P2/P4 durations
(5–26 s) prove the backend genuinely executes; the SP-022 pause/resume test
observes the real engine state changes on that live task.

## What this closes

The SP-022 live **durable-task pause/resume state transition** on a real backend
turn — the primary residual that kept SP-022 `in_progress`. Combined with
`EV-SP-022-20260826-LIVE-UI-01` (Capability Center task controls Ready/Local,
disabled reasons, Emergency Stop verified) and
`EV-SP-022-20260826-LIVE-DIALOGUE-02` (typed-input fail-closed + Task Center
truthful empty state), the SP-022 completion gate — "R9 users can understand and
control primary workflows without terminal intervention, with actionable
degraded states" — is now satisfied.

## Falsifier

A task reported `running`/`paused`/`running` that the live engine did not
actually enter, or a backend that reported `running` without launching a real
claude turn. The P1/P2/P4 real-turn durations rule out a fake/simulated backend.

## Limitations

- The live test uses the real claude CLI with auth+model left unverified
  (fail-closed) exactly as SP-013/SP-014 do; the task-control state transitions
  are engine-observed on that real task.
- `taskDelete` remains `.destructive`/deny-by-default (no destructive grant);
  deleting persisted task state is intentionally not exercised.
- A real TCC denial/revocation/restart recovery (a genuine System Settings
  permission change) is still not part of this run; the deterministic and live
  UI surfaces cover the disabled-reason and truthful-state requirements.

## Next safe action

SP-022 is now **completed** for its bounded OPEN-10 scope: deterministic slice +
live UI + live durable-task pause/resume + typed-input fail-closed evidence all
pass. Record the completion transition and open SP-023.
