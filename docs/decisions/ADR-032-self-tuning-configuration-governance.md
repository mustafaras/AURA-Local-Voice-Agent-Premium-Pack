# ADR-032 — Self-Tuning Configuration and Feature-Flag Governance

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-07-29 |
| **Author** | Codex |
| **Supersedes** | — |

## Context

Phase 24 requires layered typed configuration, rollback, reversible migrations,
governed feature flags, and local recommendation generation. The Phase 19
threat model explicitly left one security gap for this phase: repository-owned
project configuration could otherwise weaken policy defaults. Existing
`AuraConfiguration` validation checks values in isolation but does not model
source trust, migration history, flag expiry, audit, or rollback.

## Decision

1. `AuraConfig` is a separate target depending only on `AuraCore` and
   `AuraStore`. It does not replace or bypass `PolicyEngine`.
2. Resolution order is fixed:
   secure defaults → machine policy → user settings → project settings →
   session overrides. Secure defaults are schema-owned. Session overrides are
   cleared on restart.
3. Each key has a registry-owned type, purpose, allowed layers, numeric bounds,
   sensitivity rule, and security merge constraint. Project and session layers
   may strengthen but cannot weaken security-sensitive values. A present
   machine policy remains an enforced bound for every lower-trust layer.
4. Unknown keys reject the whole patch with a durable warning. Sensitive
   values are rejected and must use the existing Keychain boundary.
5. The complete governance state is encoded as one versioned envelope and
   persisted with one SQLite upsert. Candidate state becomes effective only
   after that write succeeds.
6. Every accepted mutation first records a compatibility snapshot. Rollback
   restores a snapshot and persists it before it becomes effective. Schema
   migration steps declare exact from/to versions and reversible key mappings.
7. Feature flags require owner, purpose, future expiry, default, rollback plan,
   rollout percentage, and kill-switch state. Kill switch and expiry always
   disable a flag. Project enablement of an off-by-default flag requires
   registry-owned permission.
8. Rollout assignment uses a stable local hash bucket. User/project identifiers
   are evaluated in memory and are not copied into audit records.
9. Tuning accepts only non-negative finite aggregates for latency, errors,
   energy, and user correction. Collection and recommendation require explicit
   user opt-in. Recommendations contain numeric aggregate evidence and a plain
   explanation; they never apply until accepted.
10. Settings exposes effective-key count, changed values, audit count, and the
    local-recommendation opt-in. This is inspection and user control, not an
    authority surface for project files.

## Security and privacy impact

- A project cannot raise the allow-by-default risk ceiling, lower mandatory
  confirmation, widen a network allowlist, enable raw telemetry, or increase a
  machine-bounded local-model concurrency limit.
- No raw audio, transcript, screen content, prompt, filename, project ID, user
  ID, secret, or remote telemetry transport is present in the subsystem.
- Audit details are bounded and contain keys/actions rather than values or
  identifiers.
- Persistence failure leaves the prior in-memory and durable state effective.

## Migration and rollback

The initial schema is `1.0.0`. Future changes must add a
`ConfigurationMigration` with a forward and reverse mapping before changing
the current schema. Ten snapshots are retained by default as the compatibility
window. An unavailable path fails closed without replacing durable state.

## Alternatives rejected

- Merging raw JSON dictionaries and validating only afterward: source trust
  and security direction would be lost.
- Allowing project files to enable every off-by-default flag: a repository
  could turn an experimental authority surface on.
- Automatically applying recommendations: local metrics are evidence, not
  user authorization.
- Storing one row per key/change: partial persistence could expose a mixed
  effective configuration after interruption.

## Validation

`AuraConfigTests` covers normative layer order, override revocation,
project/machine non-weakening, unknown-key warnings, atomic failure,
restart-persistent rollback, ephemeral session expiry, flag metadata/expiry/
kill-switch/rollout/overrides, explicit telemetry opt-in, explainable
recommendation acceptance, and forward/reverse migration.
