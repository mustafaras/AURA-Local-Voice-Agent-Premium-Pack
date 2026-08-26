# EV-SP-022-20260826-TASK-CONTROLS-SOURCE-01

**Evidence ID:** `EV-SP-022-20260826-TASK-CONTROLS-SOURCE-01`
**Prompt:** SP-022 — UI Controls, Onboarding, and Recovery (R9)
**Evidence class:** Deterministic source + test slice
**Date:** 2026-08-26
**Branch/commit:** `main` `4d6022fa83c5b880d3544234d62cab6ef78d674e` (pre-change HEAD; working tree carries the change below)
**Environment:** macOS arm64, Swift 6.4 toolchain, Xcode 27.0.0-beta.5 SDK / Apple Swift 6.4 via `scripts/aura-test.sh`
**Scope / authority:** Deterministic source + test slice only. **No** app launch, no TCC mutation, no user-present live demonstration, no commit/push/merge, no release/sign/deploy. Authority: edit-only for delivery.

## Symptom / gap addressed (OPEN-10)

The R9 Task Center was a read-only projection of `TaskStatus` lifecycle fields.
It exposed only a cancel button and could not show *scope* metadata (coding
backend/model/workspace/health) because that information lived only inside the
opaque `TaskRequest.context` dictionary. The capability center was an
inspectable health projection with no task-lifecycle reachability, and the
`.reversible` Task Center controls (`task.cancel`/`task.resume`) had **no
seeded grant**, so under production `PolicyConfiguration` (which denies
`.reversible` by default) the buttons would be policy-denied before ever
reaching `AuraTaskEngine` — the exact silent-gap SP-006 fixed for the
filesystem/URL capabilities.

## Mechanism / root cause
- `TaskStatus` had no typed scope field; the coordinator's coding context keys
  (`agent.backend`, `coding.mode`, `coding.workspace`, `coding.backendHealth`)
  were invisible to the UI.
- `AuraTaskEngine` exposed `cancel`, `pause`, `resume`, `delete` but had **no
  `retry`** for the Task Center's manual retry control.
- `Capability.taskPause` and `Capability.taskRetry` did not exist; only
  `taskCancel`/`taskResume`/`taskDelete`/`taskEnqueue` existed, and none of the
  four `.reversible` task controls was seeded in `DefaultPolicyGrants`.

## Change
1. `AuraCore/TaskTypes.swift` — added `TaskScopeInfo` (backend/mode/workspace/
   backendHealth) and a `scope` field on `TaskStatus` (default `nil`).
2. `AuraTasks/AuraTask.swift` — `statusSnapshot()` now derives `scopeInfo`
   from the launch context; added `resetForManualRetry()`.
3. `AuraTasks/AuraTaskEngine_Queue.swift` — added `retry(id:runner:)`: a failed
   task resets to `pending` and re-enqueues, without consuming/re-arming the
   automatic retry budget; fails closed on any non-failed state.
4. `AuraCore/PolicyTypes_Capability.swift` — added `taskPause` and `taskRetry`
   (both `.reversible`).
5. `AuraIntent/InitialCapabilitySet_CapabilityDefinitions.swift` — added the
   `taskPause`, `taskResume`, `taskRetry` manifests and registered them
   `.ready`.
6. `AuraPolicy/DefaultPolicyGrants.swift` — seeded `.none`-confirmation grants
   for `taskCancel`, `taskPause`, `taskResume`, `taskRetry`. `taskDelete`
   (`destructive`) intentionally stays unseeded/deny-by-default.
7. `AURA/AuraKernel_RuntimeAPI.swift` — added `taskPause`, `taskResume`,
   `taskRetry` kernel methods, each through the same `evaluateDirectCapability`
   policy gate.
8. `AURA/AuraAppModel_ProductState.swift` — added `pauseTask`, `resumeTask`,
   `retryTask`.
9. `AURA/AuraMenuView_Tabs.swift` — Task Center now renders scope metadata and
   pause/resume/retry/cancel controls by state.
10. `AURA/ProductUIState.swift` — localized task-control/scope copy
    (`tasks.pause/resume/retry/backend/mode/health/workspace`).
11. Tests: `AuraTasksTests` retry + scope tests; `AuraPolicyTests` grant
    lifecycle test; `AURAIntegrationTests` R9 scope round-trip + copy;
    updated reachable-capability counts to 17 in `AuraIntentTests`/
    `AuraProductivityTests`.

## Verification (command / result)
- `swift build --product AuraTasks --product AuraPolicy --product AuraIntent`
  → Build complete.
- `./scripts/aura-test.sh` → **21/21 bundles PASSED, 0 failed bundles**;
  `AuraTasksTests` 16/16 (incl. 4 new), `AuraPolicyTests` 24/24,
  `AuraIntentTests` 153/153, `AuraProductivityTests` 70/70,
  `AURAIntegrationTests` (R9) pass.
- `python3 scripts/validate_second_pass_program.py` → **PASSED**.

## Evidence class
Deterministic unit/integration + validator. This is **not** live product
acceptance.

## Falsifier
A failing Task Center control on the live path, a scope projection that does
not match the launch context, or a manual retry that re-arms the retry budget.

## Residual / outside scope
- User-present onboarding denial/revocation/restart recovery (live, user
  present) — not exercised.
- Task live verification/diff/artifact presentation — coding-backend live turn
  remains blocked (no live backend turn; SP-013/SP-014 residuals).
- Live TCC permission repair, support-bundle generation, safe reset guidance —
  not exercised this session.
- `taskDelete` remains deny-by-default; an explicit grant for deleting persisted
  task state is intentionally not seeded.

## Next action
Run the SP-022 remaining live/manual gate (user-present onboarding recovery,
task live verification, support-bundle privacy, safe-reset guidance) and record
it in `EV-SP-022-...-LIVE-...`. SP-022 stays `in_progress`/`blocked` for that
live gate; SP-023 must not start.
