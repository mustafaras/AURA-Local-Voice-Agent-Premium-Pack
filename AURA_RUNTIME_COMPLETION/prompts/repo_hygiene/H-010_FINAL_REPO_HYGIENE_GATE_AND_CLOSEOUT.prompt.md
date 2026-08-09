---
id: H-010
sequence: 10
gap_id: HYGIENE-10
depends_on: H-009
next_prompt: none
state: pending
---

# H-010 — Final repository hygiene gate and closeout

**Gap:** HYGIENE-10
**Dependency:** H-009
**Next:** none

## Mission

Prove the hygiene program's acceptance criteria, preserve blockers honestly, and leave a synchronized next-session handoff.

## Non-goals and hard boundary

Do not commit, push, merge, release, deploy, sign, notarize, enroll beta users, or claim product completion.
Respect `AGENTS.md`, the control contract, and the current authority in `REPO_HYGIENE_STATE.json`. This is an edit-only control task unless a separately recorded authority says otherwise.

## Read before acting

- `AGENTS.md`
- `README.md`
- `ledger/CURRENT_STATE.md`
- `ledger/PROJECT_LEDGER.md` latest relevant slice
- `AURA_RUNTIME_COMPLETION/context/REPO_HYGIENE_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json`
- `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_MANIFEST.json`
- All hygiene control files, ledgers, state, active context, CI/configuration, test reports, Git integrity evidence, and existing `15_SESSION_CLOSEOUT.prompt.md`.

## Bounded procedure

1. Verify the strict linear state, prompt files, manifest, schemas, gap headings, required contracts, and all evidence references.
2. Run every available build, Python test, governance test, repo-hygiene validator, second-pass validator, shell/YAML/JSON/diff check, scan, and inventory check; mark unavailable tools blocked.
3. Review the complete diff and untracked inventory against the H-000 ownership baseline. Confirm no destructive action occurred without authority.
4. Answer every open risk and blocker with owner, evidence, falsification path, and next safe action. Do not convert unknown to passed.
5. Append final evidence, update the focused state and required cross-program projections, run `15_SESSION_CLOSEOUT.prompt.md`, and leave the program completed only if all criteria truly pass.

## Acceptance checks

All hygiene gates pass or are formally blocked with evidence; state, manifest, gap register, ledgers, context, and handoff agree; no release claim is made.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting null safe now?

**Residual-risk reminder:** A final gate can prove repository hygiene only; product second-pass and release/beta gates remain independent.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-010-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
