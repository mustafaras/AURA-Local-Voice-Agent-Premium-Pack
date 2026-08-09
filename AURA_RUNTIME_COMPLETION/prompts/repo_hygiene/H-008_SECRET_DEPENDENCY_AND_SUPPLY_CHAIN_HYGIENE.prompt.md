---
id: H-008
sequence: 8
gap_id: HYGIENE-08
depends_on: H-007
next_prompt: H-009
state: pending
---

# H-008 — Secret dependency and supply-chain hygiene

**Gap:** HYGIENE-08
**Dependency:** H-007
**Next:** H-009

## Mission

Add reproducible secret, dependency, and workflow provenance checks while protecting credentials and intentional fixtures.

## Non-goals and hard boundary

Do not print, rotate, revoke, upload, or commit secrets; do not install scanners without authority.
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
- Tracked files/history policy, test fixtures, `Package.swift`, `Runtime/chatterbox/pyproject.toml`, `uv.lock`, GitHub Actions, scanner configuration, and `.gitignore`.

## Bounded procedure

1. Run available narrow and high-confidence secret scans against tracked content; separately classify intentional sentinel fixtures from real credential material.
2. Define a scanner configuration with safe redaction, fixture allowlisting by exact file/line or test marker, and a fail-closed review path.
3. Audit Swift/Python/action dependencies for pins, provenance, lockfile consistency, unused packages, and unbounded remote references.
4. Verify that logs, prompts, ledgers, crash fixtures, and artifacts contain no secret values or raw ambient data.
5. If a scanner or dependency tool is missing, record the exact blocker and intended command; do not infer a clean result.

## Acceptance checks

Secret and dependency policy is reproducible, fixtures are safe and explicit, lockfiles/provenance are reviewed, and no secret value is exposed.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-009 safe now?

**Residual-risk reminder:** History scanning may remain unavailable; absence of a current-tree finding is not proof that old secrets never existed.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-008-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
