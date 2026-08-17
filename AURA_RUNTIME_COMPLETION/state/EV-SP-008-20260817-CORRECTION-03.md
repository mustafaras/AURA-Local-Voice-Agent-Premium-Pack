# Evidence: EV-SP-008-20260817-CORRECTION-03

## Identity

- **Evidence ID:** EV-SP-008-20260817-CORRECTION-03
- **Prompt:** SP-008 — Computer-Use Adversarial Safety (post-closure re-verification
  requested by the user: "sp 0008 tam ve kusursuz şekilde tamamlandı mı")
- **Gap:** OPEN-05 (R4) — record accuracy of the SP-008 closure, not its technical scope
- **Timestamp:** 2026-08-17T08:15:11Z
- **Branch:** `main`
- **Commit at audit time:** `0000b4afae1dc1bc748f7cf1f4ae22a00916e592` (== `origin/main`)
- **Session:** AURA-SP-008-CORRECTION-20260817

## Authority

Edit-only for the audit itself. The user then granted an explicit in-turn
go-ahead ("onaylıyorum ve bu açıkları da kapatalım") to correct the findings and
to commit and push. Nothing else was authorized or exercised: no install, launch,
TCC mutation, provider contact, beta enrollment, signing, notarization, release,
or deployment.

## Environment

- macOS 27.0, Apple Silicon
- Apple Swift 6.4 (swiftlang-6.4.0.30.4), target `arm64-apple-macosx27.0.0`
- Test runner `./scripts/aura-test.sh` (canonical wrapper)

## 1. What was re-verified, independently of the SP-008 records

Every SP-008 claim was re-derived from the tree rather than read off the ledgers.

| Check | Command | Result |
|---|---|---|
| Full regression, fresh build path | `./scripts/aura-test.sh /tmp/aurabuild-verify-sp008` | **21/21 bundles, 931/931 tests, 0 failed** — bundle and test totals recomputed from the log, not read off a summary line; log SHA-256 `8106da00c089711b08626a4b5c42c29d32b3f7ad62b9c94e7bfe171d9982dec2` |
| Declared test targets | `grep -c testTarget Package.swift` | 21 — matches the 21 bundles, so none was skipped |
| Product build | `swift build --product AURA` | Clean |
| Four governance validators | `validate_second_pass_program.py`, `validate_runtime_completion.py`, `validate_repo_hygiene_program.py`, `validate_repo_hygiene_supply_chain.py` | all exit 0 |
| Governance unit tests | `python3 -m unittest discover -s scripts/tests` | 38/38 OK |
| Whitespace / secrets | `git diff --check`; pattern scan of the new test file and both evidence files | clean; no secrets, tokens, account data or unredacted model output |
| Commit pointers | `git rev-parse origin/main HEAD` vs `verified_head`, `remote_head`, `capability-matrix.repository_commit` | all four equal `0000b4a` |
| Source claims | direct read of each changed file | `.terminal(.secureFieldBlocked)` in `ComputerUseControlLoop_Run.swift`; required `secureFieldDetector` refusing every input-generating kind with `.wait` exempt in `UIActionExecuting.swift`; `exclusionReason(for:)` as single source of truth plus `windowNotVisible` in `ScreenContextEngine.swift`; `liveValidatedProduction` naming exactly three apps — all confirmed |
| Outcome-enum exhaustiveness | both `switch` sites over `ComputerUseLoopOutcome` | exhaustive, no `default:` — the new terminal case cannot be silently absorbed by an existing branch |

**SP-008's technical work stands.** Its adversarial and recovery closure at the
deterministic boundary is confirmed by re-execution, not by assertion.

## 2. Defect A — the new-test count is wrong in every record

- **Observed:** the SP-008 records state "22 tests" for
  `Tests/AuraComputerUseTests/R4AdversarialSafetyTests.swift` and
  "`AuraComputerUseTests` 93/93, up from 71".
- **Actual:** the file declares **25** `@Test` functions. At `0000b4a` the bundle
  had **68** tests (`ComputerUseControlLoopTests` 8, `_MoreTests` 10,
  `ComputerUseTypesTests` 15, `EmergencyStopControllerTests` 4,
  `R4ProductizationTests` 27, `UIActionExecutingTests` 4). 68 + 25 = 93, which is
  the number the runner actually reports.
- **Mechanism:** the "22" was taken from the evidence file's own case table, which
  lists cases by procedure step and folds several tests into one row; "71" was then
  back-derived so that 71 + 22 would reach the observed 93. Two errors that cancel
  in the total are exactly the kind a summary line hides — which is why the totals
  in §1 were recomputed from the log rather than trusted.
- **Impact:** documentation accuracy only. No test was missing, skipped or
  miscounted by the runner; the 93/93 and 931/931 figures were always correct.
- **Corrected in:** `EV-SP-008-20260817-ADVERSARIAL-01.md`, `EVIDENCE_INDEX.md`,
  `SECOND_PASS_OPEN_GAPS.md`, `ACTIVE_CONTEXT.md`, `NEXT_SESSION_STARTER.md`,
  `session-handoff.json`, `current-state.json`, `SECOND_PASS_STATE.json`. The three
  ledgers are append-only, so their SP-008 entries keep their original wording and
  are corrected by new entries pointing at this evidence ID.

## 3. Defect B — `session-handoff.json` named SP-009 but pointed at SP-008's file

- **Observed:** `active_prompt.id` was advanced to `SP-009` while
  `active_prompt.file` still read
  `AURA_RUNTIME_COMPLETION/prompts/second_pass/SP-008_COMPUTER_USE_ADVERSARIAL_SAFETY.prompt.md`.
- **Mechanism:** the closeout advanced the id and the step text but not the path;
  no validator cross-checks `file` against `id` (`validate_second_pass_program.py`
  compares only `id` and `state` against `SECOND_PASS_STATE.json`), so it passed.
- **Impact:** a fresh session opening the handoff's `file` would read SP-008's
  prompt while believing it was opening SP-009.
- **Corrected:** `file` now names
  `AURA_RUNTIME_COMPLETION/prompts/second_pass/SP-009_SAFARI_EXTENSION_PACKAGING_AND_AUTHENTICATION.prompt.md`.

### Not a defect — the `active_prompt` / `active_state` pairing

`SECOND_PASS_STATE.json` pairs `active_prompt: SP-009` with
`active_state: completed`, which reads as "SP-009 is completed". It is not: the
convention — documented at `ACTIVE_CONTEXT.md` and enforced by
`validate_second_pass_program.py`, which requires `active_prompt` to be the first
**uncompleted** prompt and requires the handoff and the overlay to match it — is
that `active_prompt` is the *next* prompt and `active_state` is the state of the
prompt just closed. `completed_prompts` is the authoritative guard. This was
inherited from every prior session and is left unchanged; changing it would be a
program-wide convention change, which is outside this correction's scope.

## 4. Finding C — the guarded computer-use loop has no user-reachable route

Found while confirming that the new terminal outcome is handled everywhere it can
surface.

- **Observed:** `ComputerUseControlLoop.run` is invoked from exactly one place,
  `AuraKernel.computerUseRun(appBundleIdentifier:objective:)`
  (`Sources/AURA/AuraKernel_RuntimeAPI.swift`). That function has **no caller** —
  not in `Sources`, not in `Tests`. `IntentKind` has no computer-use case and
  `ToolRouter` has no computer-use branch, so no utterance can reach it either.
  The `computerUse.run` capability manifest and the policy capability both exist.
- **Consequence:** SP-008's guards are correct and regression-covered, but in the
  shipped product nothing can currently drive the loop they protect. This is also
  the deeper form of the residual SP-007 already recorded ("the live tests used
  AppleScript/System Events as the executor, not the app's own
  `ComputerUseControlLoop.run` path") — that path is not merely unexercised live,
  it is unreachable.
- **Not fixed here, deliberately.** Adding an `IntentKind` case and a router
  branch is product wiring for R4 productization / NL reachability, not an
  adversarial-safety residual; SP-008's hard boundary forbids absorbing another
  prompt's objective. Recorded as `RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE`
  (Open) in `RISK_REGISTER.md` and in OPEN-05's gap section.

## 5. Verification after the corrections

All checks in §1 were re-run after the edits; the corrections touch documentation,
state projections and the risk register only — no source or test file was modified
by this pass.

| Check | Result |
|---|---|
| `swift build --product AURA` | Clean |
| `./scripts/aura-test.sh` full sweep | 21/21 bundles, 931/931 tests, 0 failed |
| Four governance validators | exit 0 |
| Governance unit tests | 38/38 OK |
| `git diff --check` | clean |

## 6. Falsification

This conclusion is falsified by any of:

- a `grep -c '@Test' Tests/AuraComputerUseTests/R4AdversarialSafetyTests.swift`
  that does not return 25 while the bundle reports 93;
- a bundle total other than 93 for `AuraComputerUseTests`, or a program total
  other than 931, on a clean re-run at this tree;
- any caller of `AuraKernel.computerUseRun` appearing without
  `RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE` being closed with live evidence;
- `session-handoff.json` naming an `active_prompt.file` that is not the file of
  its own `active_prompt.id`.

## 7. Residual risk

- `RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE` (new, Open) — see §4.
- `RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL` and
  `RISK-SP-008-PLANNER-DECLARED-INTENT-TRUST` carry forward unchanged; this pass
  neither closes nor weakens them.
- Forwarded unchanged: `RISK-SP-006-URL-OPEN-FAILS-LIVE`,
  `RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED`,
  `RISK-INJECTION-COVERAGE-NON-DIALOGUE`, `RISK-SP-004-TOCTOU-RACE`,
  `RISK-SP-004-HANDLER-COMPROMISE`, `RISK-SP-003-MODEL-LATENCY`,
  `RISK-SP-003-LIVE-VOICE-RESIDUAL`, `RISK-STT-MIC-NOT-CAPTURING`.

## 8. Limitations

- Documentation, state-projection and risk-register scope only. No production or
  test source was changed by this pass, so SP-008's evidence class is unchanged:
  still deterministic, still not live.
- The count correction was verified by static declaration count (`@Test`
  functions) cross-checked against the runner's bundle total. No parameterized
  `@Test(arguments:)` case exists in the file, so the two agree exactly.
- SP-008's delivery commit is made under this evidence ID; the state projections
  are aligned to it in a following commit, per the program's established pattern.
