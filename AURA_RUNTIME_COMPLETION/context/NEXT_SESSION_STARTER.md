# AURA Next Session Starter — SP-007 is next, pending and unopened

> Written: 2026-08-16, after the SP-006 delivery and its follow-up.
> SP-006 was delivered to `origin/main` as `fe9e5db` (work + closeout),
> `ea695d2` (projection alignment), and `ee053f5` (untracked-artifact record).
> Never copy a commit out of this header; run `git rev-parse HEAD` and
> `git status --short` at session start.
>
> **`git status` will always show three untracked files** —
> `EV-SP-006-20260816-7SCENARIO-02.entries.log` and two `EV-SP-006-*.png`. That
> is the steady state, not unfinished work: `REPO_HYGIENE_SUPPLY_CHAIN_POLICY
> .json` forbids `.log`/`.png` as *tracked* paths, and H-003's principle forbids
> *ignoring* evidence paths, so they live on disk bound to the evidence record
> by SHA-256.
>
> Authoritative state is
> `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json` and
> `AURA_RUNTIME_COMPLETION/context/session-handoff.json`.

## Read this first

`SP-006` is **completed and delivered** — the seven-scenario live gate passed
under `EV-SP-006-20260816-7SCENARIO-02`, the mandatory closeout is recorded
under `EV-SP-006-20260816-CLOSEOUT-03`, and a follow-up under
`EV-SP-006-20260816-GAPCLOSE-04` closed the two gaps that closeout had
documented rather than fixed (see below).

Delivery went straight to `main` at the user's explicit direction rather than
the SP-004/SP-005 feature-branch + no-ff shape. Whichever shape a future session
uses, the standing rule holds: a go-ahead covers only the work completed when it
was given, and must be given **in the turn** the delivery happens.

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

Re-verified after the live re-run: **21/21 bundles / 899 tests / 0 failed**
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

## Follow-up since delivery (`EV-SP-006-20260816-GAPCLOSE-04`)

Two things the closeout had *documented rather than fixed* were then closed at
the user's direction:

1. **`CapabilityPlanner` is now on the production path.** It used to be
   constructed only in tests. `ToolRouter` now owns one and validates every
   routed intent through it (a missing required slot is refused by the planner,
   not by a handler), `IntentPlanGeneratedEvent` carries a `planFingerprint`,
   and `ToolRouter.routePlan` / `IntentDispatchCoordinator.executePlan` /
   `AuraKernel.executePlan` execute validated multi-step plans in dependency
   order — `.skipped` when a dependency did not execute, per-step declared
   `rollbackStrategy`, explicitly **not** transactional.
2. **Target confinement now exists at both layers.** Closing
   `RISK-SP-006-DEFAULT-GRANT-BREADTH` revealed production had been building
   `OpenTargetValidator()` with the default `approvedRoots: []` — *no root
   restriction* — while the grants used `patterns: [.any]`. Neither layer
   bounded where a file target could live. Both now read
   `AuraCore.DeclaredFileRoots`.

**Still not proved:** natural-language multi-step decomposition. The
structured-NLU layer proposes at most one capability per turn, so no user
sentence produces a multi-step plan — a caller must supply the steps. Recorded
in `capability-matrix.json` under `intent.capability_registry.open_gaps`.

3. **The live re-run (`EV-SP-006-20260816-LIVERERUN-05`) then caught that the
   scoping was inert.** `aura.policy.grants` had accumulated **895 grants** —
   seeding appended a fresh copy every launch — including **30 legacy `.any`
   grants** that `matchingGrant` reached first, so `/etc/hosts` was stopped only
   by the adapter. Fixed with a seed marker plus
   `PolicyEngine.reconcileSeededGrants`; the live migration pruned 886 then 25,
   settled at 16 grants, and `/etc/hosts` moved to a **policy** denial. Verified
   21/21 bundles, **899/899 tests**, 0 failed.

**Two pre-existing defects are open and unfixed — read these first:**

- `RISK-SP-006-URL-OPEN-FAILS-LIVE` — `url.open` has failed in *every* recorded
  run on this machine (13:18, 13:58, 14:12, 16:38). This **contradicts**
  `EV-SP-006-20260816-7SCENARIO-02`'s scenario-2 claim that Chrome launched, so
  treat that leg as **unproven** until re-demonstrated.
- `RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED` — a `quit Calculator`
  confirmation expired where SP-006 recorded an acceptance; cause undetermined.

Scenarios 4–7 were not re-run live in the follow-up; they rest on
`EV-SP-006-20260816-7SCENARIO-02` and the deterministic suite.

## Open residual risks to keep in view (none block SP-007)

- `RISK-SP-003-MODEL-LATENCY` — **bound widened to 28.5–49.0 s** (was
  19.8–36.1 s). Still inside the 90 s think budget and 120 s request timeout.
  Plan live runs around it; SP-006 had to raise its demo per-turn budget from
  45 s to 120 s after a 45 s cutoff produced a false `confirmationDenied`.
- `RISK-SP-004-TOCTOU-RACE`, `RISK-SP-004-HANDLER-COMPROMISE` (R10 scope);
  `RISK-INJECTION-COVERAGE-NON-DIALOGUE`; `RISK-SP-003-LIVE-VOICE-RESIDUAL`,
  `RISK-STT-MIC-NOT-CAPTURING` (voice track — the user is speech-disabled, so
  drive everything through the **text input / UI**, never the microphone).

## First actions in the next session

1. `git rev-parse HEAD` and `git status --short`. Expect a clean tree apart from
   the three declared-untracked evidence artifacts named in the header.
2. Read Tier 0 per `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`.
3. Read the two open `RISK-SP-006-*` risks above before anything else — one of
   them questions a recorded SP-006 scenario leg.
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
- Test counts: 21 bundles / 899 tests as of the SP-006 live re-run. A different
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
