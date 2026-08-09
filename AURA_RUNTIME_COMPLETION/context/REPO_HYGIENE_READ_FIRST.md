# Repository Hygiene — Read First

Use this bounded context order before every hygiene prompt. Load the minimum
needed slice; do not paste entire ledgers into a context window.

## Tier 0 — always read

1. `AGENTS.md`
2. `README.md`
3. `ledger/CURRENT_STATE.md`
4. `ledger/PROJECT_LEDGER.md` latest relevant entries and required metadata
5. `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_CONTROL_CONTRACT.md`
6. `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json`
7. `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_MANIFEST.json`
8. The active `H-*.prompt.md`

## Tier 1 — read for the active gap

- `docs/operations/REPO_HYGIENE_PROGRAM.md`, the matching `HYGIENE-*` section
- `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md` latest entries
- `AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md` and `RISK_REGISTER.md` matching IDs
- `AURA_RUNTIME_COMPLETION/context/ACTIVE_CONTEXT.md` relevant section
- The exact source, script, workflow, package, or fixture paths named by the prompt

## Context discipline

- Prefer headings, latest entries, hashes, and file-specific slices over full-file dumps.
- Treat chat recollection, old handoffs, and unstaged assumptions as untrusted until rechecked.
- Keep historical ledgers append-only; use an authored pointer when a summary is needed.
- At the end of a prompt, write a compact evidence summary and a next-action boundary.
- If Tier-0 projections disagree, stop and repair the control plane before changing code.
