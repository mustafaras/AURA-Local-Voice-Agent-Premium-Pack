# EV-SP-025-20260827-PLUGIN-TRUST-INCIDENT-ADR044-01

- **Prompt/Track:** SP-025 / R10 (OPEN-11)
- **Timestamp:** 2026-08-27 (slice authored); 2026-08-28 (independent-review completion)
- **Commit/Branch:** working tree on `main` (HEAD `bdcc810e4a2fca66da380044d6b062dab11e245e`; origin/main equal)
- **Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0.0-beta.5 toolchain
- **Evidence class:** Automated / contract + adversarial (deterministic; no live signed-helper or third-party payload run)

## Objective

Close the bounded SP-025 slice of OPEN-11: enforce plugin trust (vendor
roots, signatures, hashes, revocation, quarantine, SBOM, rollback, update,
unverified-code rejection) with compromised fixtures, complete the incident
and review-schedule documentation, and obtain an independent security review
covering the full ADR-044 scope (process topology, IPC, policy, OAuth,
network, computer use, updater, plugins).

## Changes delivered

- `Tests/AuraPluginsTests/PluginSupplyChainAdversarialTests.swift` (new, 7
  tests) — compromised-fixture matrix with real Ed25519 cryptography:
  - `compromisedHelperFailsClosedBeforeLaunch` — a helper whose SHA-256 does
    not match the pinned digest is never launched.
  - `tamperedInstalledArtifactBlocksEnableAndExecute` — a tampered installed
    artifact fails closed at enable and at execute.
  - `tamperedUpdateBundleIsRefused` — an update whose bundle bytes do not
    match the manifest's content hash is refused before storage; version
    unchanged.
  - `updateFromUntrustedVendorRootIsRefused` — an update signed by an
    attacker key (same vendor display name) is refused; version unchanged.
  - `tamperedRetainedArtifactBlocksRollback` — a tampered retained artifact
    blocks rollback; version unchanged.
  - `quarantineRevokesGrantsAndBlocksExecution` — quarantine revokes grants
    and blocks enable and execute (one-way valve).
  - `unapprovedSourceAndUnknownVendorNeverInstall` — an unapproved
    marketplace source and an unknown vendor root never install.
- `docs/operations/PLUGIN_SUPPLY_CHAIN.md` (new) — the deny-by-default plugin
  trust chain, lifecycle safety valves, SBOM/checksum scope, unverified-code
  rejection, and the compromised-fixture test matrix.
- `docs/operations/INDEPENDENT_SECURITY_REVIEW.md` (new) — the independent
  review plan, scope table (process topology, IPC, policy, OAuth, network,
  computer use, updater, plugins), independence rule, cadence, and findings
  tracker.
- `docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md` (new) — the
  in-session independent adversarial review of the plugin trust boundary.

## Verification

- `./scripts/aura-test.sh /tmp/aurabuild-sp025 "AuraPluginsTests"` — PASSED,
  44 tests (37 baseline + 7 new), 0 failed bundles.
- `./scripts/aura-test.sh /tmp/aurabuild-sp025-full` (full suite) — PASSED,
  21/21 bundles, 0 failed.
- `python3 scripts/validate_second_pass_program.py` — SECOND-PASS VALIDATION PASSED.

## Independent review (full ADR-044 scope)

An independent adversarial read with no authorship context covered all eight
ADR-044 areas — process topology/privilege separation, IPC/helper
authentication (SP-023), policy/confirmation, OAuth/Keychain, network
enforcement (SP-024), computer use, updater trust (R11/ADR-046), and plugin
trust. No Critical or High finding remained unresolved in any area: the
main app is non-sandboxed by documented decision with distinct helper trust
domains; helper IPC uses HMAC-SHA256 over exact bytes plus SecCode peer-identity
verification, replay/freshness/capability allowlists, and output/time bounds;
policy is deny-by-default with nonce/hash/plan-bound confirmation; the OAuth
callback binds loopback-only and the Keychain uses
`AfterFirstUnlockThisDeviceOnly`; every production URLSession goes through the
factory and redirects are refused; computer use checks emergency stop and
secure-field focus and routes every step through policy with semantic
postconditions; the updater is not implemented (design-only per ADR-046); and
plugin trust fails closed under the compromised-fixture matrix. The confirmed
enforcement points and residual limitations are recorded in
`docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md`.

## ADR-044 assessment

ADR-044 **remains Proposed**. The independent review it requires is now
complete for the deterministic/contract boundary with no Critical/High
unresolved finding. Its formal acceptance is owned by the release owner once
the full independent-review scope and any critical-finding resolution exist —
including a separately-provisioned external review and live
signed-helper/third-party-payload OS-confinement runs, which remain open under
later R10/R11/R12 work, not SP-025.

## Scope and limitations

- This is a **deterministic/contract + adversarial** slice. No live
  signed-helper execution or real third-party signed vendor payload was run.
- Public marketplace/vendor PKI and a signed, notarized update transport are
  **not** implemented (owned by R11/ADR-046).
- ADR-044 formal acceptance remains owned by the release owner.
- No raw audio, screenshots, secrets, tokens, private account data, or
  unredacted model output were written to any ledger or context file.
