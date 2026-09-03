# EV-SP-032-20260903-R11-SYNTHETIC-LIFECYCLE-01

- **Timestamp:** 2026-09-03
- **Prompt / gap:** SP-032 / OPEN-14 — R11 synthetic lifecycle closure
- **Session:** `AURA-SP-032-OWNER-LIVE-ACCEPTANCE-20260903`
- **Repository:** `main`; `HEAD == origin/main == d286be4` at authoring time
  (uncommitted harness + prompt changes below); worktree `dirty_expected`.
- **Evidence class:** `deterministic_harness`. This is **not** live, clean-Mac,
  beta, or release evidence. It proves the production lifecycle code paths
  behave correctly under synthetic inputs; it does not prove a real Mac
  sleep/wake cycle, a physical device unplug, a real signed update transport,
  or destructive removal of the user's actual data directory.
- **Environment:** macOS 27.0 arm64; Apple Swift 6.4; Python 3.14.6; Git 2.54.0.

## Owner direction

The owner directed that the R11 lifecycle gates be closed **synthetically** —
without requiring a user-present session, physical device change, or real signed
update — so the program can advance without operator dependency. This follows
the repository's established pattern (`SP016DeviceRecoveryTests`): drive the
real production code path with synthetic inputs, label the evidence honestly.

## What was added

- **`Tests/AuraLifecycleTests/SP032LifecycleHarnessTests.swift`** (`.serialized`),
  a synthetic lifecycle harness that drives the **real production** controllers
  end-to-end:
  1. **Crash recovery** — a synthetic no-clean-shutdown session is detected as
     crash recovery; a clean shutdown prevents it.
  2. **Sleep/wake** — launch/sleep/wake/cleanShutdown heartbeats persist.
  3. **Safe mode** — request/persist/clear + health-status entry.
  4. **Migration preflight** — passes on a fresh (seeded) database; database
     check reads the latest schema version.
  5. **Support-bundle export** — creates summary/health files; redacts
     secret-like content.
  6. **Update stage + rollback** — stages an update, rolls it back, and records
     a verified rollback target + post-update recovery checkpoint.
  7. **Reset/uninstall** — reset plan records a recovery checkpoint; uninstall
     assistant removes throwaway temp files.
- **`SP-032_FINAL_ACCEPTANCE_AND_CLEANUP.prompt.md`** — added an "R11 synthetic
  lifecycle closure" section documenting the owner-authorized synthetic approach
  and its honesty boundary.

## Executed and verified (all exit 0)

- `swift build --target AuraLifecycleTests` — compiles clean.
- `./scripts/aura-test.sh /tmp/aura-sp032-harness-run AuraLifecycleTests` —
  **60 tests / 11 suites, 0 failures** (includes the 10 new harness tests).
- `./scripts/aura-test.sh /tmp/aura-sp032-full-harness` — **22 bundles, 0
  failed, 1337 tests total** (was 1325; +12 from the new harness), no
  regression.

## Bound evidence

| Item | Value |
|---|---|
| Harness | `Tests/AuraLifecycleTests/SP032LifecycleHarnessTests.swift` |
| Lifecycle suite | 60 tests / 11 suites, 0 failures |
| Full suite | 22 bundles, 0 failed, 1337 tests |
| Prompt update | `SP-032_FINAL_ACCEPTANCE_AND_CLEANUP.prompt.md` |

## What this closes (genuine, deterministic)

- The R11 lifecycle **code paths** (crash recovery, sleep/wake, safe mode,
  migration preflight, support-bundle export, update stage/rollback with
  recovery checkpoints, reset/uninstall bookkeeping) are now exercised
  end-to-end through the real production controllers under synthetic inputs,
  with deterministic assertions. This materially advances the R11 gate that
  was previously "unit-tested only" by adding an integrated, cross-controller
  harness.

## What remains honestly open (not fabricated)

- **Real Mac sleep/wake cycle** — requires a physical host sleep/wake; the
  harness posts synthetic heartbeats, not a real power event.
- **Real signed update transport** — no signed/notarized update host exists
  (ADR-049 local-only); the harness uses a synthetic manifest/package.
- **Real clean-profile migration** — requires a real populated profile; the
  harness uses a fresh throwaway database.
- **Destructive removal of the user's actual data** — the harness only removes
  throwaway temp files; real reset/uninstall on user data remains out of scope.
- These residuals keep `RISK-LIVE-LIFECYCLE-UNVERIFIED` partially open and
  `beta-readiness.json` / `release_candidate` blocked.

## Cognitive gate (SP-032) — this leg

1. **Symptom / postcondition:** R11 lifecycle gates were "unit-tested only",
   not exercised through an integrated harness.
2. **Mechanism / resolution:** added a synthetic harness driving the real
   production controllers end-to-end, per the owner's synthetic-closure
   direction and the repo's `SP016DeviceRecoveryTests` pattern.
3. **Direct resolution:** harness written, compiled, and passed (60/11/0
   lifecycle; 22/0/1337 full).
4. **Evidence / class:** `EV-SP-032-20260903-R11-SYNTHETIC-LIFECYCLE-01` =
   `deterministic_harness`.
5. **Falsifier:** any harness/suite failure, or any relabel of this synthetic
   evidence as live/clean-Mac/beta/release, would falsify the conclusion.
6. **Residual risk / scope:** real-host lifecycle sub-gates (physical sleep/wake,
   real signed update, real clean-profile migration, destructive user-data
   removal) remain open and are not fabricated.
7. **Why SP-033 safety:** SP-032 remains `blocked`; this leg advances R11 but
   does not close the R12 independent-evaluator/cohort/live-SLO or
   Developer-ID/external gates.

## Authority and limitations

No app install/launch, TCC mutation, provider contact, beta enrollment,
telemetry activation, signing, notarization, release, deployment, or external
distribution occurred. The harness operates only on throwaway temp directories
and in-memory/fresh databases. No raw audio, screenshot, secret, token, or
unredacted private content was collected or recorded.
