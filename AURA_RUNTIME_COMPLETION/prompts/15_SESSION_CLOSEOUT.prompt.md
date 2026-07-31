# SESSION CLOSEOUT — Anti-Amnesia and Ledger Handoff Prompt

Run this prompt at the end of every implementation session, including blocked, interrupted, failed, or partially completed sessions.

## Mission

Leave the repository in a state that a new session can resume safely without chat history, hidden assumptions, or unbounded context loading.

## 1. Verify before writing the handoff

Record:

- current branch and exact `HEAD`;
- remote relation;
- working tree status;
- user-owned/unrelated changes;
- active prompt/track and actual state;
- files changed this session;
- commands/tests/live procedures actually run;
- evidence IDs created;
- blockers, open decisions, and risks;
- current authority and any authority that expired with the session.

Do not claim a test ran if it did not. Do not claim a capability works if only a fake or unit test ran.

## 2. Review the diff

Before commit or handoff:

- inspect scope and accidental changes;
- check formatting/static issues;
- check secrets/private content;
- check generated files and schemas;
- ensure no unrelated user change is overwritten;
- ensure no TODO/placeholder is represented as complete;
- ensure security and acceptance criteria were not weakened;
- ensure documentation matches implementation.

Commit/push only if explicitly authorized.

## 3. Ledger entry

Append one completion/interruption entry to `ledger/runtime_completion/PROGRAM_LEDGER.md` containing:

- timestamp and session ID;
- actor;
- active prompt;
- verified start and end commit;
- objective;
- delivered changes;
- evidence IDs;
- acceptance verdict by criterion;
- blockers and residual risks;
- authority boundary;
- exact next safe action.

If correcting prior state, append a reconciliation entry. Never rewrite previous entries.

## 4. Evidence and risk updates

- add concise rows to `EVIDENCE_INDEX.md`;
- add/update risks in `RISK_REGISTER.md`;
- add/update decision status in `DECISION_REGISTER.md`;
- update capability statuses only to the highest proven evidence class.

## 5. Machine state update

Atomically replace `ledger/runtime_completion/current-state.json` and validate it.

Update:

- timestamp/session;
- repository branch/head/remote/working tree;
- program status;
- active prompt/state/step;
- track states/evidence/risks;
- authority reset for the next session unless standing authority was explicitly granted;
- release gates;
- blockers;
- exact next action.

Do not place verbose history in the state JSON.

## 6. Session handoff update

Atomically replace `anti_amnesia/runtime_completion/session-handoff.json` and validate it.

Keep it concise. Include only:

- last verified commit;
- active prompt and exact step;
- short summary;
- completed items;
- files changed;
- evidence/test results;
- blockers;
- open decisions;
- risk IDs;
- one exact next action;
- mandatory first-read files.

Remove stale details from previous sessions.

## 7. Human context update

Update `ACTIVE_CONTEXT.md` only if the active prompt, immediate objective, or major blockers changed.

Update `KNOWN_FACTS.md` only for stable evidence-backed facts that will remain relevant across future tracks.

Do not copy ledger history into either file.

## 8. Validate closure artifacts

Validate or deterministically check:

- current-state JSON and schema;
- session-handoff JSON and schema;
- capability matrix and schema if changed;
- prompt manifest integrity;
- evidence/risk/decision references;
- active prompt dependencies;
- repository state stored in the handoff.

Record a closeout evidence item when the phase has meaningful implementation work.

## 9. Required final response

Report only:

- active prompt and status;
- work completed;
- verification/evidence;
- unresolved blockers/risks;
- repository/commit state;
- exact next prompt and first action.

Do not include private chain of thought, raw logs, secrets, or unnecessary historical detail.
