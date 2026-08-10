---
id: H-006
sequence: 6
gap_id: HYGIENE-06
depends_on: H-005
next_prompt: H-007
state: completed
---

# H-006 — Unsafe constructs and debug output

**Gap:** HYGIENE-06
**Dependency:** H-005
**Next:** H-007

## Mission

Audit high-risk Swift constructs and diagnostics, resolving defects with tests or explicit bounded decisions.

## Non-goals and hard boundary

Do not replace every unsafe construct mechanically or change security/concurrency architecture without an ADR and focused tests.
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
- Production Swift `try!`, `as!`, `@unchecked Sendable`, `Task.detached`, `print()`, logging utilities, tests, and relevant ADRs.

## Bounded procedure

1. Generate a production-only inventory and classify each occurrence by invariant, failure behavior, isolation proof, user-data exposure, and test coverage.
2. For each finding choose one disposition: safe replacement, wrapper with invariant test, ADR-backed exception, or explicit deferred risk.
3. For debug output, verify release behavior, privacy redaction, log level, and diagnostic usefulness; remove gated `print()` where structured logging is required.
4. Run focused tests and a source build for every changed cluster. Do not claim concurrency safety from syntax alone.
5. Append a finding-by-finding table with symptom, mechanism, root cause, resolution, falsification test, confidence, and residual risk.

## Acceptance checks

Every production finding has a tested resolution or an explicit owner/ADR/deferred risk; no secret or ambient audio/screen data enters diagnostics.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-007 safe now?

**Residual-risk reminder:** `@unchecked Sendable` may encode a valid external invariant; the risk is unresolved if the invariant is not tested.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-006-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
