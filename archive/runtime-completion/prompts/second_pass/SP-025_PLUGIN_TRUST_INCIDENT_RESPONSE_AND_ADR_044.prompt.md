---
id: SP-025
sequence: 25
track: R10
gap_ids: OPEN-11
depends_on: SP-024
next_prompt: SP-026
state: pending
---

# SP-025 — Plugin Trust, Incident Response, and ADR-044

## Mission

Close supply-chain and operational security gaps and obtain independent review.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R10 prompt`
- `PluginVerifier/Registry/Marketplace`
- `SBOM/checksum docs`
- `incident response`
- `independent review plan`
- `ADR-044`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-11

## Hard boundaries

- Work only on OPEN-11; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Enforce vendor roots, signatures, hashes, revocation, quarantine, SBOM, rollback, update, and unverified-code rejection with compromised fixtures.
2. Complete incident containment, grant revocation, vulnerability reporting, evidence preservation, and review schedule.
3. Obtain an independent architecture/security review covering IPC, policy, OAuth, network, computer use, updater, and plugins.
4. Accept ADR-044 only with critical findings resolved or explicitly authorized with scope and expiry.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-026 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-025`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Supply-chain, incident, and independent-review evidence exists; no critical unaccepted security risk remains.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-025 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-026.
