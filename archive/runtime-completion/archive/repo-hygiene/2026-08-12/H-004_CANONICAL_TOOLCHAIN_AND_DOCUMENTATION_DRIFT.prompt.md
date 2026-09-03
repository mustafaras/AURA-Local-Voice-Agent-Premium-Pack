---
id: H-004
sequence: 4
gap_id: HYGIENE-04
depends_on: H-003
next_prompt: H-005
state: ready
---

# H-004 — Canonical toolchain and documentation drift

**Gap:** HYGIENE-04
**Dependency:** H-003
**Next:** H-005

## Mission

Reconcile active toolchain, test-count, path, and platform claims with repository authority and live commands.

## Non-goals and hard boundary

Do not rewrite historical ledger entries or claim full Xcode/release evidence when only Command Line Tools are available.
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
- `AGENTS.md`, `README.md`, `TOOLCHAIN.md`, `Package.swift`, `.github/instructions`, `.github/workflows/ci.yml`, `scripts/aura-test.sh`, and test-target enumeration.

## Bounded procedure

1. Determine the canonical active baseline from the normative contract and verify installed Swift/Xcode/CLT facts with commands.
2. Enumerate actual Swift test bundles and Python tests from source/configuration; identify every conflicting active claim.
3. Inventory hard-coded developer-directory/framework paths and replace them only with validated portable discovery or clearly documented fail-closed behavior.
4. Update active docs/scripts/CI with an evidence-linked baseline. Preserve historical counts as historical notes, not as current instructions.
5. Run source build, script syntax, YAML/JSON parsing, and documentation link/reference checks available without installing tools.

## Acceptance checks

Active instructions agree on macOS/Swift/toolchain/test counts, hard-coded paths are removed or bounded, and historical records remain intact.

## Cognitive completion gate

Answer all six questions in the focused ledger entry; do not use a green command as a substitute for reasoning:

1. What exact symptom or hygiene gap was observed?
2. What mechanism and root cause explain it?
3. What exact resolution, decision, or safe blocker is supported by evidence?
4. What falsification or regression test would disprove the conclusion?
5. What residual risk remains, who owns it, and why is it outside this prompt?
6. Why is starting H-005 safe now?

**Residual-risk reminder:** Changing test enumeration can alter CI scope; H-007 independently verifies the complete matrix.

## Required records

- Append an evidence-backed entry with prefix `EV-REPO-HYGIENE-H-004-` to `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.
- Update the matching gap, evidence, and risk projections without rewriting history.
- Synchronize `REPO_HYGIENE_STATE.json`; its active prompt must remain this prompt until the gate is actually complete.
- Run `python3 scripts/validate_repo_hygiene_program.py` and record its output.
- When repository state changes, update the required runtime/project ledgers and session handoff under `AGENTS.md`.

## Do not proceed

Do not proceed to the next prompt if evidence, ownership, authority, validator output, or the Cognitive completion gate is missing. A blocked result is a valid result; mark the prompt blocked and keep it active.

## SESSION_CLOSEOUT

After this attempt, run `AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md`. Record exact branch/commit, files, tests, evidence IDs, blockers, authority, and next action. Closeout is mandatory and does not by itself complete this prompt.
