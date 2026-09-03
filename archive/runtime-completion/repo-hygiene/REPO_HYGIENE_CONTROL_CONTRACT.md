# Repository Hygiene Control Contract

This contract governs the sequential hygiene prompts. It is subordinate to
`AGENTS.md`, the current runtime-completion state, and explicit user authority.

## Authority and recovery

The preparation phase has edit authority for these control files only. It does
not authorize cleanup, deletion, Git recovery mutation, dependency/model
installation, permission changes, app launch/install, release, deployment, or
Git delivery. A prompt must stop when its action would cross that boundary.

Git object recovery is fail-closed. A non-zero `git fsck` result is evidence of
a recovery gate, not permission to run `gc`, `prune`, `repack`, delete object
files, or reset the branch. Recovery requires an independently verified backup
or clean clone, an inventory of dirty user-owned work, and explicit authority
for the chosen repair.

## Synchronization invariants

The following projections describe one program and must agree:

1. `docs/operations/REPO_HYGIENE_PROGRAM.md` — human gap truth and roadmap.
2. `REPO_HYGIENE_PROMPT_MANIFEST.json` — exact order and dependencies.
3. `REPO_HYGIENE_STATE.json` — active/completed/blocked state.
4. `REPO_HYGIENE_PROMPT_CONTRACT.md` and every prompt file — execution rules.
5. `REPO_HYGIENE_LEDGER.md` — append-only focused evidence history.
6. `AURA_RUNTIME_COMPLETION/context/REPO_HYGIENE_READ_FIRST.md` — bounded read order.
7. Repository ledgers, risk register, evidence index, and session handoff — cross-program projections.

The validator must pass after every attempt. If any projection disagrees, keep
the current prompt `in_progress` or `blocked`; do not infer completion.

## State transition rule

Only the first not-completed prompt may be active. A prompt may move to
`completed` only after its cognitive completion gate, evidence record, required
ledger updates, and validator pass are all present. A blocked prompt remains
active. The next prompt is not eligible until the current prompt and the
mandatory `15_SESSION_CLOSEOUT.prompt.md` procedure are complete.

## Evidence quality

Each evidence record must include timestamp, session ID, exact commit/branch,
commands or manual procedure, tool/OS versions, objective result and exit
status, artifact/log path, supported gate, and limitations. A conclusion must
identify symptom, mechanism, root cause, evidence, confidence, resolution or
blocker, falsification test, and residual risk.

## Preservation rule

Historical ledgers are append-only. Large or duplicated context is handled by
an authored successor document and an explicit pointer; history is not silently
rewritten. Existing product second-pass state remains authoritative for product
gaps and is not replaced by this hygiene program.
