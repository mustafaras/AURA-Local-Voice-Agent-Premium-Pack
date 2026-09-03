---
id: SP-015
sequence: 15
track: R7
gap_ids: OPEN-08
depends_on: SP-014
next_prompt: SP-016
state: pending
---

# SP-015 — Wake-Word Decision and Evaluation

## Mission

Make one evidence-backed decision: qualify a real local wake word or explicitly exclude it from the release scope.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R7 prompt`
- `DisabledWakeWordDetector`
- `wake model inventory`
- `privacy/license/hash policy`
- `wake tests`
- `ADR-042 draft`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-08

## Hard boundaries

- Work only on OPEN-08; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Define FAR/FRR, Turkish/noise/distance, self-trigger, debounce, energy, privacy, license, hash, and soak thresholds.
2. Evaluate a licensed local candidate on authorized hardware; distinguish synthetic fixtures from live human audio.
3. If no candidate passes, keep production PTT-only and update capability/UI/ADR scope explicitly.
4. Record the decision, expiry/review, and no-false-ready behavior.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-016 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-015`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Wake word is live-qualified with evidence or explicitly excluded with truthful UI and no wake-word claim.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-015 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-016.
