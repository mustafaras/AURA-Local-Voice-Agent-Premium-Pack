# AURA Runtime Completion

> **Canonical program root:** `AURA_RUNTIME_COMPLETION/`  
> **Program version:** 1.0.0  
> **Status:** Execution-ready; product implementation has not started

This directory is the single canonical home of the AURA Runtime Completion Program. It consolidates the master plan, executable implementation prompts, anti-amnesia context, machine state, ledgers, evidence registers, risks, decisions, and JSON Schemas.

## Start here

Open [`START_HERE.md`](START_HERE.md).

A fresh engineering session should initially read only:

1. repository-root `AGENTS.md`;
2. `AURA_RUNTIME_COMPLETION/prompts/SHARED_EXECUTION_CONTRACT.md`;
3. `AURA_RUNTIME_COMPLETION/state/current-state.json`;
4. `AURA_RUNTIME_COMPLETION/context/session-handoff.json`;
5. `AURA_RUNTIME_COMPLETION/context/READ_FIRST.md`;
6. the active prompt named by the state file.

## Directory map

```text
AURA_RUNTIME_COMPLETION/
├── README.md
├── START_HERE.md
├── MASTER_PLAN.md
├── prompts/
│   ├── README.md
│   ├── SHARED_EXECUTION_CONTRACT.md
│   ├── prompt-manifest.json
│   ├── 00_SESSION_BOOTSTRAP.prompt.md
│   ├── 01_R0_....prompt.md
│   ├── ...
│   └── 15_SESSION_CLOSEOUT.prompt.md
├── context/
│   ├── README.md
│   ├── READ_FIRST.md
│   ├── KNOWN_FACTS.md
│   ├── ACTIVE_CONTEXT.md
│   ├── context-index.json
│   └── session-handoff.json
├── state/
│   ├── README.md
│   ├── current-state.json
│   ├── capability-matrix.json
│   ├── PROGRAM_LEDGER.md
│   ├── DECISION_REGISTER.md
│   ├── RISK_REGISTER.md
│   └── EVIDENCE_INDEX.md
└── schemas/
    ├── program-state.schema.json
    ├── session-handoff.schema.json
    ├── evidence-record.schema.json
    ├── capability-matrix.schema.json
    ├── prompt-manifest.schema.json
    └── context-index.schema.json
```

## Source-of-truth order

1. live repository and command/runtime evidence;
2. accepted ADRs and security policy;
3. schema-valid `state/current-state.json` reconciled to live evidence;
4. newest relevant entry in `state/PROGRAM_LEDGER.md`;
5. `context/session-handoff.json`;
6. active implementation prompt;
7. `MASTER_PLAN.md`;
8. legacy prose and historical phase records.

## Compatibility links

The previous locations under `prompts/runtime_completion`, `ledger/runtime_completion`, `anti_amnesia/runtime_completion`, `schemas/runtime_completion`, and the old master-plan path are retained only as repository symlinks to this canonical directory. New documentation and code must use `AURA_RUNTIME_COMPLETION/...` paths.

## Completion rule

AURA must not be described as fully operational until `prompts/14_FINAL_ACCEPTANCE_AND_CLEANUP.prompt.md` passes with evidence and `state/current-state.json` reports `release_candidate_verified` or `released`.
