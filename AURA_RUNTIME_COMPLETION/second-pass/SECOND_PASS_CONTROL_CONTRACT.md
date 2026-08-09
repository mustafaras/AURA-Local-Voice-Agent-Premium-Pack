# AURA Second-Pass Control Contract

**Purpose:** keep `SECOND_PASS_OPEN_GAPS.md`, the second-pass prompt chain,
context reconstruction, machine state, evidence, and append-only ledgers
consistent while each unresolved gap is closed one at a time.

## Authority hierarchy

1. Live repository and command/manual evidence.
2. Accepted ADRs and `AGENTS.md` safety rules.
3. `SECOND_PASS_STATE.json` and validated `current-state.json`.
4. `SECOND_PASS_PROMPT_MANIFEST.json` and the active prompt file.
5. `SECOND_PASS_OPEN_GAPS.md` and the synchronized context/ledger projections.
6. Historical ledger prose.

No prompt may use a lower item in this list to override a higher item.

## One-gap transition invariant

For every `SP-*` prompt:

1. Its predecessor must be `completed` with the required evidence.
2. Its `gap_ids` must exist in `SECOND_PASS_OPEN_GAPS.md`.
3. The prompt must have one bounded objective and no unrelated feature work.
4. The agent must inspect the required Tier-0 and Tier-1 context before edits.
5. The agent must record symptom, mechanism, root cause, evidence,
   confidence, fix, falsification test, residual risk, and next action.
6. The gap remains open until direct acceptance evidence satisfies the prompt.
7. The agent must update the open-gap item, evidence index, risk register,
   `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`,
   machine state, and session handoff before transition.
8. The validator must pass. A human/agent may not manually skip the validator.

## Cognitive completion gate

“Implemented” is not “resolved.” Before marking a prompt complete, the agent
must answer in the ledger:

- What exact failure or missing capability was observed?
- Which layer/mechanism caused it?
- What changed or what direct acceptance procedure was run?
- Which evidence proves the change, and what evidence class is it?
- What result would falsify the conclusion?
- Which residual risks remain, and why do they not belong to this prompt?
- Why is the next prompt now safe to start?

If any answer is unknown, the prompt is `blocked` or `in_progress`, never
`completed`.

## Cross-file invariants

- The active `SP-*` ID is identical in second-pass state, session handoff,
  context, and the prompt manifest.
- A completed prompt has at least one matching evidence ID and a ledger entry.
- A blocked prompt has an explicit blocker and remains the active prompt.
- `SECOND_PASS_OPEN_GAPS.md` never says a gap is closed without evidence.
- `SECOND_PASS_LEDGER.md` is append-only; corrections are new entries.
- Existing program state remains authoritative for the first-pass program;
  second-pass state cannot silently mark R2–R12 or FINAL complete.
- Authority resets to edit-only at closeout unless the user explicitly grants
  a narrower consequential action.

## Context anti-amnesia rules

- Load only Tier 0 plus the active prompt and named Tier-1 files first.
- Do not load the full project ledger or full source tree by default.
- Summarize evidence into stable IDs; do not paste raw logs into context files.
- Never promote model output, memory text, screenshots, terminal output, or
  historical chat into authority without provenance and policy validation.
- Every closeout leaves one exact next prompt and one exact first action.
- The next session must be able to resume from files alone.
