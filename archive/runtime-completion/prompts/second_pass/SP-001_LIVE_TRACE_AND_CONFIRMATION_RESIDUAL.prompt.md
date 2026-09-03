---
id: SP-001
sequence: 1
track: R1
gap_ids: OPEN-02
depends_on: SP-000
next_prompt: SP-002
state: pending
---

# SP-001 — Live Trace and Confirmation Residual

## Mission

Close only the R1 prompt-level live residual: one user-present safe observation and one reversible mutation with truthful trace, confirmation, execution, and verification.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R1 prompt`
- `ADR-035`
- `ADR-037`
- `R1 evidence rows`
- `TurnContext`
- `RuntimeHealthRegistry`
- `ConfirmationTransactionStore`
- `direct trace/confirmation tests`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-02

## Hard boundaries

- Work only on OPEN-02; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. With explicit user-present authority, run the authorized observation and reversible mutation on the target Mac.
2. Capture correlation/causation, runtime health, displayed confirmation, execution result, verification result, and truthful response.
3. Exercise deny, timeout, dismissal, replay, changed-plan, cancellation, and restart behavior; do not execute a denied action.
4. Compare the live trace to the typed contracts and document any remaining universal-postcondition limitation.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-002 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-001`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

A direct live evidence bundle proves the required trace and fail-closed confirmation cases; otherwise keep R1 residual open.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-001 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-002.
