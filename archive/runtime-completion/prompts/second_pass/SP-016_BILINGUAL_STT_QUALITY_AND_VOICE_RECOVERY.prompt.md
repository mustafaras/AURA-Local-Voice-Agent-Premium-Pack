---
id: SP-016
sequence: 16
track: R7
gap_ids: OPEN-08
depends_on: SP-015
next_prompt: SP-017
state: pending
---

# SP-016 — Bilingual STT Quality and Voice Recovery

## Mission

Close live STT quality, microphone, barge-in, echo, device, sleep, and permission-recovery gaps.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R7 prompt`
- `STTRouter`
- `audio capture`
- `TCC procedure`
- `STT tests`
- `target hardware recovery matrix`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-08

## Hard boundaries

- Work only on OPEN-08; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Run a consented Turkish/English/mixed technical/noisy/far-field corpus and record WER/entity/turn-end metrics.
2. Exercise barge-in, assistant self-trigger protection, headset/device switching, sleep/wake, interruption, cancellation, TCC revocation, and helper crash recovery.
3. Verify incomplete-turn continuation and duplicate-result suppression on live streams.
4. Keep locale fallback fail closed; never rewrite a bad transcript into a successful command.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-017 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-016`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Defined bilingual quality and recovery thresholds pass on target hardware or the affected capability is excluded.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-016 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-017.
