# AURA Next Session Starter — SP-009 is next, pending and unopened

> Written: 2026-08-17, after SP-008 closed OPEN-05's adversarial and recovery
> residuals. Never copy a commit out of this header; run `git rev-parse HEAD`
> and `git status --short` at session start.
>
> Authoritative state is
> `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json` and
> `AURA_RUNTIME_COMPLETION/context/session-handoff.json`. This file is a
> reading aid, not authority.

## The worktree is dirty, and that is expected

`git status` will show two distinct groups. Neither is unfinished work to
"clean up":

1. **Four untracked SP-006 evidence artifacts** —
   `EV-SP-006-20260816-7SCENARIO-02.entries.log`,
   `EV-SP-006-20260816-LIVERERUN-05.entries.log`,
   `EV-SP-006-scenarios1-2-ui.png`, `EV-SP-006-scenario3-quit.png`.
   `REPO_HYGIENE_SUPPLY_CHAIN_POLICY.json` forbids `.log`/`.png` as *tracked*
   paths, and H-003's principle forbids *ignoring* evidence paths, so they live
   on disk bound to their evidence records by SHA-256. Permanent steady state.
2. ~~**All of SP-008's work, local and uncommitted**~~ — **superseded
   2026-08-17T08:15:11Z**: SP-008 was delivered under an explicit in-turn
   go-ahead, together with the corrections in
   `EV-SP-008-20260817-CORRECTION-03`. Only group 1 above should still appear
   as untracked; if anything else is dirty, it is new work, not SP-008's.

## Where the program actually is

`SP-008` is **completed** for `OPEN-05`'s adversarial and recovery residuals, at
the deterministic boundary its own authority covers. `completed_prompts` =
`SP-000`…`SP-008`. `SP-009` is next eligible, **pending and unopened**.

**Mind the convention trap.** `active_prompt` / `active_state` reading
`SP-009` / `completed` means "SP-009 is next, SP-008 just closed" — it does not
mean SP-009 ran. And prompt frontmatter reads `state: pending` on *every* SP
prompt including finished ones, so frontmatter alone never proves a prompt is
unopened. The authoritative guard is `completed_prompts`.

## What SP-008 changed, and what it deliberately did not

Reading the production computer-use path found three defects of one kind — a
fail-closed control correct at one layer and silent at the next:

| Defect | Fix |
|---|---|
| A focused secure field returned non-terminal `.stop`, so the session looped to its budget and reported `noProgress` — failing closed but naming the wrong reason | Terminal `ComputerUseLoopOutcome.secureFieldBlocked` |
| `AXCGEventActionExecutor` enforced emergency stop unconditionally but had no secure-field equivalent, so a direct call could type into a credential field | Required `secureFieldDetector`; every input-generating kind refused, `.wait` exempt |
| An off-screen window was refused correctly but reported as `sensitiveApplication` | `ScreenContextEngine.exclusionReason(for:)` is the single source of truth; new `ScreenCaptureBlockReason.windowNotVisible` |

The beta allowlist moved into `ComputerUseBetaAllowlist.liveValidatedProduction`
so allowlist confinement is a value a test asserts against. **No app was added**
— the SP-007 bundle validates Finder, Terminal and Notes and nothing else.

`Tests/AuraComputerUseTests/R4AdversarialSafetyTests.swift` (25 tests) covers
injection, secure-field refusal at both layers, modal mismatch, wrong identity,
cancellation, restart/re-arm, emergency stop at all four stage boundaries, a
hostile planner, and hidden-window/sensitive-app/self-capture refusal. Every
case asserts the executor call count, not merely the reported outcome.

Verified: **21/21 bundles, 931/931 tests, 0 failed**; all four governance
validators exit 0; 38/38 governance unit tests. Evidence:
`EV-SP-008-20260817-ADVERSARIAL-01`, `EV-SP-008-20260817-CLOSEOUT-02`,
`EV-SP-008-20260817-CORRECTION-03`.

**Re-verified after closure (`EV-SP-008-20260817-CORRECTION-03`).** The whole
sweep was re-run from the tree rather than read off these records; the technical
closure stands. Two record defects were corrected — the new-test count (22 to 25)
and the prior bundle total (71 to 68) — along with `session-handoff.json`'s
`active_prompt.file`, which still named SP-008's prompt while its `id` read
`SP-009`. One finding was recorded rather than fixed:
**`RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE`** — `ComputerUseControlLoop.run` is
called only by `AuraKernel.computerUseRun`, which has no caller anywhere, and
`IntentKind`/`ToolRouter` have no computer-use branch. Nothing in the shipped
product can currently drive the loop SP-008 hardened. **Do not silently absorb
this into SP-009** — it is R4 productization wiring and needs its own prompt and
authority.

**What it did not do:** no live run. SP-008's hard boundary withholds
launch/install/TCC authority, and the user was asked directly and chose to close
on the deterministic boundary rather than grant it.

## Read this before starting SP-009

`RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL` is the one to read first. SP-008 proved
the *control flow*: given a detector that reports a secure field or a modal, the
loop and the executor both refuse, and emergency stop terminates at every stage.
What is unproven is the layer beneath — `AccessibilitySecureFieldDetector` and
`AccessibilityModalDialogDetector` have never been observed against a real
credential field or a real `SecurityAgent` dialog, and generated-event cessation
has not been watched on hardware. **A detector that silently returns `false`
would make every guard above it inert while all tests still pass.** That is the
same failure shape as `RISK-SP-006-DEFAULT-GRANT-BREADTH`, whose test-only
closure proved premature on live evidence — do not repeat it.

Also open, and worth reading before trusting any SP-006-era claim:
`RISK-SP-006-URL-OPEN-FAILS-LIVE` (the `url.open` adapter leg has failed in
every recorded run, contradicting SP-006 scenario 2's "Chrome launched" claim —
treat that leg as unproven) and
`RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED`.

New from SP-008: `RISK-SP-008-PLANNER-DECLARED-INTENT-TRUST` — semantic intent
is *declared by the planner* and `riskTier` is a pure function of it, so a
future model-backed planner could label a destructive keystroke `.observe` and
be evaluated at observation tier. Sound today because the only production
conformer is the curated deterministic planner.

## A pointer trap that already bit once

`validate_runtime_completion.py` was failing at clean `HEAD` for a whole session
before SP-008 noticed. SP-007's delivery commit changed product source but never
advanced `verified_head` / `remote_head` / the capability matrix's
`repository_commit`. **After any delivery that touches non-projection paths,
advance all three together.** SP-008 repaired them to `0000b4a`; note that the
content verification at that SHA rests on SP-007's recorded sweep, not a fresh
clean-tree run.

## First actions in the next session

1. `git rev-parse HEAD`, `git rev-parse origin/main`, `git status --short`.
2. Read Tier 0 per `SECOND_PASS_READ_FIRST.md`, then the `SP-009` prompt.
3. Run `python3 scripts/validate_second_pass_program.py` and the other three
   validators before any product work; if a projection disagrees, repair it
   first.
4. Open `SP-009` only under its own explicit authority. Authority is currently
   **edit-only**: no install, launch, TCC mutation, provider contact, beta
   enrollment, signing, commit, push, merge, release, or deploy.
