---
id: H-007
sequence: 7
gap_id: HYGIENE-07
depends_on: H-006
next_prompt: H-008
state: completed
---

# H-007 — Test matrix CI and coverage hygiene

**Gap:** HYGIENE-07
**Dependency:** H-006
**Next:** H-008

## Mission

Make local and CI verification complete, truthful, and aligned with the actual Swift/Python/governance test surface.

## Non-goals and hard boundary

Do not claim a post-change CI run when none occurred, weaken coverage thresholds, or add a test merely to inflate counts.
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
- `scripts/aura-test.sh`, `.github/workflows/ci.yml`, `Package.swift`, `Runtime/chatterbox/tests`, `scripts/tests`, coverage configuration, and artifact retention.

## Bounded procedure

1. Enumerate all 21 Swift bundles, 4 Python runtime tests, governance validators, shell/YAML/JSON checks, and any second-pass/repo-hygiene validators.
2. Compare the enumeration to CI jobs and identify omitted, duplicated, flaky, or falsely green commands; distinguish local from hosted evidence.
3. Define coverage scope/threshold and ensure the CI command fails closed when coverage output is absent or malformed.
4. Review checkout/diff hygiene, artifact paths/retention, action pinning policy, and test-runner exit propagation.
5. Run the complete locally available matrix without altering user permissions or installing missing dependencies; record unavailable jobs separately.

## Acceptance checks

The matrix explains exactly what runs locally and in CI, all exits propagate, coverage is meaningful, and missing hosted evidence is explicit.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-008 safe now?

**Residual-risk reminder:** A green local runner may differ from the hosted macOS image; release claims remain outside this prompt.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-007-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
