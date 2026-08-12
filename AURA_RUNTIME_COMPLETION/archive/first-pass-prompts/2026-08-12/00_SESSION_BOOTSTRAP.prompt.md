# BOOTSTRAP — Fresh-Session Baseline Reconciliation Prompt

You are starting or resuming the AURA Runtime Completion Program in a session with no trusted chat history.

Follow `AGENTS.md` and `AURA_RUNTIME_COMPLETION/prompts/SHARED_EXECUTION_CONTRACT.md` exactly.

## Mission

Establish a truthful, schema-valid, evidence-backed execution baseline. Do not implement product features in this prompt. The only acceptable outcome is a reconciled repository/program state that makes R0 safely executable.

## Minimum initial context

Read only:

1. `AGENTS.md`
2. `AURA_RUNTIME_COMPLETION/prompts/SHARED_EXECUTION_CONTRACT.md`
3. `AURA_RUNTIME_COMPLETION/state/current-state.json`
4. `AURA_RUNTIME_COMPLETION/context/session-handoff.json`
5. `AURA_RUNTIME_COMPLETION/context/READ_FIRST.md`
6. `AURA_RUNTIME_COMPLETION/prompts/prompt-manifest.json`
7. this prompt

Then use `AURA_RUNTIME_COMPLETION/context/context-index.json` to load only the additional files needed for reconciliation.

## Required preflight

### A. Authority

Extract the current user’s explicit authority and update the in-memory authority matrix before any write. Distinguish:

- inspect/read;
- edit;
- install dependency;
- download model;
- mutate TCC/permissions;
- install/launch app;
- create branch;
- commit;
- push;
- merge;
- sign/notarize;
- release/deploy.

Do not inherit authority from the seeded JSON or an older session.

### B. Live repository state

Verify and record:

- repository root and remote;
- current branch;
- exact `HEAD` and remote default-branch head;
- ahead/behind/diverged relation;
- working tree status;
- untracked files;
- submodules if any;
- user-owned changes;
- last relevant commits;
- whether the prompt suite files exist and are complete.

If the live state differs from `current-state.json`, live evidence wins. Reconcile before proceeding.

### C. JSON and manifest integrity

Validate:

- `AURA_RUNTIME_COMPLETION/prompts/prompt-manifest.json`
- `AURA_RUNTIME_COMPLETION/state/current-state.json`
- `AURA_RUNTIME_COMPLETION/state/capability-matrix.json`
- `AURA_RUNTIME_COMPLETION/context/session-handoff.json`
- `AURA_RUNTIME_COMPLETION/context/context-index.json`

against the schemas in `AURA_RUNTIME_COMPLETION/schemas/`.

Use an installed standards-compliant validator when available. If none exists and dependency installation is not authorized, perform deterministic parse/structural checks without pretending full JSON Schema validation occurred. Record the evidence class and limitation.

Verify:

- every prompt file in the manifest exists;
- order and dependency graph are acyclic;
- the active prompt matches state;
- every risk/evidence/capability identifier uses the declared format;
- every referenced schema path resolves;
- every required first-read path exists.

### D. Legacy status reconciliation

Inspect only the relevant sections of:

- `ledger/CURRENT_STATE.md`
- `SESSION_STARTER.md`
- newest relevant `ledger/PROJECT_LEDGER.md` entries
- latest commits

Identify stale or contradictory claims. Do not rewrite historical append-only records. Decide whether R0 should:

- replace legacy current-state projection;
- add a compatibility pointer to the new state;
- generate legacy prose from JSON;
- add a contradiction CI validator;
- archive or deprecate stale starter text.

Record findings as risks and R0 tasks.

### E. Toolchain and external dependency inventory

Record exact observed versions and health for items required to begin R0:

- macOS and hardware profile;
- Xcode/CommandLineTools path and build;
- Swift version and SDK;
- Python used by Chatterbox tooling;
- Git and GitHub authentication;
- repository test wrapper;
- self-hosted CI availability if observable.

Do not verify unrelated CLIs/models yet. R0 will establish the durable toolchain contract.

## Deliverables

1. Append a `BOOTSTRAP_STARTED` and `BOOTSTRAP_COMPLETED` entry to `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md` if edits are authorized.
2. Update `AURA_RUNTIME_COMPLETION/state/current-state.json` with:
   - live branch/head/remote relation;
   - working-tree state;
   - current authority;
   - session ID;
   - reconciled blockers;
   - BOOTSTRAP state `completed`;
   - R0 state `ready` only if all bootstrap gates pass;
   - exact next action.
3. Replace `AURA_RUNTIME_COMPLETION/context/session-handoff.json` with a concise handoff for R0.
4. Update `ACTIVE_CONTEXT.md` only if the immediate context changed.
5. Add evidence-index entries for repository reconciliation and JSON/manifest validation.
6. Add or update risk-register entries discovered during bootstrap.
7. Do not modify product source code.

## Required evidence

At minimum:

- `EV-BOOTSTRAP-<date>-REPOSITORY-STATE-01`
- `EV-BOOTSTRAP-<date>-SCHEMA-MANIFEST-01`
- `EV-BOOTSTRAP-<date>-TOOLCHAIN-INVENTORY-01`

Each must state whether it is automated, manual, or partial and include limitations.

## Completion gate

BOOTSTRAP is complete only if:

- live repository state is known;
- stored state no longer falsely claims a different head/branch/worktree;
- prompt manifest and JSON files parse and satisfy available validation;
- prompt dependencies are coherent;
- user authority is explicitly recorded;
- legacy contradictions are captured as R0 work, not silently ignored;
- no unrelated user change was overwritten;
- R0 has one exact first implementation action.

If any gate fails, leave BOOTSTRAP `blocked` with the exact blocker. Do not mark R0 ready.

## Required final report

- verified repository state;
- validation results;
- authority matrix;
- contradictions found;
- toolchain inventory;
- files updated;
- evidence IDs;
- blocker status;
- exact R0 first action.

End by running the closeout procedure in `15_SESSION_CLOSEOUT.prompt.md`.
