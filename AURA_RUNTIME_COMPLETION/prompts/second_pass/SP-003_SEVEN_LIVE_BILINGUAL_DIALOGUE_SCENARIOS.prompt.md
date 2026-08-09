---
id: SP-003
sequence: 3
track: R2
gap_ids: OPEN-03
depends_on: SP-002
next_prompt: SP-004
state: pending
---

# SP-003 — Seven Live Bilingual Dialogue Scenarios

## Mission

Close the R2 language/dialogue gate with seven reproducible Turkish, English, mixed, clarification, degradation, and provenance scenarios.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R2 prompt`
- `bilingual corpus/tests`
- `DialogueEngine`
- `IntentEngine`
- `Ollama evidence`
- `context/provenance contracts`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-03

## Hard boundaries

- Work only on OPEN-03; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Run the seven scenarios from the R2 prompt on the authorized target and record language, intent, slots, model/backend, latency, and outcome.
2. Include general questions, mixed technical command, paraphrased command, ambiguity clarification, model unavailable degradation, and provenance inspection.
3. Verify no raw model result reaches execution and no secret/private content enters prompt, event, log, or speech.
4. Compare results against the accepted model-variance risk and decide whether it remains bounded before beta.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-004 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-003`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

All seven scenarios meet their typed safety and truthful-degradation criteria with direct evidence; unresolved model or hardware behavior keeps R2 open.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-003 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-004.
