# Configuration Migration and Recovery

## Current schema

The Phase 24 governance schema is `1.0.0`. Its durable envelope is stored under
`configuration.governance.state.v1` in AURA's existing SQLite store. It contains
configuration overrides, governed feature definitions, aggregate tuning
metrics, pending recommendations, rollback snapshots, migration history,
warnings, and audit records. It contains no secrets.

## Adding a schema version

1. Add or update registry-owned key definitions, including type, purpose,
   allowed layers, bounds, and security constraint.
2. Add a `ConfigurationMigration` with exact `fromVersion`, `toVersion`, and
   reversible key mappings.
3. Add forward and reverse tests, plus an interrupted-persistence test when the
   migration changes more than a name.
4. Add an adversarial project/machine-policy test for every security-relevant
   key.
5. Update ADR-032 and this document before activating the new schema version.

Loading fails closed when no compatible migration path exists. Migration is
performed on a candidate envelope; the previous durable state remains effective
unless the complete migrated envelope is written successfully.

## Rollback

The engine retains ten compatibility snapshots by default. A user-selected
rollback restores configuration layers and feature flags, migrates the snapshot
to the current compatible schema when necessary, and persists one complete
envelope before exposing it as effective. Rollback does not change Keychain
secrets, policy grants, plugin artifacts, model files, TCC permissions, or the
append-only project ledger.

Session overrides are intentionally ephemeral and clear on restart. Their
creation and expiry remain visible in the audit history.

## Recovery failure

If a snapshot is missing or outside the compatibility window, rollback is
rejected without changing active state. If SQLite persistence fails, the
candidate is discarded and the prior in-memory state remains active. Operators
should preserve the database, inspect the bounded error, and retry only after
storage health is restored.
