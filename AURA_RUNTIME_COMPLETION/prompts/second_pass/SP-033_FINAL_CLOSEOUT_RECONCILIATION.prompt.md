---
id: SP-033
sequence: 33
track: SESSION_CLOSEOUT
gap_ids: OPEN-15
depends_on: SP-032
next_prompt: none
state: pending
---

# SP-033 — Final Closeout Reconciliation

## Mission

Close the second-pass chain with a machine-resumable, append-only handoff. This prompt never hides a blocked result.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `15_SESSION_CLOSEOUT prompt`
- `SECOND_PASS_CONTROL_CONTRACT`
- `SECOND_PASS_STATE`
- `session handoff`
- `both ledgers`
- `evidence/risk/decision registers`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-15

## Hard boundaries

- Work only on OPEN-15; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Record exact branch, HEAD, remote, worktree, files, commands, evidence, risks, authority, and the final prompt state.
2. Answer the cognitive completion questions for the entire chain and link each SP prompt's evidence/ledger entry.
3. Validate the manifest, state, prompt files, gap IDs, dependencies, evidence references, and all synchronized context projections.
4. If any mandatory gate is not proved, leave the program blocked and state the exact owning prompt and first next action.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is the chain safe to close?

## Required records

- Evidence ID prefix: `EV-SP-033`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

The chain is either truthfully completed with all direct evidence or truthfully blocked with a complete maintainer handoff; no ambiguous state remains.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-033 `in_progress` or `blocked`, record the exact blocker, and do not proceed to none.
