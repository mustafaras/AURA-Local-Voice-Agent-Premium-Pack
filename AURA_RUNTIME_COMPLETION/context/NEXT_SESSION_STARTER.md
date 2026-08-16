# AURA Next Session Starter — SP-007 is next, pending and unopened

> Written: 2026-08-16 at the SP-006 closeout.
> `HEAD == origin/main == 94e9e36a149bfd1913d67ebf76e7e29ec9e9e8a5`, but the
> **worktree is dirty on purpose**: the whole SP-006 change set is still local
> and uncommitted. Never copy a commit out of this header; run
> `git rev-parse HEAD` and `git status --short` at session start.
>
> Authoritative state is
> `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json` and
> `AURA_RUNTIME_COMPLETION/context/session-handoff.json`.

## Read this first: SP-006 is delivered as *work*, not as *commits*

`SP-006` is **completed** — the seven-scenario live gate passed under
`EV-SP-006-20260816-7SCENARIO-02` and the mandatory closeout is recorded under
`EV-SP-006-20260816-CLOSEOUT-03`. What has **not** happened is delivery. The
SP-006 source changes, tests, evidence artifacts, and control-plane projections
are all sitting in the working tree.

The user granted commit/push/merge authority for SP-006 in the previous
starter, and that grant is recorded — but the standing project rule is that a
go-ahead covers only the work completed when it was given, and must be given
**in the turn** the delivery happens. So: **ask, then deliver.** The intended
shape is the SP-004/SP-005 pattern — feature branch, then no-ff merge to `main`
(`09df409`, `75b42ae`).

Not in scope without a fresh explicit grant: dependency installs, model
downloads, provider accounts, telemetry, beta enrollment, Developer-ID
signing/notarization, release, deployment.

## Where the program actually stands

| | |
|---|---|
| Completed | `SP-000` … `SP-006` |
| Next eligible | **`SP-007`** — pending and **unopened** |
| Blocked | none |
| `OPEN-04` | **closed**, and its forwarded live-gate bullet is now satisfied by SP-006. |

Re-verified at the SP-006 closeout: **21/21 bundles / 880 tests / 0 failed**
(totals recomputed from the log, not read off a summary line), all four
governance validators exit 0. Recheck these rather than trusting the numbers.

## What SP-006 actually proved, and what it did not

Proved live, on the running app, through the production text → `Conversation` →
`IntentEngine` → `ToolRouter` → `PolicyEngine` → adapter path with the local
`gemma4:latest` model (cloud inference count 0): observation, reversible
file/URL opens with real OS effects, confirmed mutation, unavailable capability
staying unavailable, malformed model-plan rejection, and capability-health
inspection. Cancellation, partial failure, rollback declaration, and
no-unauthorized-delivery controls also pass.

Two real defects were found and fixed *because* the run was live:

1. The four `.reversible` filesystem/URL capabilities had **no seeded policy
   grant**, so every live request would have been denied before the adapter —
   despite the capabilities being registered `.ready`. Fixed by extracting
   `Sources/AuraPolicy/DefaultPolicyGrants.swift` (testable outside the `AURA`
   executable target) and seeding `.none`-confirmation grants that match each
   manifest's declared `confirmationRule`.
2. `ToolRouter.handleFileOpen` routed a `folderPath` slot to `openFile`, which
   refuses non-regular files. Fixed to dispatch on the slot.

**Not proved, and worth knowing before SP-007:** `CapabilityPlanner` is
constructed only in tests — `grep -rn "CapabilityPlanner(" Sources/` returns
nothing. Scenario 4's two-step plan was built by the harness and executed step
by step through the *real* registry/policy/adapter objects, which satisfies the
completion gate, but no production path decomposes a sentence into a plan. That
wiring is a pre-existing R3 residual recorded in `capability-matrix.json` under
`intent.capability_registry.open_gaps`.

## Open residual risks to keep in view (none block SP-007)

- `RISK-SP-006-DEFAULT-GRANT-BREADTH` — **new.** The three grants above use
  `patterns: [.any]`, so policy-layer target narrowing for filesystem/URL is
  absent and every refusal now rests on `OpenTargetValidator`. Closure needs
  pattern-scoped grants or an explicit accepted-risk decision under R10.
- `RISK-SP-003-MODEL-LATENCY` — **bound widened to 28.5–49.0 s** (was
  19.8–36.1 s). Still inside the 90 s think budget and 120 s request timeout.
  Plan live runs around it; SP-006 had to raise its demo per-turn budget from
  45 s to 120 s after a 45 s cutoff produced a false `confirmationDenied`.
- `RISK-SP-004-TOCTOU-RACE`, `RISK-SP-004-HANDLER-COMPROMISE` (R10 scope);
  `RISK-INJECTION-COVERAGE-NON-DIALOGUE`; `RISK-SP-003-LIVE-VOICE-RESIDUAL`,
  `RISK-STT-MIC-NOT-CAPTURING` (voice track — the user is speech-disabled, so
  drive everything through the **text input / UI**, never the microphone).

## First actions in the next session

1. `git rev-parse HEAD` and `git status --short`. Confirm the SP-006 tree is
   still present and uncommitted.
2. Read Tier 0 per `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`.
3. Ask the user whether to deliver SP-006 now (feature branch + no-ff merge)
   before anything else — an uncommitted tree of this size is the main risk
   carried into this session.
4. Only then, and only under its own explicit authority, open SP-007
   (`SP-007_LIVE_COMPUTER_USE_PLANNER_IN_APPROVED_APPS.prompt.md`) and read its
   Tier 1 set.

## Traps carried forward (do not relearn)

- Prompt frontmatter `state: pending` appears on **every** SP prompt, including
  completed ones — the validator enforces it. Truth is in
  `SECOND_PASS_STATE.json.completed_prompts`.
- `active_prompt`/`active_state: SP-007/completed` means "SP-007 is next, SP-006
  just closed" — not "SP-007 is done".
- **The second-pass validator derives its `ACTIVE_CONTEXT.md` requirement from
  `SECOND_PASS_STATE.json`.** Advancing `active_prompt` without writing the
  matching `` `SP-NNN` / `<state>` `` overlay in `ACTIVE_CONTEXT.md` turns the
  validator red *after* the state edit. This exact mistake ended the SP-006
  session with a failing validator and two ledgers claiming it was green.
- `validate_second_pass_program.py` rejects `--ci`; the other three require it.
- Handoff JSON is schema-strict: `risks` (not `risk_ids`),
  `required_first_reads` (not `mandatory_first_read`), `tests` entries are
  objects `{name, result, evidence_id}`, `last_verified_commit` must be a full
  40-char hash, `evidence_ids` must exist in `EVIDENCE_INDEX.md`.
- `EVIDENCE_INDEX.md` rows are appended after the last existing row; never in
  table syntax at the end of a paragraph.
- `capability-matrix.json.repository_commit`, `current-state.json
  .verified_head/remote_head`, and `session-handoff.json.last_verified_commit`
  must be aligned to the same commit **in the same commit**.
- **The capability matrix rots quietly.** Bumping its header while leaving a
  capability row describing a world three prompts old passes every validator.
  SP-006's closeout found `intent.capability_registry` still claiming "no
  adapter yet" and "the live demonstration has not been performed". Update the
  row, not just the header.
- **`RISK_REGISTER.md` is a named required record in the SP prompts** and is
  easy to skip because nothing enforces it.
- Test counts: 21 bundles / 880 tests with the SP-006 tree applied. A different
  total means a bundle was skipped or a test silently dropped — investigate.
- **Never use plain `swift test`.** Use
  `./scripts/aura-test.sh /tmp/<unique-path> [bundle-filter]` and capture full
  output to a file — piping through `tail` has already hidden a real failure.
  Recompute totals from the log rather than trusting a summary line.
- **iCloud breaks code signing**: the repo lives under an iCloud-synced
  Desktop. Copy the bundle outside the synced tree and `xattr -cr` before
  signing.
- **The installed app is not what you build**: `/Applications/AURA.app` is a
  separate copy; check its mtime before claiming the user sees current code.
- **TCC is per executable**; a grant to `AURA.app` does not extend to the
  SwiftPM test helper.
- Evidence artifacts live in `AURA_RUNTIME_COMPLETION/state/`, never `/tmp`.
- Ledgers are append-only; corrections are new entries, historical wording
  preserved.
