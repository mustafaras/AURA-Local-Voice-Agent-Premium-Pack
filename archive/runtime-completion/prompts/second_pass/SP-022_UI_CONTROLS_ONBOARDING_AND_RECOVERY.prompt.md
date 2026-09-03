---
id: SP-022
sequence: 22
track: R9
gap_ids: OPEN-10
depends_on: SP-021
next_prompt: SP-023
state: pending
---

# SP-022 — UI Controls, Onboarding, and Recovery

## Mission

Close remaining product-control coverage and staged onboarding/recovery behavior.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R9 prompt`
- `AuraAppModel`
- `AuraMenuView`
- `ProductUIState`
- `permission/model/task/memory/recovery paths`
- `support-bundle contract`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-10

## Hard boundaries

- Work only on OPEN-10; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Expose truthful task scope/diff/test/evidence/pause/resume/retry and capability grant/expiry/revoke/disable controls.
2. Exercise no-model, offline, provider-disabled, permission denied/revoked, onboarding restart, emergency stop, memory deletion/export, support bundle privacy, and safe reset guidance.
3. Keep model download/remove, launch-at-login, integrations, and recovery steps behind their owning gates.
4. Verify every unavailable capability has a disabled reason and no fake success.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-023 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-022`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

R9 users can understand and control primary workflows without terminal intervention, with actionable degraded states.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-022 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-023.
