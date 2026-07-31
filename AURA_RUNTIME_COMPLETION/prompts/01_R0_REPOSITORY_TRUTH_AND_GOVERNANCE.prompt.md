# R0 — Repository Truth and Governance Repair Prompt

Execute only after BOOTSTRAP is `completed` and R0 is `ready` in `ledger/runtime_completion/current-state.json`.

## Mission

Make repository status, toolchain assumptions, completion claims, and evidence projection deterministic and contradiction-resistant. R0 must eliminate the conditions that allowed legacy state files to simultaneously describe work as both committed and uncommitted or to name obsolete next actions.

This track is complete when a new session can determine the real state without reading a long historical narrative.

## Phase-specific context

Read:

- current state, handoff, risk register, evidence index, capability matrix;
- `ledger/CURRENT_STATE.md`;
- `SESSION_STARTER.md`;
- newest relevant entries in `ledger/PROJECT_LEDGER.md`;
- `ledger/DECISION_INDEX.md`;
- `Package.swift`;
- `.github/workflows/ci.yml`;
- repository test/build/signing scripts;
- toolchain/environment instructions.

Do not load unrelated source targets.

## Required architectural decisions

Draft and accept, when supported by evidence:

- ADR-034 program ownership portions relevant to state projection;
- ADR-045 toolchain/deployment baseline portions relevant to development builds.

At minimum decide:

1. canonical machine state format;
2. how legacy prose state is generated, deprecated, or redirected;
3. what constitutes verified `HEAD` when state-only commits follow a tested code commit;
4. evidence classes and minimum evidence per capability status;
5. toolchain pinning strategy;
6. CI contradiction checks;
7. authority and user-owned-change recording.

## Implementation requirements

### A. State projection

Implement a deterministic repository-local state validator/projector that:

- parses all runtime-completion JSON files;
- validates against schemas;
- verifies prompt manifest files/dependencies;
- checks `HEAD`, branch, remote relation, and dirty state;
- checks referenced evidence/risk/gate IDs;
- ensures completed tracks have evidence;
- prevents a capability from being `live_verified` or `release_verified` without matching evidence class;
- detects impossible combinations such as `released` with open mandatory release gates;
- detects stale active prompt/dependency combinations;
- produces concise actionable errors.

Prefer a standard-library implementation or an already pinned dependency. Do not add a dependency without explicit authority and supply-chain review.

### B. Legacy state migration

Choose and implement one safe approach:

- generate `ledger/CURRENT_STATE.md` and `SESSION_STARTER.md` from the new JSON state; or
- replace their active-status content with a concise compatibility pointer while preserving historical ledger data; or
- move the active starter role to the new files and explicitly mark legacy files historical.

Do not rewrite append-only historical entries.

### C. Toolchain manifest

Create a machine-readable and human-readable toolchain contract containing:

- supported development and release toolchains;
- exact observed Swift/Xcode/SDK versions;
- whether any component is preview/snapshot;
- minimum deployment target strategy;
- Python/model helper versions and hashes;
- required CLI versions;
- validation command;
- compatibility/deprecation policy.

Add a bootstrap script that fails with actionable messages when the environment differs.

### D. CI governance

Add CI jobs or checks for:

- schema/state/manifest validation;
- generated-state drift;
- stale commit IDs;
- contradictory completion/release claims;
- prompt dependency integrity;
- ADR/decision-index consistency;
- evidence/gate consistency;
- existing build/test coverage gates.

Do not report CI as operational until an associated workflow run is observed.

### E. Capability matrix audit

Re-inspect the production composition and update `capability-matrix.json` for the audited commit. Each entry must distinguish implementation, runtime registration, user reachability, and verification class.

## Testing

Add deterministic tests for:

- valid program state;
- malformed JSON;
- schema violations;
- missing prompt files;
- dependency cycles;
- stale active prompt;
- completed track without evidence;
- released state with open gates;
- capability/evidence mismatch;
- dirty user-owned file preservation;
- legacy generated-state drift;
- unsupported toolchain.

Run repository formatting, changed-file checks, relevant tests, full validation, and the repository coverage gate if source code changes.

## Required evidence

Record at least:

- state/schema validator pass;
- capability audit result;
- toolchain inventory/validator pass;
- legacy state migration result;
- CI configuration validation;
- any actual CI run separately from local configuration proof.

## Completion gate

R0 is complete only when:

- one machine state is canonical;
- legacy active-status ambiguity is removed;
- toolchain assumptions are explicit and validated;
- prompt/state/evidence contradictions fail deterministically;
- capability matrix matches production reality;
- evidence and ADR indexes are consistent;
- a fresh session can identify R1 in the minimum read set;
- no product feature was falsely advanced.

Update R0 to `completed`, R1 to `ready`, append evidence/ledger entries, replace the handoff, and run `15_SESSION_CLOSEOUT.prompt.md`.
