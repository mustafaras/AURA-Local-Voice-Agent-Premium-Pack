---
id: SP-006
sequence: 6
track: R3
gap_ids: OPEN-04
depends_on: SP-005
next_prompt: SP-007
state: pending
---

# SP-006 — R3 Live Capability Scenarios

## Mission

Run the R3 seven-scenario demonstration and prove registry, planner, policy, verification, and unavailable-capability behavior end to end.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R3 prompt`
- `capability manifest/health UI`
- `live trace contract`
- `authorized target hardware`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-04

## Hard boundaries

- Work only on OPEN-04; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Demonstrate observation, reversible app/file/URL action, confirmed mutation, two-step safe plan, unavailable capability, malformed model plan rejection, and capability-health inspection.
2. Capture plan fingerprint, policy decision, confirmation, adapter result, verification, and UI evidence for each scenario.
3. Test cancellation, partial failure, rollback/compensation declaration, and no unauthorized delivery action.
4. Do not mark R3 complete if any capability is only direct-call reachable or only simulated.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-007 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-006`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

The seven direct/live scenarios pass with typed evidence and no registry bypass; otherwise keep R3 open.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-006 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-007.
