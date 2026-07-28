> **Status:** Normative specification
> **Target:** macOS 26+ on Apple Silicon
> **Priority:** Safety → Correctness → Recoverability → Latency → Convenience

# Plugin and Adapter System

## Manifest schema v1

`PluginManifest` binds these fields into deterministic sorted JSON before
Ed25519 verification:

- schema version, reverse-DNS identity, and semantic version;
- vendor display name, vendor key ID, and signing algorithm;
- capability identities including risk tiers;
- input and output JSON schemas;
- resource permissions, supported application bundle IDs, and network domains;
- executable dependencies and relative entrypoint;
- grant lifetime, migration notes, audit level, and payload SHA-256.

Capabilities require at least one explicit scoped permission. `.any` is
invalid for a plugin manifest; an empty list is never broadened. Vendor trust
is keyed by normalized vendor name plus the signed key ID.

## Verification and local catalog

`PluginVerifier` executes structural validation, real SHA-256 comparison,
trusted-key lookup, then Ed25519 verification before artifact activation.
`PluginMarketplace` accepts packages only from a source the user approved.
Catalog presence grants no authority: install still passes policy,
verification, artifact, grant, persistence, and audit gates. Phase 23 adds no
network entitlement or automatic remote download.

## Artifacts and lifecycle

`PluginArtifactStore` writes immutable-mode, versioned payloads below one
configured root, resolves symlinks, and rehashes before enable, execute, or
rollback. `PluginRegistry` implements:

- install into non-actionable `.installed`;
- explicit enable and disable;
- one-way quarantine with immediate grant revocation;
- update only to a higher semantic version with the same ID/vendor/key;
- rollback only to a retained, locally rehashed version;
- uninstall with grant revocation and artifact removal while retaining
  lifecycle and immutable audit records.

Update and rollback create replacement grants and durable state before
revoking old grants. Persistence failure restores the old projection and
revokes the replacement grants. Both transitions return to `.disabled`.

## Capability grants

Each capability becomes a `Grant` with the manifest's exact patterns,
`subjectActor == .plugin`, a signed lifetime-derived expiry, and a purpose
bound to plugin ID/version. A plugin actor without a matching active grant is
denied before the application's default tier matrix, so expiry or revocation
cannot become implicit default authority. Execution repeats lifecycle, capability,
allowlist, policy, artifact hash, helper protocol, nonce, and sandbox checks.
Only `.enabled` can reach the helper or create runtime-success audit.

## Separate helper boundary

`AuraPluginHost` is embedded as
`Contents/Helpers/AuraPluginHost.app/Contents/MacOS/AuraPluginHost`, with a
signed `CFBundleIdentifier` required by App Sandbox. It checks its own
`com.apple.security.app-sandbox` entitlement through the installed SDK's
`SecTaskCreateFromSelf`/`SecTaskCopyValueForEntitlement` APIs and refuses to
run without it. Its entitlement file denies network, microphone, and camera.
The app pins the helper SHA-256 before launch. Both sides validate protocol,
nonce, manifest identity, capability, target allowlists, and payload hash.
Execution has bounded input/output and a 30-second timeout. Missing,
unpinned, unsandboxed, wrong-protocol, or non-attesting helpers fail closed.

`build-app-bundle.sh` embeds the helper. `codesign-adhoc.sh` signs it first
with restrictive entitlements, then signs the app without `--deep`, avoiding
propagation of the app's broader microphone/screen entitlements.

## Persistence and migration

Lifecycle projections remain in `aura.plugins.registry`. Missing Phase 23
record fields decode to restrictive empty values. Migration
`v1_4_0_plugin_audit` adds append-only `plugin_audit_records`; records retain
correlation IDs but no raw plugin payload.

## Tests and evidence boundary

`Phase23MarketplaceTests.swift` covers broad/implicit permission rejection,
key/migration spoofing, actor-scoped expiring grants, state-based runtime
denial, artifact tamper, update/rollback/uninstall, audit retention, and
source approval. Existing verifier tests cover bundle substitution, wrong
keys, capability/risk mutation, and permission widening.

The local packaging gate builds and ad-hoc signs a nested helper application,
verifies both signatures strictly, verifies the helper's restrictive
entitlements, and executes its sandbox self-attestation successfully. Developer
ID/notarized distribution and end-to-end execution of a real third-party signed
payload remain release evidence; they are not claimed by source tests.
