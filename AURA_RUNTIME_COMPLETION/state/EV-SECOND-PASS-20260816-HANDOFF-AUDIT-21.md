# EV-SECOND-PASS-20260816-HANDOFF-AUDIT-21

Handoff-accuracy audit and control-plane reconciliation.

- **Timestamp:** `2026-08-16T10:08:19Z`
- **Branch / commit at audit start:** `main` @ `e8f5f434c8741d8a13231698030dcf7768140746`
  (`e8f5f43`), `HEAD == origin/main`, worktree clean.
- **Session / authority:** user instruction `be perfect` against a fully selected
  `AURA_RUNTIME_COMPLETION/context/NEXT_SESSION_STARTER.md`. Authority at audit
  start was **edit-only**. The user then explicitly authorized, in a single turn,
  (a) reconciling the stale governance state files, (b) opening `SP-004`, and
  (c) committing and pushing this audit to `main`. No app launch, install, TCC
  mutation, model download, provider contact, signing, or deployment occurred.
- **Evidence class:** control-plane / governance verification evidence. No
  product source was modified and no gap was closed.
- **Scope:** verification of every checkable claim in `NEXT_SESSION_STARTER.md`
  against live repository state, correction of the two false claims found, and
  reconciliation of the second-pass control plane. This evidence closes no
  prompt, no gap, and no live gate.

## Commands and procedure

| # | Command / procedure | Result |
|---|---|---|
| 1 | `git rev-parse HEAD` / `git rev-parse origin/main` / `git status --short` | `e8f5f43` == `e8f5f43`, tree clean |
| 2 | `./scripts/aura-test.sh /tmp/aurabuild-audit-20260816` (full output to file, not piped) | **21/21 bundles, 816 tests, 0 failures**, exit 0 |
| 3 | Count `.testTarget` entries in `Package.swift` vs bundles executed | 21 declared == 21 executed; no bundle omitted from the runner loop |
| 4 | `python3 scripts/validate_runtime_completion.py --ci` | exit 0 |
| 5 | `python3 scripts/validate_second_pass_program.py` | exit 0 |
| 6 | `python3 scripts/validate_repo_hygiene_program.py --ci` | exit 0 |
| 7 | `python3 scripts/validate_repo_hygiene_supply_chain.py --ci` | exit 0 |
| 8 | `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` | **38/38**, exit 0 |
| 9 | Existence check of `EV-SP-003-*-16` … `-20` on disk and in `EVIDENCE_INDEX.md` | all five present and registered |
| 10 | Frontmatter read of `SP-004` and `SP-005` prompts | both carry `gap_ids: OPEN-04` |

## Findings

### F1 — `NEXT_SESSION_STARTER.md` header commit was stale (corrected)

The document stated `Live HEAD == origin/main == d55aebb`. Live `HEAD` was
`e8f5f43`. `d55aebb` was the document's own **parent** commit: the starter was
authored before `e8f5f43` committed it, so the pointer was already wrong when it
shipped. Corrected in place, with the failure mode named so the next author does
not repeat it.

### F2 — `NEXT_SESSION_STARTER.md` overstated SP-004's scope (corrected)

The document stated "`SP-004` closes `OPEN-04` (track R3)". It does not.
`OPEN-04` carries two bullets — build the remaining filesystem/URL adapters, and
add NLU/UI reachability for the four capabilities that currently have only
direct-call reachability. `SP-005` carries the identical `gap_ids: OPEN-04`, and
`SP-004`'s own completion gate ends "no UI/NLU reachability is claimed yet".
Left uncorrected, that sentence authorizes closing `OPEN-04` one prompt early —
the same premature-completion failure mode that produced the retracted
`EV-SP-003-20260815-R2-DIALOGUE-TESTS-15`. Corrected, with an explicit "do not
mark `OPEN-04` closed at the end of SP-004" instruction.

### F3 — second-pass control plane was never brought forward after 2026-08-16 (reconciled)

All four validators passed throughout, because none of the drifted fields are
validator-enforced. Reconciled in this evidence's commit:

| File | Field | Was | Now |
|---|---|---|---|
| `SECOND_PASS_STATE.json` | `updated_at` | `2026-08-15T18:23:13Z` | `2026-08-16T10:08:19Z` |
| `SECOND_PASS_STATE.json` | `last_evidence_ids` | ended at `…-INJECTION-FIX-17` | `-18`, `-19`, `-20`, `-21` appended |
| `SECOND_PASS_STATE.json` | `next_action` | forwarded `RISK-SP-003-NLU-DOWNGRADE-VARIANCE` as open | risk set corrected to the three still open |
| `session-handoff.json` | `updated_at` | `2026-08-15T14:44:48Z` | `2026-08-16T10:08:19Z` |
| `session-handoff.json` | `last_verified_commit` | `813a504e…` | `e8f5f434…` |
| `session-handoff.json` | `completed[]` | last entry credited retracted `…-15` | correction entries appended; original wording preserved |
| `ACTIVE_CONTEXT.md` | second-pass overlay | stamped `18:23:13Z` | new overlay appended, prior preserved as superseded |
| `state/current-state.json` | `working_tree_state` | `clean` while tree was dirty | `dirty_expected` + describing entry |

`RISK-SP-003-NLU-DOWNGRADE-VARIANCE` was **closed** in `RISK_REGISTER.md` at
`2026-08-16T08:20:49Z` under `EV-SP-003-20260816-RISKS-AND-UI-19`, but
`SECOND_PASS_STATE.json` still forwarded it as an open residual. The starter
document's risk table was therefore *more current than the state file it
declared authoritative*. Where the two disagree, `RISK_REGISTER.md` wins.

### F4 — two reading traps recorded, deliberately not "fixed"

- `active_prompt: SP-004` paired with `active_state: completed` reads literally
  as "SP-004 is completed". It is the program's convention for "active_prompt =
  next eligible, active_state = state of the prompt just closed", and
  `validate_second_pass_program.py` **enforces** that `SECOND_PASS_STATE.json`,
  `session-handoff.json` and `ACTIVE_CONTEXT.md` all carry the same pair
  (lines 251–273). Editing one file alone would fail the validator, so the pair
  is preserved unchanged and documented instead. The real non-completion guard
  is `completed_prompts`, which correctly excludes `SP-004`. Note also that
  prompt frontmatter `state:` is `pending` for **every** SP prompt including the
  finished ones, so frontmatter alone never proves a prompt is unopened.
- `validate_second_pass_program.py` rejects `--ci`, which the other three
  validators require; passing it uniformly makes that one exit 2 via argparse.

### F5 — method note

During this audit the four validators were first run piped through `tail`, which
masked their real exit codes behind the pipe's, and a `for`-loop relied on word
splitting that `zsh` does not perform, silently mangling three invocations into
"file not found" while the summary still read green. Both were caught by
re-running with exit codes captured directly. This is the same class of masking
recorded for the test runner: **never pipe a validator or the test runner
through `tail`.**

## Falsifier

This conclusion is falsified by any of: `git rev-parse HEAD` disagreeing with
the recorded `e8f5f43` at audit time; a validator exiting non-zero at that
commit; the full sweep reporting fewer than 21 bundles, or any failure; a
`.testTarget` in `Package.swift` absent from the runner's executed set; or
`SP-005` not carrying `gap_ids: OPEN-04`.

## Limitations

- No live-model, live-voice, microphone, TCC, or running-application behaviour
  was exercised or claimed. The full sweep is deterministic and offline; both
  live suites remained disabled by default.
- This audit verifies the **accuracy of recorded state**, not the correctness of
  the underlying SP-003 work. `EV-SP-003-*-16` … `-20` remain the evidence for
  that, and none of them were re-executed here.
- `verified_head` / `remote_head` / `capability-matrix.repository_commit`
  remained at `d55aebb` during the audit. This is permitted:
  `validate_runtime_completion.py` accepts a `verified_head` that is an ancestor
  of live `HEAD` when the intervening diff is projection-only. Realigning them
  after this commit is a separate `chore(state):` step.

## Residual risks

Unchanged and forwarded; none owned by this audit, none blocking `SP-004`:
`RISK-INJECTION-COVERAGE-NON-DIALOGUE`, `RISK-SP-003-MODEL-LATENCY`,
`RISK-SP-003-LIVE-VOICE-RESIDUAL`, `RISK-STT-MIC-NOT-CAPTURING`.
`RISK-SP-003-NLU-DOWNGRADE-VARIANCE` is closed under
`EV-SP-003-20260816-RISKS-AND-UI-19` and is **not** forwarded.

A new low-severity observation is recorded rather than closed: no mechanism
forces a future handoff document to be re-verified against live state before it
is trusted. F1 and F2 were both authored by a session that had the correct facts
in context at the time of writing.
