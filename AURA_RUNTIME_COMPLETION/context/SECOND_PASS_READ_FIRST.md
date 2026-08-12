# Second-Pass Context Read Order

This is the Tier-0/Tier-1 context contract for every `SP-*` prompt. It keeps
the prompt chain anti-amnesic without loading the entire repository into every
session.

## Tier 0 — always read

1. `AGENTS.md`
2. `AURA_RUNTIME_COMPLETION/prompts/SHARED_EXECUTION_CONTRACT.md`
3. `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
4. `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json`
5. `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_MANIFEST.json`
6. `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`
7. `AURA_RUNTIME_COMPLETION/state/current-state.json`
8. `AURA_RUNTIME_COMPLETION/context/session-handoff.json`
9. `AURA_RUNTIME_COMPLETION/context/ACTIVE_CONTEXT.md`
10. the active `SP-*` prompt file

## Tier 1 — read only for the active prompt

- The named ADRs and subsystem specifications.
- The named production source and direct tests.
- The relevant slices of `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`,
  `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, and `PROJECT_LEDGER.md`.
- `second-pass/SECOND_PASS_REFERENCE_INDEX.md` when locating archived
  first-pass material or an on-demand ADR/subsystem reference.
- The previous prompt's closeout entry and evidence.

## Tier 2 — load only when blocked or required

- Full master plan or historical project ledger.
- Large logs/artifacts, external official documentation, or adjacent modules.
- A broader architecture audit when a layer-boundary failure is suspected.

## Session reconstruction record

At the beginning of each prompt, write a short private working summary with:

- active prompt and predecessor evidence;
- exact gap IDs and their current state;
- known facts versus assumptions;
- authority available and explicitly unavailable;
- first safe action;
- stop conditions.

At the end, persist only the stable result, evidence IDs, residual risks, and
one next action. Never persist chain-of-thought or raw private content.

## Context integrity checks

- If state, handoff, context, gap file, or manifest disagree, stop and repair
  the projections before product work.
- If an old historical entry says “complete” but direct evidence is missing,
  retain the history and keep the current gap open.
- If a model/tool result contradicts a typed postcondition, treat the result as
  unverified and fail closed.
