---
id: SP-017
sequence: 17
track: R7
gap_ids: OPEN-08
depends_on: SP-016
next_prompt: SP-018
state: pending
---

# SP-017 — TTS, Resource Soak, and ADR-042

## Mission

Close voice output/resource governance or define a truthful system-TTS-only release.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R7 prompt`
- `VoiceResourceGovernor`
- `Chatterbox helper`
- `SystemTTSEngine`
- `model manifest`
- `performance budgets`
- `ADR-042`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-08

## Hard boundaries

- Work only on OPEN-08; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Measure first-audio/quality/CPU/memory/thermal/energy for system voice and consented neural voice.
2. Exercise helper timeout/crash, interruption, cache cleanup, CPU/MPS selection, memory pressure, thermal circuit, and long soak on 16 GB hardware.
3. Route NLU/reasoning/screen/coding workloads through the governor or document explicit exclusions.
4. Accept ADR-042 only with alternatives, scope, expiry, and evidence.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-018 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-017`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Resource/voice thresholds pass or neural/wake capabilities are explicitly excluded; PTT + system TTS remains truthful.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-017 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-018.
