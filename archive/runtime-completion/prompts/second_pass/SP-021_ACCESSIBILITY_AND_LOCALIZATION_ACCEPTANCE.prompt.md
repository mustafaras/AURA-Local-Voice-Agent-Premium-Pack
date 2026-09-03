---
id: SP-021
sequence: 21
track: R9
gap_ids: OPEN-10
depends_on: SP-020
next_prompt: SP-022
state: pending
---

# SP-021 — Accessibility and Localization Acceptance

## Mission

Close manual VoiceOver, keyboard, focus, contrast, scaling, reduced-motion, Turkish, and English acceptance.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R9 prompt`
- `AuraMenuView`
- `ProductUIState`
- `localization keys`
- `accessibility tests`
- `clean/configured macOS profiles`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-10

## Hard boundaries

- Work only on OPEN-10; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Run a structured clean/configured profile pass with VoiceOver reading order, keyboard-only focus, confirmation containment/expiry, non-color status, Dynamic Type/scaled reflow, and reduced motion.
2. Exercise Turkish/English copy, dates, errors, degraded guidance, and no-terminal usability.
3. Record accessibility tree/labels and user-present findings without claiming automated tests as manual proof.
4. Fix every critical failure or keep R9 blocked.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-022 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-021`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Manual evidence proves primary workflows are operable and understandable in both locales.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-021 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-022.
