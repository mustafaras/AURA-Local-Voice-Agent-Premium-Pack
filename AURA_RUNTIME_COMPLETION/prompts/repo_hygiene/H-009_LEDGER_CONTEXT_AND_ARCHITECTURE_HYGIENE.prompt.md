---
id: H-009
sequence: 9
gap_id: HYGIENE-09
depends_on: H-008
next_prompt: H-010
state: pending
---

# H-009 — Ledger context and architecture hygiene

**Gap:** HYGIENE-09
**Dependency:** H-008
**Next:** H-010

## Mission

Reduce context bloat and synchronization drift while preserving append-only history and the repository's architectural boundaries.

## Non-goals and hard boundary

Do not delete ledger history, collapse evidence into untraceable summaries, or silently change product architecture.
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
- `ledger/PROJECT_LEDGER.md`, `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md`, `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `ACTIVE_CONTEXT.md`, `AGENTS.md`, and architecture ADRs.

## Bounded procedure

1. Measure ledger/context sizes, duplicate sections, stale projections, and contradictory active claims; identify authoritative source for each fact class.
2. Create bounded successor summaries/pointers only where useful, retaining exact evidence IDs and historical links.
3. Verify Tier-0/Tier-1 read order, active prompt selection, state/manifest/ledger cross-checks, and session handoff limits.
4. Perform an architecture audit across package targets, dependency direction, security boundaries, and the 12-layer reasoning model: symptom, mechanism, layer, root cause, evidence, confidence, severity, owner, fix, falsification, residual risk, next gate.
5. Run all context/control validators and inspect the diff for accidental history rewrite or scope expansion.

## Acceptance checks

A fresh session can recover current truth with bounded reads; history is intact; every architectural finding has evidence and owner.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-010 safe now?

**Residual-risk reminder:** Summaries can become a second source of truth; all summaries must point back to authoritative ledgers and be validator-checked.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-009-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
