---
id: SP-012
sequence: 12
track: R6
gap_ids: OPEN-07
depends_on: SP-011
next_prompt: SP-013
state: pending
---

# SP-012 — Authenticated VS Code Extension Bridge

## Mission

Replace the local bridge contract with a real authenticated extension transport while preserving policy enforcement.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R6 prompt`
- `VSCodeAdapter/Bridge/Security`
- `ADR-041`
- `typed route tests`
- `extension packaging and secret provisioning`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-07

## Hard boundaries

- Work only on OPEN-07; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Package the extension and provision its shared secret or platform-authenticated equivalent through a user-controlled path.
2. Bind extension identity, protocol version, nonce, freshness, workspace, actor, and payload to every request.
3. Exercise disconnect, version mismatch, replay, stale editor, dirty buffer, and confirmation-required paths.
4. Keep every VS Code capability disabled until the live bridge health is proven.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-013 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-012`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

The extension is packaged, authenticated, revocable, and policy-enforced on the live path.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-012 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-013.
