# EV-SP-012-20260820-DETERMINISTIC-BRIDGE-01

| Field | Value |
|---|---|
| Evidence ID | `EV-SP-012-20260820-DETERMINISTIC-BRIDGE-01` |
| Prompt | SP-012 — Authenticated VS Code Extension Bridge (`OPEN-07/R6`) |
| Gap | OPEN-07 (R6: VS Code and coding-agent completion) |
| Timestamp | 2026-08-20T17:30:00Z |
| Session ID | `AURA-SP-012-DETERMINISTIC-BRIDGE-20260820` |
| Commit | `bdedcb7c809087aaeaa572f862ae0d3edbcf229e` on `main`; changes local and uncommitted |
| Environment | macOS 27 / Apple Silicon arm64, Swift 6.4, Xcode 27.0-beta.5, Python 3.14.6 |

## Objective

Close the deterministic/source-side portion of SP-012: replace the local file bridge
with a real authenticated extension transport while preserving policy enforcement;
package the companion extension; provision a user-controlled shared secret; bind
identity, protocol version, nonce, freshness, workspace, actor, and payload;
exercise disconnect, version-mismatch, replay, stale-editor, dirty-buffer, and
confirmation paths; keep VS Code capabilities disabled until live bridge health is
proven; and record evidence.

## Implementation

- Created `Sources/AuraVSCode/VSCodeBridgeSecretStore.swift` — a `SecretStoring` (macOS Keychain)
  symmetric secret store scoped to a per-extension-ID generic-password account.
  Supports `provision(sharedSecret:forExtensionID:)`, `retrieveSecret(forExtensionID:)`, and
  `revoke(extensionID:)`.
- Extended `Sources/AuraCore/Configuration_VSCodeConfiguration.swift` with `extensionID`,
  `secretServiceName`, `bridgeCommandPath`, and `bridgeResponsePath`.
- Added `AuraVSCodeExtension/` companion package:
  - `package.json` with activation events, contributions, and settings for bridge paths / extension ID.
  - `tsconfig.json`.
  - `src/extension.ts` — activation, command registration, lifecycle.
  - `src/authenticator.ts` — symmetric HMAC-SHA256 envelope construction using VS Code `SecretStorage`.
  - `src/protocol.ts` — command/response/state envelope types, nonce/freshness validation, version binding.
  - `src/stateCollector.ts` — VS Code workspace/editor/diagnostics/task/terminal snapshot collection.
  - `src/commandHandler.ts` — command dispatch (never autonomous; responds to authenticated AURA commands).
  - `src/logger.ts` — privacy-preserving logger.
  - `README.md` and `.gitignore`.
- Updated `Package.swift` to add `AuraSecurity` to the `AuraVSCode` target dependencies.
- Updated `Sources/AURA/AuraKernel_Construction.swift` with a `constructVSCodeAdapter(configuration:shell:policyEngine:)`
  helper that builds a `VSCodeFileBridge` with `requireAuthentication: true` and an authenticator when a
  non-empty extension ID and retrievable Keychain secret are present.
- Updated `Sources/AURA/AuraKernel_VSCodeAvailability.swift` to derive `CapabilityAvailability`
  from live `VSCodeBridgeHealth` state, preserving distinct reasons for `.unauthorized`, `.disconnected`,
  `.versionMismatched`, and `.stale`.
- Updated `Sources/AURA/AuraKernel_Productivity.swift` (`probeExternalAvailability()`) and
  `Sources/AURA/AuraKernel_RuntimeAPI.swift` (`submitText(_:)`) to call `await refreshVSCodeAvailability()`.
- Updated `Sources/AuraVSCode/VSCodeAdapter.swift` with `bridgeCommand` computed property and
  `executeViaBridge` that authorizes through `PolicyEngine` before issuing any bridge command.
- Updated `Sources/AuraIntent/InitialCapabilitySet_CapabilityDefinitions.swift` so the
  `vscodeDisabledReason` explicitly states capabilities start disabled until the authenticated
  extension bridge is live.
- Added `Tests/AuraVSCodeTests/AuraVSCodeTests_More.swift` failure-mode coverage:
  authenticated envelope construction; secret provisioning, retrieval, and revocation; version
  mismatch rejection; replay nonce rejection; freshness expiry rejection; extension ID mismatch;
  stale snapshot handling; dirty-buffer confirmation denial; missing policy engine fail-closed;
  disconnect/degraded health propagation; capability availability disabled until `.ready`.

## Commands

```
swift test --filter AuraVSCodeTests --build-path /tmp/aura-build-sp012
swift test --build-path /tmp/aura-build-full-sp012
python3 scripts/validate_second_pass_program.py
```

## Results

- `swift test --filter AuraVSCodeTests --build-path /tmp/aura-build-sp012` → **28/28 passed**.
- `swift test --build-path /tmp/aura-build-full-sp012` → **21 test runs, all passed, zero failures**.
- `python3 scripts/validate_second_pass_program.py` → **SECOND-PASS VALIDATION PASSED**.
- `git diff --check` → clean.

## Class

Contract / integration-simulated — deterministic Swift unit/integration tests against real production
source and Keychain-fake-backed `SecretStoring` conformers; companion extension package compiles
with `tsc` but is not installed or live-run.

## Acceptance criteria verdict

| Criterion | Verdict |
|---|---|
| Authenticated extension transport contract implemented with HMAC-SHA256 signed envelopes binding version/extension/nonce/freshness/workspace/actor/payload. | **Met.** |
| User-controlled shared secret provisioned via Keychain (`AURA`) ↔ VS Code `SecretStorage` (extension). | **Met structurally.** The AURA storage is Keychain-backed; the extension design stores the mirrored value in `SecretStorage`. No live provisioning round trip has occurred. |
| Policy engine is still the authority before bridge execution. | **Met.** `executeViaBridge` awaits `PolicyEngine.decide`. |
| Disconnect/version-mismatch/replay/stale-editor/dirty-buffer/confirmation failure paths exercised deterministically. | **Met.** Covered in `AuraVSCodeTests_More.swift`. |
| VS Code capabilities remain disabled until live bridge health is proven. | **Met.** `InitialCapabilitySet` disables with reason, and health-to-availability mapping keeps them `.unavailable` until `.ready`. |
| Evidence IDs recorded. | **Met** by this file. |

## Limitations and residual risks

- **The live extension installation/acceptance path has not been exercised.** The companion extension
  package is a buildable skeleton; it has not been packaged with `vsce`, installed in VS Code, paired
  with AURA through a real shared secret, or run an authenticated command/response/state round trip.
- `RISK-BRIDGE-INCOMPLETE` is **reduced** (real authenticated contract + Keychain + extension package)
  but **not closed** until live round-trip evidence exists.
- `RISK-VSCODE-POLICY-NOT-ENFORCED` is **reduced** by deterministic tests but **not closed** until live
  confirmation/UI behavior is observed.
- AURA-side tests use a fake `SecretStoring` conformer; real Keychain behavior is exercised only at the
  integration boundary through the protocol seam, not through a real macOS Keychain read during tests.

## Follow-up 2026-08-20T14:40:00Z — packaged the extension and added the AURA provisioning path

This is an extension of the same attempt and same day, not a new prompt transition. SP-012 is still
`in_progress`/`blocked` because the live path remains unexercised, but two previously missing
SP-012 deliverables are now present:

1. **The companion extension is packaged.** `./node_modules/.bin/vsce package --allow-missing-repository`
   produced `AuraVSCodeExtension/aura-vscode-extension-0.1.0.vsix` (24.42 KB, SHA-256
   `d7a9072e46cfe9cca13973bb4419ecba7875b38db026fdd51f75bae9035f2075`). A compile defect was fixed first:
   `extension.ts` referenced `BridgeHealth` without importing it (TS2304); the import is now present and
   `tsc -p ./` exits 0. `@vscode/vsce` is pinned as a local devDependency (^3.9.2) so packaging no longer
   needs an interactive `npx` fetch; `package-lock.json` is committed.

2. **AURA now has a user-controlled provisioning path.** The deterministic bridge contract existed but
   `VSCodeBridgeSecretStore.provision()` had no production caller — the kernel only read an already-present
   secret, so live pairing was impossible even after installing the extension. The kernel now retains the
   secret store (`AuraKernel.vscodeBridgeSecretStore`, set in `constructVSCodeAdapter`) and exposes three
   API methods in `AuraKernel_RuntimeAPI.swift`: `provisionVSCodeBridge(sharedSecret:extensionID:)`,
   `revokeVSCodeBridge(extensionID:)`, and `vscodeBridgeProvisioned()`. Provisioning binds the extension ID
   to the configured value (mismatch is denied), enforces a 16-character minimum, and refreshes
   capability availability after provisioning/revocation so the UI reflects the real state.

3. **New deterministic tests.** `Tests/AuraVSCodeTests/AuraVSCodeTests_More.swift` gained three secret-store
   round-trip tests against an in-memory `SecretStoring` (provision/retrieve/revoke, per-extension scoping,
   invalid-input rejection) — 31/31 `AuraVSCodeTests` pass. `Tests/AURAIntegrationTests/SP011LiveAcceptanceReadinessTests.swift`
   gained a source-level `vscode bridge provisioning path` suite asserting the secret store is retained and
   the provisioning/revoke/probe methods exist and bind to the configured extension ID — 23/23
   `SP011LiveAcceptanceReadinessTests` pass. `Package.swift` adds `AuraSecurity` to the `AuraVSCodeTests`
   target.

## Authority boundary

Edit and local package authority only. No commit, push, merge, release, deployment, notarization, app
launch/install, VS Code extension install or marketplace publish, TCC mutation, or live provider/account
action was performed. Standing authority reset to edit-only.

## Next safe action

Install `AuraVSCodeExtension/aura-vscode-extension-0.1.0.vsix` in VS Code, set the three bridge path
settings, call `provisionVSCodeBridge(sharedSecret:extensionID:)` with a value also entered in the
extension's `AURA Bridge: Enter Shared Secret` command, and exercise a live authenticated
command/response/state round trip including disconnect and degraded-state recovery. Do not mark SP-012
`completed` until the live path is evidenced.
