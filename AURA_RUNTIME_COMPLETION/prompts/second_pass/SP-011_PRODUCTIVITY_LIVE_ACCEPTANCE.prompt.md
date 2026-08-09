---
id: SP-011
sequence: 11
track: R5
gap_ids: OPEN-06
depends_on: SP-010
next_prompt: SP-012
state: pending
---

# SP-011 — Productivity Live Acceptance

## Mission

Run the authorized R5 live acceptance matrix and keep all externally consequential actions separately gated.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R5 prompt`
- `test-account procedure`
- `provider transport`
- `injection and post-action verification tests`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-06

## Hard boundaries

- Work only on OPEN-06; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Run unread mail/thread summary, draft-only mail, agenda/free-window, event draft, approved page summary, and injection-ignore scenarios.
2. If separately authorized, run one benign send/mutation only after reviewed immutable confirmation and exact post-action verification.
3. Revoke provider access and prove immediate disablement; test account ambiguity and offline behavior.
4. Record no real private-account data, tokens, message bodies, or screenshots in ledgers.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-012 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-011`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Read-first live matrix and revocation pass; mutation/send is either separately evidenced or explicitly excluded.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-011 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-012.
