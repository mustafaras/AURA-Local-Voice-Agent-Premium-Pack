# ADR-028 — Verified Plugin and Adapter Marketplace

- **Status:** Accepted
- **Date:** 2026-07-28

## Context

ADR-020 created verification and lifecycle bookkeeping but explicitly
deferred isolation, distribution, versioned artifacts, key identity,
update/rollback, and durable audit to Phase 23. Its original empty-permission
mapping to `.any` is incompatible with Phase 23's no-escalation gate.

## Decision

1. Schema v1 signs deterministic JSON containing every identity, authority,
   schema, execution, and migration field.
2. Trust binds normalized vendor name and signed key ID; Ed25519 and SHA-256
   remain the local cryptographic primitives.
3. Capabilities require explicit non-`.any` patterns. Grants are expiring and
   actor-bound to `.plugin`; plugin actors never fall through to application
   default-tier permission when no active grant matches.
4. Marketplace sources are local and user-approved; no automatic remote
   download or network entitlement is introduced.
5. Payloads are versioned, rehashed at activation boundaries, retained for
   rollback, and removed on uninstall.
6. Update/rollback are destructive-tier and always leave the plugin disabled.
7. Plugin code never loads into AURA. A separately identified, digest-pinned
   `AuraPluginHost.app` verifies its App Sandbox entitlement and repeats
   manifest/request checks.
8. The helper is signed separately without network, microphone, or camera;
   the outer app is then signed without `--deep`.
9. Lifecycle and execution audits are append-only SQLite records.
10. Incomplete artifact/helper/hash configuration fails closed.

## Consequences

- Unsigned, wrong-key, broad-scope, modified, or artifact-tampered plugins
  fail before loading.
- Non-enabled plugins cannot cross the runtime boundary.
- Plugin grants cannot authorize user/system actors and expire automatically.
- Network-declaring plugins remain OS-denied by the v1 helper entitlement.
- Bare SwiftPM helper execution intentionally fails sandbox attestation. The
  ad-hoc signed nested helper passes the packaging self-attestation gate;
  Developer ID/notarized third-party payload execution remains release
  evidence.

## Migration

`v1_4_0_plugin_audit` creates `plugin_audit_records` and its plugin/timestamp
index. Existing configuration decodes new runtime fields as empty, disabling
execution. Existing registry JSON decodes absent artifact/history fields as
empty and requires fresh installation before execution.

## Rejected alternatives

- In-process loading: no memory/process isolation.
- Empty permissions as `.any`: silent escalation.
- Vendor display name as sole key selector: ambiguous rotation.
- `codesign --deep` with app entitlements: can broaden helper authority.
- `sandbox-exec`: deprecated/private operational dependency.
