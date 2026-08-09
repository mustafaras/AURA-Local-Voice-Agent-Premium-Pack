---
id: H-002
sequence: 2
gap_id: HYGIENE-02
depends_on: H-001
next_prompt: H-003
state: pending
---

# H-002 — Dirty worktree and artifact quarantine

**Gap:** HYGIENE-02
**Dependency:** H-001
**Next:** H-003

## Mission

Produce a recoverable ownership and disposition map for dirty files, generated artifacts, caches, and control-plane additions.

## Non-goals and hard boundary

Do not discard user changes, remove ignored files broadly, or normalize the worktree by assumption.
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
- H-000/H-001 evidence, `git status --short --untracked-files=all`, `.build`, `Runtime/chatterbox/.venv`, `.venv`, `__pycache__`, `.DS_Store`, and all untracked program files.

## Bounded procedure

1. Group paths by tracked modification, untracked source/control file, generated artifact, cache, environment, OS metadata, or unknown.
2. For each group record owner, provenance, size, whether it is reproducible, preservation method, proposed disposition, and rollback path.
3. If quarantine is authorized, use an explicit recoverable destination outside the repository and write a manifest before moving anything. Otherwise perform inventory only.
4. Verify that no path in the prior second-pass/product work is classified as disposable merely because it is untracked.
5. Append the evidence and leave unresolved ownership as a blocker.

## Acceptance checks

Every relevant path has a disposition and recovery reference; generated artifacts are separated conceptually or through an authorized recoverable quarantine.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-003 safe now?

**Residual-risk reminder:** A generated-looking file may be a user-authored control artifact; never infer deletion from ignore status.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-002-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
