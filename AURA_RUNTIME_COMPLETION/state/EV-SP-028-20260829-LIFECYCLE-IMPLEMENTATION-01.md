# EV-SP-028-20260829-LIFECYCLE-IMPLEMENTATION-01

**Evidence ID:** EV-SP-028-20260829-LIFECYCLE-IMPLEMENTATION-01
**Track:** SP-028 / R11 / OPEN-12
**Type:** Product source/build/test (contract/integration-simulated)
**Commit:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` (HEAD -> main, origin/main) with uncommitted SP-028 working tree
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, CommandLineTools, Git 2.54.0
**Authority:** User authorized source edits, local build/test, and state/ledger updates. No sign, notarize, release, deploy, TCC mutation, app launch/install, provider contact, commit, push, or merge authority.

## Objective

Implement the SP-028 operational lifecycle slice: launch-at-login, update validation/staging, migration preflight, recovery checkpoints, rollback, safe mode, support bundle redaction, reset/uninstall/factory reset, and lifecycle event observation; wire the new `AuraLifecycle` subsystem into the AURA kernel and expose direct-call RuntimeAPI wrappers guarded by capability policy.

## Exact work

- Added `AuraLifecycle` library target to `Package.swift` with `ServiceManagement` linker dependency.
- Created 12 source files under `Sources/AuraLifecycle/` isolating all system-mutating operations behind protocols:
  - `LaunchAtLoginController` + `LaunchAtLoginControlling` (SMLoginItemSetEnabled wrapped for testability)
  - `UpdateValidator`, `UpdateStager`, `UpdateEngine` (local-only deterministic manifest/package validation; default production source returns `.noUpdateAvailable`)
  - `MigrationPreflight` (config/database/memory/plugin/model migrations behind `Migrating` protocol)
  - `RecoveryCheckpoint`, `RecoveryController`, `SafeModeController`, `RollbackController`
  - `ResetController`, `UninstallPlanner`, `SupportBundleExporter` (redaction protocol)
  - `LifecycleObserver` (launch/sleep/wake/clean-shutdown/crash recovery hooks)
- Extended core types:
  - `AuraCore`: `.lifecycle` ActorID, `.lifecycleError`, new RuntimeHealth states, `.network` PermissionRiskTier, lifecycle capabilities, `denyByDefaultTiers` includes `.network`
  - `AuraConfig`: lifecycle configuration keys including `lifecycle.factoryResetRequested`
  - `AuraStore`: lifecycle tables/indexes and `v1_7_0_lifecycle_recovery` migration record
  - `AuraMemory`: exhaustive `.lifecycle` ActorID switches
  - `AuraPolicy`: fixed exhaustive switch for `.network`
- Added `ApplicationSupportBootstrap.urlFor(directory:subpath:fileManager:)` for update staging root.
- Registered 11 lifecycle capability manifests in `InitialCapabilitySet_CapabilityDefinitions.swift`, truthfully `.disabled` with reasons "direct AuraKernel RuntimeAPI only".
- Wired lifecycle subsystems in `AuraKernel_Construction.swift` and added direct-call RuntimeAPI methods in `AuraKernel_RuntimeAPI.swift` guarded by `started` + `evaluateDirectCapability`.

## Verification

- `swift build --target AURA --build-path /tmp/aura-build` — passed.
- `swift test --filter AuraLifecycleTests --build-path /tmp/aura-build` — passed, 39 tests across 9 suites.
- `swift test --build-path /tmp/aura-build` — passed, 89 tests in 16 suites.
- `python3 scripts/validate_second_pass_program.py` — PASSED.
- `python3 scripts/validate_runtime_completion.py --ci` — PASSED.

## Artifacts

- Build/test logs: `/tmp/aura-build` (local SwiftPM build path chosen to avoid iCloud Finder extended-attribute codesign breakage).
- Evidence index references: `EV-SP-028-20260829-LIFECYCLE-IMPLEMENTATION-01`

## Scope and limitations

- This is source/build/contract evidence. All network-facing and system-mutating operations are behind protocols with in-memory/mock doubles used in tests.
- No live ServiceManagement login-item enablement, no live update download, no signed/notarized update transport, no real factory-reset execution, and no clean-machine recovery acceptance was performed.
- Launch-at-login is implemented and tested via the protocol boundary; live SMLoginItemSetEnabled behavior requires a signed/helper-packaged app and user consent, which are outside current authority.
- Update path is local-only: default production manifest source returns `.noUpdateAvailable`; deterministic validation/staging/rollback is exercised against synthetic fixtures only.
- ADR-046 remains Proposed pending direct operational evidence of signed update/rollback/recovery; SP-028 does not claim to close ADR-046 acceptance.

## Falsifier

Any Swift build error, failing lifecycle test, missing `AuraLifecycle` import in kernel files, or live system mutation outside protocol boundaries would falsify this evidence.
