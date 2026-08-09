---
id: SP-030
sequence: 30
track: R12
gap_ids: OPEN-13
depends_on: SP-029
next_prompt: SP-031
state: pending
---

# SP-030 — Beta SLOs, Scenarios, Incidents, and Sign-Offs

## Mission

Run the controlled beta evidence program and close reliability, safety, accessibility, privacy, security, and false-success gates.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R12 prompt`
- `beta readiness record`
- `performance budgets`
- `acceptance scenarios`
- `incident response`
- `independent review checklist`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-13

## Hard boundaries

- Work only on OPEN-13; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Collect the approved sample and compute defined percentile SLOs for latency, STT/WER, task completion, verification, crash/recovery, accessibility, privacy, and unauthorized actions.
2. Run Turkish/English/mixed scenario matrix, false-success/unauthorized-action cases, update/recovery/uninstall, and incident review.
3. For every incident, preserve redacted evidence, root cause, remediation, regression, and closure owner.
4. Obtain independent security/privacy/accessibility/localization/release sign-offs and keep critical risks open until accepted by authorized ownership.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-031 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-030`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Mandatory SLOs and scenarios pass, incidents are remediated, and independent sign-offs are complete.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-030 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-031.
