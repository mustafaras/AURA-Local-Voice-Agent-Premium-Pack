---
id: SP-014
sequence: 14
track: R6
gap_ids: OPEN-07
depends_on: SP-013
next_prompt: SP-015
state: pending
---

# SP-014 — Coding Assistant Live Acceptance

## Mission

Run the ten-step R6 user-present acceptance on an approved repository.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R6 prompt`
- `approved test repository`
- `extension bridge`
- `task/backend evidence`
- `delivery authority boundary`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-07

## Hard boundaries

- Work only on OPEN-07; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Identify workspace/file, read diagnostics, run tests, execute a harmless typed terminal command, and start a read-only task.
2. Run one confirmed write task in an isolated worktree; show progress, diff, tests, evidence, cancellation, and cleanup.
3. Disable/uninstall a backend and verify accurate health; restart/resume or fail closed.
4. Prove no commit, push, merge, PR, release, or deploy occurs without separate authority.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-015 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-014`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

All live coding scenarios pass with direct evidence and no unauthorized repository delivery.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-014 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-015.
