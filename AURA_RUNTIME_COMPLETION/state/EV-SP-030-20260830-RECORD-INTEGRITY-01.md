# EV-SP-030-20260830-RECORD-INTEGRITY-01

**Evidence ID:** EV-SP-030-20260830-RECORD-INTEGRITY-01
**Track:** SP-030 / R12 — governance record integrity
**Type:** Correction — three defects in the uncommitted SP-030 body of work
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty)
**Session:** AURA-SP-030-A11Y-PLUMBING-20260830

## Why this record exists

`NEXT_SESSION_STARTER.md` stated: *"Python suite has 3 pre-existing failures
unrelated to this work — proven by stashing only these changes and re-running.
Do not 'fix' them as if they were new."* That instruction was tested rather than
obeyed, and it was wrong. Recording the correction by appending, per the
program's own rule.

## Finding 1 — the failure count was 2, not 3, and one was an artifact

`python3 -m unittest discover -s scripts/tests` reports **three** failures when
run inside the agent's Bash sandbox and **two** when run with the sandbox
disabled. The third,
`test_validate_repo_hygiene_supply_chain.test_validator_passes_without_printing_secret_values`,
fails only on `uv lock --check failed with exit 2` — a blocked network/tool
access, not a repository defect. It is a **measurement artifact of the harness**
and should never have been counted as a repository failure.

## Finding 2 — both remaining failures were regressions from this work, not pre-existing

Each was checked against `HEAD` (`8b16142`) rather than assumed.

**(a) `test_current_repository_state_is_valid` — schema violation.**
`current-state.json` `$.active_prompt.step` was **521 characters** against a
schema `maxLength` of **500**. At `HEAD` the same field is 405 characters and
valid. The overlong string was written by the uncommitted work.
*Fixed:* rewritten to 492 characters with no loss of substance.

**(b) `test_state_and_handoff_are_locked_to_first_uncompleted_prompt` — an
internally inconsistent status.** The record asserted three different things
about the same prompt at once: `SECOND_PASS_STATE.json` had
`active_state: "in_progress"` while `blocked_prompts: ["SP-030"]`;
`current-state.json` and `session-handoff.json` said
`"SP-030 BLOCKED/IN_PROGRESS"`; `ACTIVE_CONTEXT.md` carried a heading reading
`` `SP-030` / `in_progress` / **BLOCKED** ``. At `HEAD`, `blocked_prompts` is `[]`,
so the inconsistency was introduced here.

*Resolved as `blocked`,* on the contract's own definition:
`SECOND_PASS_CONTROL_CONTRACT.md` — *"A blocked prompt has an explicit blocker and
remains the active prompt."* SP-030 has four explicit blockers that no agent can
clear and remains the active prompt. The alternative reading — emptying
`blocked_prompts` to match `in_progress` — would have **hidden** the blocker, so
it was rejected. `blocked` is what the record already asserted in three of four
places; only `active_state` disagreed.

Synchronized accordingly: `SECOND_PASS_STATE.json.active_state`,
`session-handoff.json.active_prompt.state`,
`current-state.json.active_prompt.state`, and both `ACTIVE_CONTEXT.md` overlay
headings. `program_status` was left at `in_progress` — no invariant constrains
it, and changing it is the owner's call, not a repair.

## Finding 3 — `validate_runtime_completion.py` was failing, and two further claims were false

Fixing (a) and (b) let the validator run past its first error and expose two more:

- **`working_tree_state: "clean"` with 44 dirty files.** The last commit is
  literally titled *"mark working tree clean at 60212ce"*; the session then
  dirtied 44 files without updating the claim. *Fixed:* set to `dirty_expected`
  with six entries in `user_owned_changes` describing the actual groups, as the
  validator requires.
- **`verified_head` asserted a verification that never happened.** It had been
  advanced to `8b16142`, while `capability-matrix.json` still records
  `9e1c756`. At `HEAD` both are `9e1c756`; commit `60212ce` had deliberately
  *reconciled* `verified_head` down to it, and the uncommitted work undid that.
  The two intervening commits are documentation-only, so no capability was
  re-verified. *Fixed by restoring `verified_head` to `9e1c756`* rather than
  bumping the matrix — bumping it would have fabricated a verification.

## Finding 4 — an evidence ID with no evidence behind it

`EV-SP-030-20260830-A11Y-REMEDIATION-01` was cited in six governance files,
including a full `EVIDENCE_INDEX.md` row, but the file was never written.
*Fixed:* reconstructed, explicitly labelled non-contemporaneous, re-verifying each
claim against the tree — except the `89` test baseline, marked as carried forward
on trust.

**A first pass at this finding claimed it was "the only one of 146 cited IDs with
no file". That was wrong, and it is corrected here before publication.** The check
behind it used a shell pipeline whose `ls | grep -oE` branch failed silently
(BSD grep has no lookahead) and fell through to a redirect that never wrote its
output, so `comm` compared against an empty file and the result looked clean. A
failed check that reports success is worse than no check. Re-run properly:

Of the 134 standalone evidence files in `AURA_RUNTIME_COMPLETION/state/`, **eight** SP-era cited IDs had no file behind them. This was the only one belonging to the active prompt; the other seven — `EV-SP-000-…-BASELINE-01`, `EV-SP-000-…-DELIVERY-01`, `EV-SP-001-…-ATTEMPT-01`, `EV-SP-001-…-CLOSEOUT-02`, `EV-SP-001-…-CLOSEOUT-03`, `EV-SP-003-…-R2-DIALOGUE-TESTS-15`, `EV-SP-010-…-COMPOSITION-01` — are older and remain open. Pre-SP tracks (R0–R12, REPO-HYGIENE, BOOTSTRAP) never used standalone files at all; their evidence lives only as index rows. The per-ID file is therefore an **SP-era** convention, not a universal one.

The seven older gaps are **not** repaired here. They belong to closed prompts, and
inventing reconstructions for them would manufacture evidence — the exact failure
mode this record exists to name. They are reported so a future session can decide.

## Verification after the fixes

| Check | Result |
|---|---|
| `scripts/validate_second_pass_program.py` | exit 0 |
| `scripts/validate_runtime_completion.py` | exit 0 (was failing) |
| `scripts/validate_beta_readiness.py --record …/beta-readiness.json` | exit 0 |
| `python3 -m unittest discover -s scripts/tests` | **58 tests, OK, 0 failures** |
| `./scripts/aura-test.sh` | 1302 tests / 83 suites / 22 bundles, 0 failures |

A full schema sweep of `current-state.json`, `session-handoff.json`,
`SECOND_PASS_STATE.json` and `beta-readiness.json` against their schemas now
reports no `maxLength` or `enum` violation in any of the four.

## What this does NOT change

No SLO was measured, no scenario was re-run, no sign-off was obtained, and no
gate moved. SP-030's four human-dependent blockers are untouched. This record
corrects the accuracy of the governance record only.

## Falsifiers

Any claim that these were pre-existing failures; that the Python suite still has
known failures; that `verified_head` reflects a re-verified capability matrix;
that the reconstructed evidence file is contemporaneous; or that any SP-030 gate
advanced as a result of this work, would falsify this record.
