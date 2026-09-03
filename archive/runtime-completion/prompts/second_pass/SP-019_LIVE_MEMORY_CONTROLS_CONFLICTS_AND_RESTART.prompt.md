---
id: SP-019
sequence: 19
track: R8
gap_ids: OPEN-09
depends_on: SP-018
next_prompt: SP-020
state: pending
---

# SP-019 — Live Memory Controls, Conflicts, and Restart

## Mission

Demonstrate that memory is useful, bounded, inspectable, correctable, deletable, exportable, and restart safe.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R8 prompt`
- `R9 memory UI`
- `MemoryEngine`
- `preference store`
- `conflict/supersession/delete/export tests`
- `user-present app`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-09

## Hard boundaries

- Work only on OPEN-09; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Remember an explicit preference across a launched-app restart and prove scope/purpose metadata.
2. Derive a project fact from verified tool evidence, resolve a multi-turn reference, surface a contradiction, and apply a user correction.
3. Demonstrate inspection, correction, deletion, export, retention, and audit-memory exclusion.
4. Verify memory cannot authorize a risky action and record privacy-safe evidence only.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-020 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-019`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

All eight R8 live/product scenarios pass with user-visible controls and no hidden authority transfer.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-019 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-020.
