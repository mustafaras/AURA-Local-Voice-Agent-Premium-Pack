# Current State

This file is a compact, atomically replaced projection of the append-only ledger.
Projection refreshed from live Git and command evidence on 2026-07-28.

- Phase: Phase 23 Verified Plugin and Adapter Marketplace complete and remotely verified
- Active milestone: 20_RELEASE_READINESS → TTS_ROADMAP (parked) → 03_STREAMING_STT → 21_PROVENANCE_GRAPH_MEMORY → 22_DEEP_CONTEXT_RECONSTRUCTION → 23_VERIFIED_PLUGIN_MARKETPLACE
- Verified remote state before the final closing-evidence commit: `HEAD == origin/main == git ls-remote == df18fae305c94bdadf958bbe709e3328f17a4801`.
- Phase 23 commits: `8afdbf2b56b8003148508b0bbd8ae49ca389fefa` (implementation) and `df18fae305c94bdadf958bbe709e3328f17a4801` (implementation-hash state record).
- Implemented:
  - Signed manifest schema v1 with vendor/key identity, Ed25519 signature, SHA-256 payload binding, schemas, scoped permissions, bundle/domain/dependency allowlists, migration notes, and restrictive legacy decoding.
  - Vendor/key-ID trust, exact actor-scoped expiring grants, revocation, and explicit denial when a plugin has no active matching grant.
  - Versioned artifact installation, update, rollback, quarantine, uninstall, digest revalidation, executable-mode enforcement, and path/symlink containment.
  - Separate digest-pinned `AuraPluginHost` process with protocol/nonce/sandbox attestation, sanitized environment, bounded output collection, timeout, and repeated capability/target/hash checks.
  - Durable append-only plugin audit storage in `AuraStore` via migration `v1_4_0_plugin_audit`.
  - User-approved local marketplace sources; no implicit remote catalog or network entitlement.
- Verified evidence:
  - `AuraPluginsTests`: 37/37 pass.
  - Default full suite: 356/356 pass across 10 bundles; combined targeted/full evidence is 393 tests.
  - `AuraPluginHost` product and `AURA` target build with `-warnings-as-errors`; only known CommandLineTools linker search-path warnings remain.
  - Final app packaging, ad-hoc signing, strict signature checks, helper entitlement checks, and live helper sandbox self-attestation pass.
  - Final packaged app CDHash: `714da2b8f5c4e3b1f6777f8689ef7d20ada6e8ae`.
- Acceptance gate: Passed for the implemented local marketplace boundary. Unsigned/tampered/spoofed packages are rejected; grants cannot exceed signed scoped declarations; inactive plugins cannot reach runtime; uninstall removes artifacts while retaining audit history; adversarial spoofing, digest mismatch, and escalation tests pass.
- Resolved during validation:
  - Bare-helper packaging crashed because App Sandbox could not obtain a bundle identifier; the helper is now a nested application bundle with a fixed identifier and independent signature.
  - One audit timestamp test incorrectly required exact floating-point equality after ISO-8601 persistence; production fields were correct and the test now uses a sub-millisecond tolerance.
  - A system-TTS latency test exceeded its threshold only while multiple heavy builds ran concurrently; the required final suite was rerun serially and passed.
- Unresolved release/integration risks:
  - No public vendor PKI or remote marketplace catalog exists; sources and trust keys are user-controlled local configuration.
  - The v1 helper denies network at the OS entitlement layer even if a manifest declares domains.
  - Developer ID/notarized distribution and end-to-end execution of a real third-party signed payload remain release evidence; only the ad-hoc signed sandbox self-attestation is verified here.
  - `AuraKernel` does not yet construct the plugin runtime or expose a marketplace UI; the complete runtime factory is configuration-driven.
  - The artifact root must be deliberately located where the sandboxed helper can read it.
  - Filesystem, store, and policy lifecycle changes use compensating operations rather than a distributed transaction.
- Release status: No release, notarization, deployment, or public marketplace publication performed or authorized.
- Next safe action: Publish and verify the final closing-evidence commit, then begin Phase 24 — Self-Tuning Configuration and Feature-Flag Governance from the clean verified revision.
