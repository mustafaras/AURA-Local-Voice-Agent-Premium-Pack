---
id: H-000
sequence: 0
gap_id: HYGIENE-00
depends_on: none
next_prompt: H-001
state: ready
---

# H-000 — Baseline freeze and evidence capture

**Gap:** HYGIENE-00
**Dependency:** none
**Next:** H-001

## Mission

Create a fresh, tamper-evident baseline and classify every relevant dirty or untracked path before any hygiene mutation.

## Non-goals and hard boundary

Do not edit product code, delete files, alter Git objects, install tools, or change permissions.
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
- `git status`, `git ls-files`, `git check-ignore`, `git fsck`, `git count-objects`, `README.md`, `ledger/CURRENT_STATE.md`, `ledger/PROJECT_LEDGER.md`, `AGENTS.md`.

## Bounded procedure

1. Read the Tier-0 context and confirm the authority in `REPO_HYGIENE_STATE.json` is still edit-only.
2. Record branch, HEAD, remote relation, porcelain status, tracked/untracked/ignored inventories, file sizes, tool versions, and the selected OS/toolchain.
3. Run read-only integrity checks, including `git fsck --full --strict --no-reflogs`; capture exit status and output path without attempting recovery.
4. Classify each dirty/untracked group as user-owned, generated, historical control-plane work, unknown, or safe-to-review. Unknown ownership is a blocker.
5. Append `EV-REPO-HYGIENE-H000-<date>-01` to the focused ledger and keep H-000 active until the snapshot is reproducible.

## Acceptance checks

A second operator can reproduce the baseline from recorded commands and hashes; no unclassified path or authority ambiguity remains.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-001 safe now?

**Residual-risk reminder:** A stale snapshot can cause destructive cleanup; this prompt does not repair Git and therefore leaves the fsck finding open.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-000-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
