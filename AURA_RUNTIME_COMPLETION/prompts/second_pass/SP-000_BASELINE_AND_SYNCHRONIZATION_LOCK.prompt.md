---
id: SP-000
sequence: 0
track: BOOTSTRAP/R0
gap_ids: OPEN-00, OPEN-01
depends_on: none
next_prompt: SP-001
state: pending
---

# SP-000 — Baseline and Synchronization Lock

## Mission

Establish a truthful second-pass baseline and prove that every control file points to the same pending prompt. This prompt changes no product behavior.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `AGENTS.md`
- `SECOND_PASS_READ_FIRST.md`
- `SECOND_PASS_CONTROL_CONTRACT.md`
- `SECOND_PASS_STATE.json`
- `current-state.json`
- `session-handoff.json`
- `prompt manifest`
- `SECOND_PASS_OPEN_GAPS.md`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-00, OPEN-01

## Hard boundaries

- Work only on OPEN-00 and OPEN-01; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Verify branch, HEAD, origin relation, worktree, user-owned changes, toolchain, and authority.
2. Validate both first-pass and second-pass JSON/state/manifest files and confirm OPEN-00 through OPEN-15 plus SP-000 through SP-033 exist.
3. Reconcile any mismatch before continuing; do not infer authority from stale state or chat history.
4. Record the baseline and leave SP-001 pending only if every synchronization check passes.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-001 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-000`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

All control files agree on SP-000, no dependency or identifier mismatch exists, and the validator passes. Any mismatch keeps SP-000 blocked.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-000 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-001.
