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
- `AURA_RUNTIME_COMPLETION/context/REPO_HYGIENE_CONTEXT_SUMMARY.md` when present; it is a derived pointer, never a source of truth
- `AURA_RUNTIME_COMPLETION/repo-hygiene/H-009_ARCHITECTURE_AUDIT.md` for HYGIENE-09 architecture evidence
- The exact source, script, workflow, package, or fixture paths named by the prompt

## Separate remediation boundary — 2026-08-10

`ONAY: HYGIENE-REMEDIATION-01` was a separate remediation authority, not a
prompt transition. Its recoverable backup/clean-clone work, source/configuration
remediation, approved scanner/toolchain provisioning, and validation are
historical evidence. The later H-010 final remediation and hosted observation
closed the terminal hygiene gate; `REPO_HYGIENE_STATE.json` is now
`active_prompt=H-010`, `active_state=completed`, `program_status=completed`.
See `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01` and the latest
projection-reconciliation evidence. No H-011 exists.

## Context discipline

- Prefer headings, latest entries, hashes, and file-specific slices over full-file dumps.
- Treat chat recollection, old handoffs, and unstaged assumptions as untrusted until rechecked.
- Keep historical ledgers append-only; use an authored pointer when a summary is needed.
- Treat `REPO_HYGIENE_STATE.json` as the active-prompt authority and `current-state.json` as the audited product/content-baseline authority; a projection-only descendant must not be mistaken for a new product audit.
- At the end of a prompt, write a compact evidence summary and a next-action boundary.
- If Tier-0 projections disagree, stop and repair the control plane before changing code.
