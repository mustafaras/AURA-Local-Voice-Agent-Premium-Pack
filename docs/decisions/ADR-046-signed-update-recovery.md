# ADR-046 — Signed Updates, Rollback, and Recovery

- **Status:** Proposed
- **Date:** 2026-08-09
- **Owners:** AURA Runtime Completion Program
- **Scope:** R11 release engineering and continuous operations

## Context

AURA's current update document is design-only. A release mechanism must protect
the running application from tampered, replayed, downgraded, incompatible, or
partially installed artifacts while keeping installation user-controlled. The
main process is not yet a fully sandboxed network/update authority, and R9/R10
gates remain open, so this ADR defines the intended trust boundary without
claiming that the mechanism is active.

## Decision proposal

1. Use a maintained updater mechanism rather than custom cryptography. The
   current candidate is Sparkle 2 after dependency, license, sandbox, helper,
   and architecture review. Sparkle's EdDSA update signatures and Apple code
   signing must both validate; an unsigned or structurally invalid update is
   rejected.
2. Keep release metadata, appcast/update manifest, package, and release notes
   separate from user data. A manifest binds channel, semantic version, minimum
   OS, helper protocol, schema/migration compatibility, package SHA-256, and
   updater signature metadata.
3. Require explicit user approval before staging or installing an update. A
   check may notify only; it may not silently install, widen permissions, or
   mutate TCC.
4. Stage updates in a private, non-followable directory. Verify metadata,
   updater signature, package hash, bundle identifier, version monotonicity,
   helper compatibility, and Apple code-signing/notarization state before an
   install transaction begins.
5. Install atomically with a recoverable previous version and a migration
   preflight. The previous version remains available until the new version
   passes launch/readiness checks; failed migration or launch rolls back without
   changing Keychain secrets, TCC state, or the append-only project ledger.
6. Add a kill switch and channel policy that can stop a compromised release or
   freeze a vulnerable updater without accepting arbitrary remote instructions.
7. Keep safe mode, support-bundle export, reset, uninstall, and factory-reset
   operations explicit, redacted, auditable, and reversible where practical.

## Alternatives considered

- **Custom Ed25519/update cryptography:** rejected; it increases review and key
  rotation risk without improving the updater boundary.
- **Silent self-replacement by the main process:** rejected; it violates user
  control and complicates rollback and privilege separation.
- **App Store distribution:** deferred; it changes signing, update, and review
  authority and is outside the current pack.
- **Home-grown HTTP package replacement:** rejected; a mature updater must own
  signature verification, atomic staging, quarantine, and rollback semantics.

## Security and privacy impact

Update checks carry only public channel/version metadata. Tokens, account IDs,
memory, prompts, screenshots, and diagnostics are not sent. Package validation
must be fail-closed, must not follow arbitrary redirects, and must not execute
downloaded code before all trust and compatibility gates pass. Secret material
for any update-signing or notarization service remains outside the repository
and outside evidence logs.

## Migration

1. Add deterministic release manifest/checksum/SBOM generation and validation.
2. Select and review the updater dependency and license; pin it in the package
   lockfile and record its exact artifact hash.
3. Implement the user approval, staging, atomic install, migration preflight,
   rollback, safe-mode, and uninstall paths.
4. Add offline, downgrade, replay, corrupt-package, low-disk, interrupted-
   update, helper-protocol, and failed-migration tests.
5. Run clean-machine and user-present acceptance before accepting this ADR.

## Verification plan

- Structural manifest/checksum/SBOM tests pass with path-traversal, missing-file,
  hash, version, compatibility, and unsigned-release negative fixtures.
- The selected updater's official signature, channel, and rollback tests pass.
- A local-identity signed, hardened-runtime artifact passes `codesign --verify
  --deep --strict` and local launch checks. Developer ID signing, notarization,
  stapling, and external clean-machine Gatekeeper checks are permanently out of
  scope for the local-only product (ADR-049).
- Update, rollback, migration, safe mode, launch-at-login, support-bundle,
  uninstall, and recovery evidence is indexed with exact artifacts and logs.

## Consequences

R11 may produce a local, untrusted development artifact and deterministic
manifest evidence, but it must not label that artifact a release candidate.
ADR-046 remains Proposed until the local updater/rollback/recovery/safe-mode/
reset contract evidence exists and receives independent review; a real
externally signed update is out of the local-only scope (ADR-049).
