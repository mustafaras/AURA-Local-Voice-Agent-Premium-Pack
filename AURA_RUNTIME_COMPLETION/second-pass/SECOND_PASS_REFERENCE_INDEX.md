# Second-Pass Reference Index

This is the compact locator for the active second-pass work. It is not a new
authority layer and does not change prompt order or state.

## Default fresh-session surface

- `AGENTS.md`
- `AURA_RUNTIME_COMPLETION/prompts/SHARED_EXECUTION_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_MANIFEST.json`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`
- `AURA_RUNTIME_COMPLETION/state/current-state.json`
- `AURA_RUNTIME_COMPLETION/context/session-handoff.json`
- `AURA_RUNTIME_COMPLETION/context/ACTIVE_CONTEXT.md`
- the active `SP-*` prompt only

## On-demand Tier-1 references

Named ADRs, subsystem specifications, direct source/tests, and relevant ledger
slices remain under their canonical paths, primarily `docs/`, `Sources/`,
`Tests/`, `AURA_RUNTIME_COMPLETION/state/`, and `ledger/`. They are loaded only
when named by the active prompt or required by an evidence gate.

## Archived first-pass material

- Completed first-pass prompt definitions: `archive/first-pass-prompts/2026-08-12/`
- First-pass master plan and startup/context prose:
  `archive/first-pass-context/2026-08-12/`
- Legacy runtime-state directory guide:
  `archive/first-pass-context/2026-08-12/state-README.md`
- Completed repository-hygiene prompt definitions:
  `archive/repo-hygiene/2026-08-12/`

Archive contents are preserved for audit and explicit historical recovery; they
are excluded from default second-pass context.

## Boundary

`SP-000` remains the active pending prompt. This index does not complete it,
advance it, or alter any first-pass/product/release state.
