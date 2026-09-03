---
id: SP-028
sequence: 28
track: R11
gap_ids: OPEN-12
depends_on: SP-027
next_prompt: SP-029
state: pending
---

# SP-028 — Updater, Lifecycle, Recovery, and Migration

## Mission

Close operational lifecycle behavior: launch at login, update, rollback, recovery, migration, uninstall, and private diagnostics.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R11 prompt`
- `ADR-046`
- `UPDATE_MECHANISM`
- `ServiceManagement/login-item sources`
- `migration/state schemas`
- `support-bundle paths`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-12

## Hard boundaries

- Work only on OPEN-12; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Implement and test user-controlled launch-at-login with enable/disable and sleep/wake/crash recovery.
2. Exercise signed manifest/package, atomic update, downgrade/replay protection, backup/migration, rollback, kill switch, low disk, corruption, and interrupted update.
3. Test configuration/database/memory/plugin/model migrations, support-bundle redaction, safe mode/reset, uninstall/reinstall, and factory reset semantics.
4. Accept ADR-046 only after direct operational evidence.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-029 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-028`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Lifecycle, updater, recovery, migration, support, uninstall, and rollback all pass on supported clean/configured profiles.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-028 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-029.
