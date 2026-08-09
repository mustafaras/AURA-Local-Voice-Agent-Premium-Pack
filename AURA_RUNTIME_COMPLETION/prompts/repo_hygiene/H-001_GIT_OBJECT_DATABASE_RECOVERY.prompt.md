---
id: H-001
sequence: 1
gap_id: HYGIENE-01
depends_on: H-000
next_prompt: H-002
state: pending
---

# H-001 — Git object database recovery

**Gap:** HYGIENE-01
**Dependency:** H-000
**Next:** H-002

## Mission

Determine whether the repository object database can be safely recovered while preserving all user-owned work.

## Non-goals and hard boundary

Do not run `git gc`, `git prune`, `git repack`, `git clean`, `git reset`, delete `.git/objects`, or rewrite history.
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
- H-000 evidence, `.git/objects`, `git fsck`, `git cat-file`, `git rev-list`, remote refs, and any separately approved backup/clone location.

## Bounded procedure

1. Re-read H-000 evidence and verify HEAD, remote, and dirty-file inventory have not drifted.
2. Re-run read-only object checks and distinguish malformed loose-object filenames from missing referenced objects, dangling objects, and unreachable but valid history.
3. Obtain or verify an independent clean clone or byte/integrity-checked backup through an explicitly authorized recovery path. Do not treat a local copy as independent without proving its provenance.
4. Compare refs, reachable object closure, and the dirty-work patch/untracked inventory. If a recovery mutation is not explicitly authorized, record a blocked decision and stop.
5. Only after an explicit recovery decision may a separate authorized session perform repair; this prompt itself must not mutate the object database.

## Acceptance checks

Either a clean authoritative clone/backup and preservation mapping are proven, or the gap is explicitly blocked with a named owner and safe recovery action.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-002 safe now?

**Residual-risk reminder:** Object deletion or repack can make user work unrecoverable; a non-zero fsck result remains open until independently repaired.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-001-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
