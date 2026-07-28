# Current State

This file is a compact, atomically replaced projection of the append-only ledger.
Projection refreshed from live Git and command evidence on 2026-07-28.

- Phase: Phase 23 Verified Plugin and Adapter Marketplace in progress
- Active milestone: 20_RELEASE_READINESS → TTS_ROADMAP (parked) → 03_STREAMING_STT → 21_PROVENANCE_GRAPH_MEMORY → 22_DEEP_CONTEXT_RECONSTRUCTION → 23_VERIFIED_PLUGIN_MARKETPLACE
- Active task: Implement schema-v1 verification, lifecycle update/rollback, versioned artifacts, scoped expiring grants, durable audit, and a fail-closed separate-helper runtime boundary.
- Verified base: `HEAD == origin/main == 37ff2992bf459d7d7faf0ea8038d90e691a80d51`.
- Phase 22 remote evidence: `git push origin main` advanced `58fb9be..37ff299`; local `HEAD`, `origin/main`, and `git ls-remote` all matched the full `37ff2992bf459d7d7faf0ea8038d90e691a80d51` hash.
- Baseline test: `./scripts/aura-test.sh /tmp/aurabuild-phase23-baseline AuraPluginsTests` passes 29/29, zero failed bundles.
- Current Phase 23 findings:
  - Phase 19 already verifies real SHA-256 payload hashes and Ed25519 signatures and gates lifecycle transitions through `PolicyEngine`.
  - Empty `requiredPermissions` currently expands to `[.any]`; Phase 23 must remove that authority escalation.
  - Vendor trust is keyed only by display name; schema v1 needs a signed key ID.
  - Update, rollback, versioned artifact cleanup, durable audit tables, and a separate-process execution path are absent by explicit Phase 19 design.
  - Existing app entitlements disable client/server networking. Phase 23 will not silently broaden them.
- Known environment constraint: Use `/tmp/aurabuild*`; Desktop/iCloud extended attributes can break SwiftPM ad-hoc codesign. CommandLineTools linker search-path warnings remain non-fatal.
- Safety boundary: No plugin executable is loaded in the AURA process. Runtime must fail closed if helper identity/protocol/sandbox attestation or manifest allowlist checks fail.
- Pending evidence: Phase 23 implementation, adversarial tests, warnings-as-errors build, full test suite, artifact/helper packaging validation, diff review, completion ledger/state, commits/pushes, and remote-hash verification.
- Release status: No release, notarization, deployment, or public marketplace publication is authorized.
- Next safe action: Implement restrictive schema-v1 validation and grants, then versioned artifact/audit storage and helper-process runtime dispatch.
