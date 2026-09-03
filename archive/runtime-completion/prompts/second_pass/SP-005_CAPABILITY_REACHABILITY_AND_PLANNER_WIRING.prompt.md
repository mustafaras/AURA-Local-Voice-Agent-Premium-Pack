---
id: SP-005
sequence: 5
track: R3
gap_ids: OPEN-04
depends_on: SP-004
next_prompt: SP-006
state: pending
---

# SP-005 — Capability Reachability and Planner Wiring

## Mission

Connect registered capabilities to natural-language and UI reachability and wire bounded multi-step plans into production routing.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R3 prompt`
- `DialogueEngine`
- `ToolRouter`
- `capability UI`
- `planner/registry tests`
- `R2 typed dialogue contracts`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-04

## Hard boundaries

- Work only on OPEN-04; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Map utterance/entity schemas and UI actions to the registry rather than adding switch statements.
2. Route model proposals through CapabilityPlanner, registry availability, policy, immutable fingerprint, confirmation, and typed adapter verification.
3. Add bounded multi-step/delegated/refusal handling with dependency, budget, cancellation, and replanning tests.
4. Keep disabled or ambiguous capabilities visibly unavailable and never fall back to arbitrary execution.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-006 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-005`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

A production natural-language request creates only registry-validated plans and every reachable capability has truthful health and UI/NLU state.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-005 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-006.
