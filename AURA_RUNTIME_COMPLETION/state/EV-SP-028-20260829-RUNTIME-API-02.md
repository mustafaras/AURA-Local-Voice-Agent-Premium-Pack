# EV-SP-028-20260829-RUNTIME-API-02

**Evidence ID:** EV-SP-028-20260829-RUNTIME-API-02
**Track:** SP-028 / R11 / OPEN-12
**Type:** Product source/build/test (contract)
**Commit:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` (HEAD -> main, origin/main) with uncommitted SP-028 working tree
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, CommandLineTools
**Authority:** User authorized source edits and local build/test. No live app launch, TCC mutation, signing, release, deploy, commit, push, or merge.

## Objective

Expose SP-028 lifecycle operations through the AuraKernel RuntimeAPI as direct-call methods guarded by capability policy, with truthful capability manifests registered as `.disabled` because no NLU/UI route is implemented.

## Exact work

Added `import AuraLifecycle` and the following direct-call RuntimeAPI methods in `Sources/AURA/AuraKernel_RuntimeAPI.swift`:

- `setLaunchAtLoginEnabled(_:)` / `isLaunchAtLoginEnabled()`
- `requestSafeMode()` / `clearSafeMode()` / `isSafeModeRequested()`
- `planReset(mode:)` / `executeResetPlan(_:)`
- `requestFactoryReset()` / `uninstallPlan(mode:)`
- `runMigrationPreflight()` / `exportSupportBundle(redacting:)`
- `checkForUpdate()` / `stageUpdate()` / `approveUpdate(_:)` / `rollbackUpdate()`
- `lifecycleRecordLaunch()` / `lifecycleRecordSleep()` / `lifecycleRecordWake()` / `lifecycleRecordCleanShutdown()`
- `isInCrashRecovery()` / `reconcileLaunchAtLogin()`

Added `public enum UninstallPlanMode` in `AuraKernel_RuntimeAPI.swift`.

All methods check `started` and `evaluateDirectCapability(.someCapability, directReason:)` before delegating to the constructed `AuraLifecycle` controllers. Capability manifests for these operations are registered as `.disabled` with the reason "direct AuraKernel RuntimeAPI only".

## Verification

- `swift build --target AURA --build-path /tmp/aura-build` — passed.
- `swift test --filter AuraLifecycleTests --build-path /tmp/aura-build` — 39 tests passed.
- `swift test --build-path /tmp/aura-build` — 89 tests passed.
- `python3 scripts/validate_second_pass_program.py` — PASSED.

## Scope and limitations

- These are kernel-level direct-call API wrappers, not user-facing NLU/UI routes.
- Live ServiceManagement calls, update downloads, and reset/uninstall execution remain gated by `PermissionRiskTier.network` and the local-only scope; no live system mutation occurred.

## Falsifier

A build failure in `AuraKernel_RuntimeAPI.swift`, missing `import AuraLifecycle`, or an unguarded direct capability call would falsify this evidence.
