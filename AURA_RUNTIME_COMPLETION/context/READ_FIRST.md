# Read First — AURA Runtime Completion

Use this file at the beginning of every new session.

## Immediate procedure

1. Read `AGENTS.md`.
2. Read `AURA_RUNTIME_COMPLETION/prompts/SHARED_EXECUTION_CONTRACT.md`.
3. Parse and validate `AURA_RUNTIME_COMPLETION/state/current-state.json`.
4. Parse and validate `AURA_RUNTIME_COMPLETION/context/session-handoff.json`.
5. Confirm the active prompt exists in `AURA_RUNTIME_COMPLETION/prompts/prompt-manifest.json` and its dependencies are completed.
6. Verify live branch, `HEAD`, remote relation, and working tree before trusting stored commit values.
7. Record current user authority. No authority persists automatically from an earlier session.
8. Read the active prompt and only its phase-specific context.
9. Append a phase/session-start entry before editing.

## Source-of-truth hierarchy

When information conflicts:

1. live repository, official tool output, and verified runtime behavior;
2. accepted ADRs, policy code, and security specifications;
3. schema-valid `AURA_RUNTIME_COMPLETION/state/current-state.json` reconciled to live evidence;
4. newest relevant entry in `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md`;
5. `session-handoff.json`;
6. the active implementation prompt;
7. `docs/roadmap/AURA_FULLY_OPERATIONAL_ASSISTANT_MASTER_PLAN.md`;
8. legacy `ledger/CURRENT_STATE.md`, `SESSION_STARTER.md`, older prompts, and older prose claims.

## Critical current interpretation

The historical 0–25 implementation record is evidence that many subsystems were built and tested. It is not evidence that the intended assistant is fully operational.

Do not assume:

- a constructed service is user-reachable;
- a unit-tested adapter is live-ready;
- a deterministic fake proves production behavior;
- local signing equals Developer ID distribution;
- a design document equals an implemented update system;
- an emitted policy request equals an enforced policy decision;
- process exit success equals verified task success;
- historical “complete” language overrides current runtime evidence.

## Context hygiene

- Do not load the full historical project ledger unless investigating a specific prior decision or claim.
- Do not paste entire logs into context; use evidence IDs and concise summaries.
- Read direct production files before broad documentation when diagnosing behavior.
- Read tests alongside production code, but identify fake/test-only paths explicitly.
- Use `context-index.json` to select the smallest phase-relevant read set.

## Required reconciliation triggers

Stop feature work and reconcile state if any of these occur:

- `HEAD` differs from the stored verified commit without explanation;
- the active prompt dependencies are not genuinely complete;
- JSON does not validate;
- a capability state conflicts with production wiring;
- test counts or coverage claims cannot be reproduced;
- required toolchain/CLI/model versions differ;
- user-owned uncommitted changes overlap the intended scope;
- authority for a consequential action is missing;
- current APIs or flags are unverified.

## Completion language

Use precise terms:

- **implemented:** production code exists;
- **registered:** available through the capability registry;
- **reachable:** a user path can invoke it;
- **system-tested:** production composition was tested;
- **live-verified:** validated on real target hardware/service;
- **release-verified:** clean distribution evidence exists.

Only the final prompt may mark AURA `release_candidate_verified` or `released`.
