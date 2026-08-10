---
id: H-005
sequence: 5
gap_id: HYGIENE-05
depends_on: H-004
next_prompt: H-006
state: ready
---

# H-005 — Swift format lint and strict concurrency

**Gap:** HYGIENE-05
**Dependency:** H-004
**Next:** H-006

## Mission

Define reproducible Swift formatting, lint, warnings, and concurrency gates, then separate tool unavailability from code findings.

## Non-goals and hard boundary

Do not install tools or mass-reformat the repository without explicit authority and a bounded diff review.
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
- `Package.swift`, Swift sources/tests, `TOOLCHAIN.md`, existing CI, `.swift-format`, `.swiftlint.yml`, `swift-format`, `swiftlint`, and compiler flags.

## Bounded procedure

1. Check which formatter/linter/compiler capabilities are installed and record exact versions/help output.
2. If a tool is unavailable, define the intended pinned configuration and record the installation blocker instead of pretending it ran.
3. Inspect Package.swift and CI for strict-concurrency, warnings-as-errors, and formatter/lint policy; identify unsafe or inconsistent flags.
4. If authorized and tools are available, run them in report/check mode first, partition findings by source ownership, and apply only a reviewed bounded change.
5. Run the smallest relevant build/tests after any source/config change and record diagnostics.

## Acceptance checks

A maintainer can reproduce the formatting/lint/concurrency policy, or the unavailable capability is explicitly blocked with an owner and no false pass claim.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-006 safe now?

**Residual-risk reminder:** Blind formatting can create a massive unrelated diff; source semantics must remain the next audit's concern.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-005-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
