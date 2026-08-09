---
id: SP-032
sequence: 32
track: FINAL
gap_ids: OPEN-14
depends_on: SP-031
next_prompt: SP-033
state: pending
---

# SP-032 — Final Acceptance and Cleanup

## Mission

Perform the final acceptance review only after every owning prompt has direct evidence.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `FINAL prompt`
- `RC package`
- `all current state/evidence/risk/decision records`
- `capability matrix`
- `clean-Mac evidence`
- `docs and support handoff`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-14

## Hard boundaries

- Work only on OPEN-14; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Reconcile every capability claim with evidence class and remove only stale/misleading scaffolding; never rewrite history.
2. Run clean end-to-end installation, launch, permission, conversation, task, update, rollback, recovery, uninstall, and support-bundle checks.
3. Review security/privacy/accessibility, documentation, known limitations, release/rollback authority, and operational maintenance dates.
4. Set release_candidate_verified or released only when the prompt gate and explicit authority genuinely pass.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-033 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-032`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Every mandatory gate is passed or explicitly scoped/accepted by authorized ownership; otherwise return to the owning SP prompt.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-032 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-033.
