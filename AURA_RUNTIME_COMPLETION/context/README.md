# AURA Runtime Completion — Anti-Amnesia System

This directory contains compact, replaceable context files for resuming the runtime-completion program in a new coding-agent session.

## Files

- `READ_FIRST.md` — mandatory startup rules and source-of-truth hierarchy.
- `KNOWN_FACTS.md` — stable evidence-backed facts that should not require rediscovery every session.
- `ACTIVE_CONTEXT.md` — concise human-readable current program context.
- `session-handoff.json` — machine-readable handoff from the previous session.
- `context-index.json` — context tiers, token budgets, and phase-specific read sets.

## Design rules

1. These files are not historical ledgers.
2. Keep them concise and atomically replace them when state changes.
3. Put command history and detailed evidence in `ledger/runtime_completion/`.
4. Put architectural rationale in ADRs.
5. Put stable product requirements in the master plan and specifications.
6. Do not copy full source files, logs, test output, email, documents, model output, or private content into anti-amnesia files.
7. Every factual status statement must be traceable to a repository commit or evidence ID.
8. When anti-amnesia files disagree with live repository evidence, live evidence wins and the files must be reconciled before feature work.

## New-session minimum read set

1. `AGENTS.md`
2. `prompts/runtime_completion/SHARED_EXECUTION_CONTRACT.md`
3. `ledger/runtime_completion/current-state.json`
4. `session-handoff.json`
5. `READ_FIRST.md`
6. the active prompt

Load `KNOWN_FACTS.md`, `ACTIVE_CONTEXT.md`, the capability matrix, ADRs, source files, tests, and historical ledgers only when the active prompt requires them.
