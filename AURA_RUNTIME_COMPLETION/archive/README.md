# Archived execution documents

This directory contains completed execution artifacts that are no longer part
of the default fresh-session context.

## Current archive

`repo-hygiene/2026-08-12/` contains the terminal `H-000` through `H-010`
prompt definitions. `first-pass-prompts/2026-08-12/` contains completed
BOOTSTRAP/R0–R12 definitions, and `first-pass-context/2026-08-12/` contains
their superseded master-plan/startup/context prose plus the removed legacy
state-directory README. The relevant manifests and
`second-pass/SECOND_PASS_REFERENCE_INDEX.md` are the canonical locators.

Fresh sessions must not load this archive unless they are auditing historical
hygiene instructions. The second-pass program remains active at `SP-000` /
`pending`, and its prompt files remain in their canonical location.

## Archive invariants

- No historical ledger, evidence, risk, decision, ADR, or active handoff was moved.
- No pending `SP-*` prompt was moved.
- Archived prompt contents are preserved byte-for-byte; only their tracked path changed.
- ADR/subsystem `docs/` remain in place as named on-demand Tier-1 references.
- Reopening a historical hygiene prompt requires explicit user authority and a new state/evidence record.
