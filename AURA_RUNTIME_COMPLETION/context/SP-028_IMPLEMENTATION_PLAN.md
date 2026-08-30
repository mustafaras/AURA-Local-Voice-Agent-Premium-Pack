# SP-028 Implementation Plan — Local-Only Lifecycle / Updater / Recovery / Migration

> Scope: close OPEN-12 gates that do **not** require signing, notarization,
> network distribution, TCC mutation, beta enrollment, or clean-machine evidence.
> All work is bounded by the current authority matrix: edit/test/state OK;
> sign/release/deploy/TCC/install/provider/network are not.

## Missing postconditions (OPEN-12 remainder)

1. No user-controlled launch-at-login controller, status surface, or tests.
2. No deterministic update manifest/package validator, stager, or adversarial
   tests for signed metadata, hash, version monotonicity, helper-protocol
   compatibility, path traversal, corruption, downgrade/replay.
3. No low-disk, interrupted-update, or kill-switch gating in the update path.
4. No migration preflight / rollback / recovery checkpoint abstraction or tests.
5. No safe-mode, reset, support-bundle redaction, uninstall/factory-reset
   semantics with tests.
6. No lifecycle/recovery capabilities in the policy registry.
7. No runtime health reporting for lifecycle subsystems in `AuraKernel`.

## Architectural decisions

- Add a single new library target `AuraLifecycle` (like `AuraMemory`,
  `AuraContext`) so the domain is testable without the `AURA` executable.
- `AuraLifecycle` depends on `AuraCore`, `AuraStore`, `AuraConfig`, and
  `AuraSecurity` (for `SecretScanner` used by support-bundle redaction).
- All system-mutating operations (`SMAppService.register`, bundle replacement,
  file deletion for reset/uninstall) are hidden behind protocols with
  production and mock/test implementations. Tests never call the production
  implementations, satisfying the authority boundary.
- Update engine is local-only: it can be handed a manifest URL or path, but
  the default production path returns `.noUpdateAvailable`. Tests exercise
  the validator with synthetic fixtures on disk.
- ADR-046 remains **Proposed**. This implementation delivers the in-process
  contract, validation, and recovery abstractions required by ADR-046, but
  does not accept the ADR (no external signed update has run).

## Files to add / modify

### Package structure
- `Package.swift`: add `AuraLifecycle` library target and `AuraLifecycleTests`
  test target; add `AuraLifecycle` dependency to `AURA` executable.

### AuraLifecycle source (`Sources/AuraLifecycle/`)
1. `LifecycleEventPayloads.swift` — typed events for launch-at-login,
   update, recovery, safe mode, support bundle.
2. `LaunchAtLoginController.swift` + `LaunchAtLoginService.swift` —
   protocolized `SMAppService` wrapper, user-intent persistence, status,
   enable/disable with approval, health reporting.
3. `LifecycleState.swift` + `LifecycleObserver.swift` — launch/crash/sleep/wake
   state machine with store-backed heartbeat and clean-shutdown flag.
4. `UpdateTypes.swift` — `UpdateManifest`, `UpdatePackage`, `UpdateValidation`
   Codable/Equatable models.
5. `UpdatePackageValidator.swift` — fail-closed deterministic validator.
6. `UpdateStager.swift` — atomic staging, previous-version backup, low-disk
   guard, interrupted-update detection/cleanup.
7. `UpdateEngine.swift` — orchestrates check/validate/approve/stage with
   kill-switch and feature-flag gating.
8. `MigrationPreflight.swift` + `RecoveryCheckpoint.swift` +
   `RollbackController.swift` — preflight reports, checkpoint/rollback contract.
9. `SafeModeController.swift` — safe-mode flag and recovery reset.
10. `SupportBundleExporter.swift` — redacted export of health, config,
    traces, ledger; excludes raw payloads/memory/screenshots/secrets.
11. `ResetController.swift` + `UninstallAssistant.swift` +
    `FactoryResetSemantics.swift` — dry-run plans, redacted file lists,
    preservation of audit/ledger/Keychain rules.

### AuraCore source
- `RuntimeHealth.swift`: add `requiresUserAction` and `safeMode` cases if
  needed; otherwise reuse existing statuses.
- `PolicyTypes_Capability.swift`: add lifecycle/recovery capabilities.
- `AuraError.swift`: add `lifecycleError` case.

### AuraConfig source
- `ConfigurationTypes.swift`: add lifecycle/update/recovery keys to the schema.

### AuraStore source
- `AuraDatabase_MigrationsAndBinding.swift`: add lifecycle/update/support
  tables and migration version `v1_7_0_lifecycle_recovery`.

### AURA app source
- `AuraKernel.swift`: add `lifecycleController`, `updateEngine`,
  `recoveryManager`, `safeModeController`, `supportBundleExporter` properties.
- `AuraKernel_Construction.swift`: construct the new subsystems after
  `constructFoundation` and record health.
- `AuraKernel_RuntimeAPI.swift`: expose query/status/runtime API methods.

### Tests
- `Tests/AuraLifecycleTests/LaunchAtLoginTests.swift`
- `Tests/AuraLifecycleTests/UpdatePackageValidatorTests.swift`
- `Tests/AuraLifecycleTests/UpdateStagerTests.swift`
- `Tests/AuraLifecycleTests/UpdateEngineTests.swift`
- `Tests/AuraLifecycleTests/MigrationPreflightTests.swift`
- `Tests/AuraLifecycleTests/SupportBundleExporterTests.swift`
- `Tests/AuraLifecycleTests/ResetAndFactoryResetTests.swift`
- `Tests/AuraLifecycleTests/SafeModeTests.swift`

## Deterministic evidence to collect

| Claim | Evidence ID prefix | How verified |
|---|---|---|
| Launch-at-login enable/disable | `EV-SP-028-LAUNCH-LOGIN` | Mock `SMAppService` tests + status persistence |
| Crash/sleep/wake recovery state | `EV-SP-028-RECOVERY-STATE` | Store heartbeat and clean-shutdown flag tests |
| Signed manifest/package validation | `EV-SP-028-MANIFEST` | Synthetic fixture tests: valid, tampered, unsigned, wrong id/version |
| Downgrade/replay protection | `EV-SP-028-DOWNGRADE` | Old manifest and stale timestamp fixtures |
| Atomic staging / rollback | `EV-SP-028-STAGE-ROLLBACK` | Temp directory staging/rollback tests |
| Kill switch | `EV-SP-028-KILLSWITCH` | Feature-flag kill-switch disables update |
| Low disk / corruption / interrupted | `EV-SP-028-ADVERSARIAL` | Injected disk/mock tests |
| Config/database migration | `EV-SP-028-MIGRATION` | Schema/table presence + config migration round-trip |
| Support-bundle redaction | `EV-SP-028-SUPPORT-BUNDLE` | Exported bundle content assertions |
| Safe mode / reset / uninstall semantics | `EV-SP-028-RESET` | Flag and dry-run plan tests |
| Capability registration | `EV-SP-028-CAPABILITY` | Registry contains lifecycle capabilities |
| Kernel health wiring | `EV-SP-028-HEALTH` | `AuraKernel` construction health snapshot test |

## Stop / blocker list

- If `swift build` fails after any structural change, stop and fix before
  adding more code.
- If any test requires real `SMAppService` registration, real bundle
  replacement, real network, or real file deletion, stop and replace with a
  protocol/mock.
- If ADR-046 acceptance is requested, block it: operational evidence for
  external signed update is outside authority.

## Next safe action after plan

Start with `Package.swift` and the `AuraLifecycle` target scaffolding, then add
`LaunchAtLoginController` and its tests, validating after each increment.
