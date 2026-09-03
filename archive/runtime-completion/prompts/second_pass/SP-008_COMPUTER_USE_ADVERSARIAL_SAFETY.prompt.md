---
id: SP-008
sequence: 8
track: R4
gap_ids: OPEN-05
depends_on: SP-007
next_prompt: SP-009
state: pending
---

# SP-008 — Computer-Use Adversarial Safety

## Mission

Close the R4 adversarial and recovery residuals without expanding computer-use scope.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R4 prompt`
- `prompt-injection tests`
- `emergency-stop executor`
- `secure-field/modal/no-progress tests`
- `live evidence bundle`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-05

## Hard boundaries

- Work only on OPEN-05; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Run screen-content injection, secure-field refusal, modal mismatch, wrong identity, no-progress, cancellation, and restart cases.
2. Trigger emergency stop at observation, confirmation, execution, and executor stages and verify prompt termination.
3. Confirm no raw model output becomes an action and no hidden window/permission bypass occurs.
4. Review redacted evidence and update the beta allowlist only for directly validated apps.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-009 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-008`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

All adversarial cases fail closed and emergency stop is proven across boundaries; unresolved cases block R4 and R9.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-008 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-009.
