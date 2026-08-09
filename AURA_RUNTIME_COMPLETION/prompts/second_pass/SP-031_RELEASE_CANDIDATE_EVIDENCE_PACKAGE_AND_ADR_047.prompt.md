---
id: SP-031
sequence: 31
track: R12
gap_ids: OPEN-13
depends_on: SP-030
next_prompt: SP-032
state: pending
---

# SP-031 — Release-Candidate Evidence Package and ADR-047

## Mission

Assemble and approve one provenance-bound RC package without inventing a release decision.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R12 prompt`
- `artifact hashes/SBOM/manifests`
- `CI/coverage/adversarial logs`
- `beta report`
- `sign-offs`
- `ADR-047 decision record`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-13

## Hard boundaries

- Work only on OPEN-13; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Bind exact commit/tag, signed/notarized hashes, SBOM/dependency/model manifests, CI/test/coverage/adversarial results, and clean-machine evidence.
2. Attach SLO report, beta incident/fix summary, open/accepted risks, capability exclusions, privacy/security/accessibility sign-offs, notes, and rollback/kill-switch plan.
3. Draft and obtain authorized ADR-047 decision on beta evidence, SLOs, RC authority, and completion declaration.
4. Only an authorized owner may approve `release_candidate_verified`; otherwise remain blocked.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-032 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-031`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

RC package is complete, reproducible, recoverable, independently reviewed, and explicitly approved.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-031 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-032.
