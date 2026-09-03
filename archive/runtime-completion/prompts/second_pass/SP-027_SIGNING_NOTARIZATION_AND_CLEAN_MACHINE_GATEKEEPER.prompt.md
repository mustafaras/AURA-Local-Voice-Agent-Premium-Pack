---
id: SP-027
sequence: 27
track: R11
gap_ids: OPEN-12
depends_on: SP-026
next_prompt: SP-028
state: pending
---

# SP-027 — Signing, Notarization, and Clean-Machine Gatekeeper

## Mission

Produce and validate an authorized release-class artifact.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R11 prompt`
- `signing/notarization scripts`
- `Developer ID authority`
- `official Apple docs`
- `clean supported Mac matrix`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-12

## Hard boundaries

- Work only on OPEN-12; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. With explicit credentials and release authority, sign nested bundles with Developer ID and hardened runtime.
2. Submit, staple, and verify notarization; run codesign, spctl, quarantine, nested helper, and TCC identity checks.
3. Install on a clean supported Mac with no developer tools and record launch/permission behavior.
4. Hash and provenance-bind every artifact; do not expose it as RC until all checks pass.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-028 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-027`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Clean-machine Gatekeeper and nested-signature/notarization evidence passes; otherwise R11 remains blocked.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-027 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-028.
