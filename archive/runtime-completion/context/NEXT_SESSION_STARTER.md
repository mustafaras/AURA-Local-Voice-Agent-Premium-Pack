# AURA Next Session Starter — SP-033 completed under ADR-053; chain COMPLETE (local scope)

> Updated 2026-09-03 after the SP-033 ADR-053 synthetic-accepted completion.
> **Never copy a commit out of this header.** Run `git rev-parse HEAD` and
> `git status --short` first — this file is a reading aid, not authority.
>
> Authoritative state: `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json`
> and `AURA_RUNTIME_COMPLETION/context/session-handoff.json`.

## Current scope overlay — 2026-09-03

`EV-SP-033-20260903-SYNTHETIC-ACCEPTED-01` records the SP-033 completion under
`docs/decisions/ADR-053-live-evidence-synthetic-scope.md` (Accepted): the user
declared live-user acceptance not required, and gates blocked solely on absent
live evidence are closed with synthetic/deterministic/local-observed evidence.
The second-pass chain SP-000–SP-033 is **COMPLETE for the synthetic-accepted
local scope**; `validate_second_pass_program.py` + unit tests PASSED; all
projections synchronized.

`beta-readiness.json` `readiness_status` and `release_candidate.status` remain
`blocked` / `approved:false` (`release_or_deploy:false`; ADR-049 keeps Developer
ID/notarization/external distribution out of scope). No synthetic evidence is
relabeled as live/beta/signed/notarized/production. External distribution, if
ever required, needs a new ADR and cannot be derived from this closure.

Historical SP-031 review instrument:
`docs/operations/SP-031_LOCAL_ONLY_PACKAGE_REVIEW_PACKET.md`; preparation
evidence `EV-SP-031-20260902-REVIEW-PACKET-01`; closeout
`EV-SP-031-20260902-CLOSEOUT-REVIEW-PACKET-01`. The owner decision is
`EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`. The next action is to
preserve the synthetic-accepted completeness and the blocked external-release
boundary; only a future authorized ADR can open external distribution.

## Historical diagnostic record — 2026-09-02 unattended alternate verification

`EV-SP-030-20260902-UNATTENDED-ALTERNATE-01` records the latest attempt. Without
the owner present, `AuraLifecycleTests` passed 48/10/0,
`AURAIntegrationTests` 111/22/0, and `AuraSTTTests` 19/4/0. The explicitly
opt-in synthetic Speech path failed closed in three real-recognizer tests with
`speechNotAuthorized`; no TCC mutation or permission prompt was requested.
These are deterministic/synthetic checks, not live-beta evidence. They do not
close `ptt_ack`, `stt_partial`, live dialogue latency, R11 recovery,
scenario-window, or incident-review gates. At that stage SP-030 remained
blocked; the later ADR-051 scope amendment recorded local-only completion while
preserving those broader live gates as open. The older historical status below
is retained as history; use the authoritative JSON and the current scope
overlay above for the current state.

## Read these first, in this order

1. `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md` (Tier 0/1 contract)
2. `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
3. `docs/decisions/ADR-050-independent-review-model.md` — **Accepted.** It governs
   every sign-off decision below. Read it before touching `signoffs`.
4. `docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md` — Rounds 2 and 3 plus
   the **correction** to Round 3. Read the correction; do not cite the withdrawn figures.

## Historical status reconciliation before ADR-051: SP-030 was `blocked`, not `in_progress`

The previous handoff said `in_progress`. The record simultaneously said
`blocked_prompts: ["SP-030"]`, `"SP-030 BLOCKED/IN_PROGRESS"` in two JSON files,
and carried a heading reading `` `SP-030` / `in_progress` / **BLOCKED** ``. Those
cannot all be true. It was reconciled to **`blocked`** on the control contract's
own definition — *"A blocked prompt has an explicit blocker and remains the active
prompt"* — which was exactly SP-030's situation at that time. Emptying `blocked_prompts` to match
`in_progress` was rejected because it would have hidden the blocker.
See `EV-SP-030-20260830-RECORD-INTEGRITY-01`.

ADR-051 later superseded this historical live-beta-only state for the
owner-approved local-only scope: SP-030 is now completed for deterministic
validation, while the broader live-beta gates and downstream SP-031 remain
blocked.

## Do not trust the previous starter's test claim

It said: *"Python suite has 3 pre-existing failures unrelated to this work…
Do not 'fix' them as if they were new."* **That was wrong.**

- One of the three was a **harness artifact** — `uv lock --check` blocked by the
  agent's Bash sandbox. It passes outside the sandbox and was never a defect.
- The other two were **regressions introduced by the uncommitted work**, verified
  against `HEAD`: an `active_prompt.step` of 521 chars against a 500 `maxLength`
  (405 and valid at `HEAD`), and the status incoherence above.

Both are fixed. **`python3 -m unittest discover -s scripts/tests` is now 58 tests,
OK, 0 failures.** If you see 3 failures, check whether you are inside the sandbox.

Fixing them let `validate_runtime_completion.py` run past its first error, which
exposed two more false claims — `working_tree_state: "clean"` with a dirty tree,
and a `verified_head` bumped past the commit `capability-matrix.json` was actually
generated at. Both fixed; the matrix was **not** bumped, because that would have
fabricated a capability verification.

## The worktree is dirty and nothing was committed

29 modified + 20 untracked. **This is complete, validated work the owner has not
asked to be committed.** Do not "clean it up", do not revert it, do not commit it
unasked. `current-state.json` now declares this honestly as `dirty_expected` with
the change groups described in `repository.user_owned_changes`.

## Historical SP-030 state before the local-only scope decision

Gate: *"Mandatory SLOs and scenarios pass, incidents are remediated, and
independent sign-offs are complete."* Not met. **Do not start SP-031.**

| Item | State |
|---|---|
| `false_success` | measured 0.0 (`deterministic_harness`) |
| `unauthorized_action` | measured 0 (`deterministic_harness`) |
| `dialogue_first_token` | measured — **lower bound only**, no target asserted |
| `ptt_ack`, `stt_partial` | **not_measured** |
| scenario matrix (5) | passed, `deterministic_harness` — never run in a live window |
| incident_review | `not_run` — no beta window has produced incidents |
| `privacy` sign-off | **obtained** |
| `security` sign-off | blocked on the DeepSeek cross-review |
| `accessibility_localization` | **REFUSED** (not deferred) |
| `release_recovery`, `product_truthfulness` | awaiting the owner |

Swift suite: **1307 tests / 84 suites / 22 bundles, 0 failures.**
Python: **58 tests, OK.** All **three** validators exit 0.

## Historical owner-dependent items at that time

Authority does not substitute for any of them.

1. **DeepSeek cross-review** — `docs/operations/CROSS_REVIEW_REQUEST_FOR_DEEPSEEK.md`.
   The owner runs it in VS Code Copilot. **`security` cannot close without it**:
   ADR-050 §4 disqualifies a reviewer from artifacts it authored, and Claude Code
   authored the F-001 fix, the R12 contract, and the F-005 remediation.
2. **Owner sign-offs** — `docs/operations/OWNER_SIGNOFF_FALSIFICATION_PACKET.md`
   for `release_recovery` and `product_truthfulness`. ADR-050 §3 requires these to
   rest on that packet, not on a summary. **The owner said "I approve everything"
   several times; that was recorded as authority, never as review. Do not convert
   it into a sign-off.**
3. **Turkish translation review — this is now the largest open item.** The owner
   chose "fix it and the rest", so `AuraCopy` went from 72 keys at `HEAD` to **184**,
   with **96 added in this session**. Every one was written by the implementing
   agent, which cannot judge its own Turkish. The review that was ~20 strings is now
   well over a hundred. That growth is the accepted cost of the coverage decision,
   and it is why `accessibility_localization` is still refused. The owner is a
   native speaker. Unreviewed translation is not correct translation.
4. **R11 live gates and `ptt_ack`** — launch-at-login, sleep/wake/crash, safe mode,
   migration, and push-to-talk latency all need the app running with the owner present.

## The plumbing refactor is DONE — and it was never a refactor

`EV-SP-030-20260830-A11Y-COVERAGE-02`. The previous starter described
`AuraConfirmationCard` and `MemoryCorrectionSheet` as needing the language
"plumbed in". Both already held `@ObservedObject var model: AuraAppModel`, so
`model.productUIState.language` was reachable the whole time; the only thing
missing was the two-line `language`/`copy()` helper every other view defines.
That is all `cannot find 'copy' in scope` ever meant.

Wiring it surfaced a **new finding of the same severity class as the emergency
control**: the whole confirmation card — title, risk/expiry line, and **both the
Deny and Allow Once buttons** — was hardcoded English. A Turkish user was reading
English at the moment of authorizing a real, side-effecting action.

Now localized: the confirmation card, the memory correction sheet,
`AuraMessageBubble` (trace prefix + "Degraded response"), and the menu-bar status
label in `AURA.swift`. `language` is threaded into `AuraMessageBubble` as a
**required** parameter — an `.english` default would let a caller silently
reintroduce the bug.

## F-005 coverage is CLOSED — the refusal moved, it did not lift

`EV-SP-030-20260830-A11Y-COVERAGE-03`. After the owner chose "fix it and the rest",
the permission readout (seven hardcoded names **and** `PermissionState.title`, now
`title(for:)` with no unlocalized overload left behind), `MemoryRowView` metadata,
all of `AuraSettingsView`, the capability/model tabs, memory controls, the deletion
receipt's visible lines, recovery, the VS Code bridge and the memory-search
placeholder were all routed through `AuraCopy`.

**The repo-wide guard the risk register asked for now exists and passes.**
`AuraCopyTableGuardTests` drives off `AuraCopy.allKeys` — not a hand-listed set,
because a hand-maintained list is exactly what let the earlier gaps survive. It
fails on any key that falls through, any untranslated pair, and any stale entry in
the two-item identical-by-design allowlist (`app.name`, `confirmation.riskPrefix`).

Deliberately English and correct that way: `Text("AURA")`, and the language
picker's own `EN`/`TR` and `English`/`Türkçe` options.

**`accessibility_localization` is still REFUSED**, but on different grounds than
before: unreviewed translation, no live VoiceOver verification, and ADR-050 §4
reviewer independence. **Not on coverage.** Do not read "coverage closed" as
"sign-off available".

## What the next agent can still do alone

- **Not much on localization, and that is the point.** The guard proves the *table*
  is complete; it cannot prove every UI literal routes through the table, since a
  literal that never became a key is invisible to it. The clean sweep of
  `Text(`/`Button(`/`Label(`/`GroupBox(`/`LabeledContent(`/`Section(`/`Toggle(`/
  `SecureField(`/`TextField(` literals is a hand-verified snapshot, not an enforced
  invariant. Turning that sweep into a real source-scanning ratchet would be
  genuine, useful work.
- **`stt_partial`** — note the SP-016 probe (`scripts/run-sp016-speech-probe.sh`)
  measures **WER/quality**, not `first_stt_partial_ms`. Different metric. It closes
  SP-030's "STT/WER" procedure item, not this SLO.
- **The seven older evidence IDs with no files** (SP-000/001/003/010) — reportable,
  but do **not** reconstruct them. Inventing evidence for closed prompts is the
  failure mode the program exists to prevent.
- **F-002** is an accepted risk, not a closed one, and is reversible.

## Hard rules that were tested this session

- **Never record a result the evidence does not support.** Two governance claims
  this session were false in the direction of looking finished — a "clean" worktree
  that was dirty, and a `verified_head` asserting a verification that never ran.
  Both drifted that way by omission, not intent. Check the cheap invariants.
- **A measurement class is not decoration.** `deterministic_harness` may never be
  presented as `live_user_present`; the validator rejects it, and so should you.
- **Correct your own errors by appending, not editing.** Applies to inherited
  handoffs too: the previous starter's "3 pre-existing failures" was tested rather
  than obeyed, and the correction was appended.
- **An evidence ID is not evidence.** `EV-SP-030-20260830-A11Y-REMEDIATION-01` was
  cited in six files, including a full index row, but never written. Reconstructed
  and explicitly labelled non-contemporaneous. **Seven older SP-era IDs are still in
  this state** (`EV-SP-000-…-BASELINE-01`, `-DELIVERY-01`, `EV-SP-001-…-ATTEMPT-01`,
  `-CLOSEOUT-02`, `-CLOSEOUT-03`, `EV-SP-003-…-R2-DIALOGUE-TESTS-15`,
  `EV-SP-010-…-COMPOSITION-01`) — left alone on purpose, since reconstructing
  evidence for closed prompts would manufacture it. Pre-SP tracks never used
  standalone files at all. Cross-check IDs against `ls` before citing them.
- **A failed check that reports success is worse than no check.** The first count of
  the gap above said "the only one of 146" and was wrong: the pipeline used a
  `grep -oE` lookahead BSD grep does not support, fell through to a redirect that
  never wrote, and `comm` compared against an empty file. It printed a clean result.
  Assert on the intermediate (`wc -l`) before trusting a set difference.
- **Follow interpolations to their source.** Two accessibility sites look like gaps
  and are not — they interpolate already-localized values. A third was written down
  as safe for the same reason and was wrong: `AuraMenuView_Tabs.swift:524` feeds on
  seven hardcoded permission names and on `PermissionState.title`, which has no
  language parameter at all. Reading the `accessibilityLabel` line alone is a
  proximity heuristic in disguise.

## Environment traps

- **`swift build` and `./scripts/aura-test.sh` cannot run inside the Bash sandbox.**
  SwiftPM invokes `sandbox-exec` itself and the outer sandbox denies it
  (`sandbox_apply: Operation not permitted`). Run them with the sandbox disabled,
  and confirm `Done. Failed bundles: 0` **and** the counts — the wrapper can exit 0
  having run nothing. The same applies to the Python suite: inside the sandbox it
  reports a phantom third failure from `uv lock --check`.
- **`TEST_TARGETS` in that script is a hardcoded list.** Cross-check it against
  `ls Tests/` whenever a record cites a total. Both are currently 22 and agree.
- **`granite4.2:8b` does not load.** No first token within a 900-second warmup,
  twice, while `ollama ps` stayed empty. The daemon is healthy — a 1.3 GB model
  answered in ~1.2 s straight afterwards. Model-specific. If the product routes to
  an 8B-class local model, that model does not serve on this Mac.

## First action next session

Ask the owner which of the four blocked items they have completed (cross-review?
sign-off verdicts? translation check?), then pick up from there. If none, the
honest solo options are the repo-wide a11y ratchet and — only if the owner accepts
more unreviewed Turkish — `MemoryRowView` and `AuraSettingsView`.
