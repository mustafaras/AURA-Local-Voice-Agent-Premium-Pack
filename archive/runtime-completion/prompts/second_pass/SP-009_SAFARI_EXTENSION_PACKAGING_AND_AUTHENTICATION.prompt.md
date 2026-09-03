---
id: SP-009
sequence: 9
track: R5
gap_ids: OPEN-06
depends_on: SP-008
next_prompt: SP-010
state: pending
---

# SP-009 — Safari Extension Packaging and Authentication

## Mission

Turn the structured Safari bridge contract into a packaged, authenticated, user-controlled read path.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R5 prompt`
- `ADR-040`
- `PRODUCTIVITY_READ_FIRST`
- `Safari bridge sources/tests`
- `extension/native-messaging packaging docs`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-06

## Hard boundaries

- Work only on OPEN-06; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Define extension identity, native messaging transport, versioning, nonce/freshness, account/profile scope, and secret provisioning.
2. Package a minimal read-only extension and connect it through the composition root without enabling mutation.
3. Test disconnect, stale page, identity mismatch, injection content, revocation, and unavailable extension states.
4. Keep the capability disabled until the live package and trust path are verified.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-010 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-009`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

A real packaged bridge is authenticated, bounded, revocable, and visibly degraded when unavailable.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-009 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-010.
