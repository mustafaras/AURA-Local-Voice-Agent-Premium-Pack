# Repository Hygiene Prompt Contract

Every `H-*.prompt.md` is an execution unit, not a suggestion. Run exactly one
prompt at a time, in manifest order.

## Required prompt structure

Each prompt must contain front matter with `id`, `sequence`, `gap_id`,
`depends_on`, `next_prompt`, and `state`; mission; non-goals; Tier-0/Tier-1
reads; bounded procedure; acceptance checks; a **Cognitive completion gate**;
**Required records**; and a **SESSION_CLOSEOUT** section.

## Cognitive completion gate

Before marking a prompt complete, answer all six questions in the prompt:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact change, decision, or safe blocker resolves it?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this scope?
6. Why is the next prompt safe to start now?

“The command passed” is not an answer to these questions.

## Required records

The operator must append an evidence-backed record to
`AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`, update the
relevant gap/evidence/risk projection, and synchronize
`REPO_HYGIENE_STATE.json`, `AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md`,
`AURA_RUNTIME_COMPLETION/state/RISK_REGISTER.md`,
`AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md`,
`ledger/PROJECT_LEDGER.md`, `ledger/CURRENT_STATE.md`, and the session handoff
when the prompt changes repository state. Run
`python3 scripts/validate_repo_hygiene_program.py`.

## Do not proceed rule

Do not proceed to the next prompt when evidence is missing, ownership is
unclear, a required tool is unavailable without a recorded blocker, a
destructive action lacks authority, or the cognitive gate is incomplete.

## SESSION_CLOSEOUT

After every attempt, run the existing
`AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md` procedure. It
must record exact branch/commit, files, tests, evidence, blockers, authority,
and next action. A closeout does not turn a blocked prompt into a completed
prompt.
