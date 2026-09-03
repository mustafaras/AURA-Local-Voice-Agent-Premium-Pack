---
id: SP-002
sequence: 2
track: R2
gap_ids: OPEN-03
depends_on: SP-001
next_prompt: SP-003
state: pending
---

# SP-002 — Microphone and TCC Push-to-Talk

## Mission

Resolve the real microphone/Speech Recognition gate without changing the privacy or permission model.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R2 prompt`
- `R2 microphone risk/evidence`
- `PermissionCoordinator`
- `AuraAppModel.pushToTalk`
- `STT pipeline`
- `Info.plist`
- `user-present hardware procedure`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-03

## Hard boundaries

- Work only on OPEN-03; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Launch the authorized development build through the documented identity-preserving path.
2. Press Push to Talk and observe permission prompt, capture start, transcript, and visible failure states on clean and previously denied TCC profiles.
3. If denied, record the exact System Settings recovery path; never mutate TCC silently.
4. Record whether the candidate fix actually produces speech frames and a transcript, not merely a permission-state change.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-003 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-002`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

User-present evidence proves a real Turkish/English speech turn reaches STT or records a reproducible, correctly handled blocker with no false success.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-002 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-003.
