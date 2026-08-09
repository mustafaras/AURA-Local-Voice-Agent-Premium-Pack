---
id: H-003
sequence: 3
gap_id: HYGIENE-03
depends_on: H-002
next_prompt: H-004
state: pending
---

# H-003 — Ignore rules and generated-file hygiene

**Gap:** HYGIENE-03
**Dependency:** H-002
**Next:** H-004

## Mission

Make generated-file boundaries explicit and regression-testable without hiding source, fixtures, manifests, or evidence.

## Non-goals and hard boundary

Do not add broad wildcard ignores to silence unknown files or remove tracked files without an explicit migration.
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
- `.gitignore`, `Runtime/chatterbox/.gitignore`, `git ls-files`, `git check-ignore`, build/cache directories, CI checkout behavior, and representative fixtures.

## Bounded procedure

1. Use the H-002 inventory to identify the minimum missing ignore rules and any over-broad rules that hide meaningful files.
2. Check whether any generated artifact is tracked; if so, design a reversible migration and preserve provenance before changing tracking.
3. Add or adjust rules only with comments where a future maintainer needs the reason. Test positive generated paths and negative intentional source/fixture paths.
4. Verify a clean checkout/fixture scenario and inspect `git status`, `git diff --check`, and the untracked inventory after the change.
5. Record the exact rule, rationale, false-positive risk, and rollback.

## Acceptance checks

Generated files are ignored by explicit tested rules, intentional fixtures remain visible, and no tracked artifact is silently lost.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-004 safe now?

**Residual-risk reminder:** Ignore rules can conceal a secret or source file; the next secret-scan prompt remains independent.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-003-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
