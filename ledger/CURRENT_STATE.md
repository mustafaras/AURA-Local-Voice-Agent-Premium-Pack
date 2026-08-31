# Current State

This file is a compact, atomically replaced projection of the append-only ledger.
Projection refreshed from live repository and command evidence on 2026-08-30.

## Authoritative current status — 2026-08-30T20:30:00Z (SP-030 `blocked`)

The active second-pass prompt is **`SP-030` / `blocked`** (beta
SLOs, scenarios, incidents, sign-offs, R12) under
`EV-SP-030-20260830-PROGRAM-BLOCKED-01`. Its completion gate — mandatory SLOs and
scenarios pass, incidents remediated, and independent sign-offs complete — cannot
be honestly met this pass: no enrolled/consented beta cohort, no enabled
content-free measurement/transport (engine default-off, `transport: none`), no
independent evaluator, and the R11 dependency is `in_progress`. `beta-readiness.json`
stays `blocked`; no SLO/scenario/incident/sign-off/telemetry/cohort/consent/RC
evidence was produced or fabricated. **SP-031 must NOT start** until owner-authorized
R11 completion + a real consented beta window + independent evaluation occur and
SP-030 is re-run. Verified live `HEAD == origin/main == 8b16142`; the **worktree is
dirty by design** (29 modified + 20 untracked), declared as `dirty_expected` with
its change groups in `current-state.json` `repository.user_owned_changes` — the
owner has not asked for a commit. All **three** validators exit 0:
`validate_second_pass_program.py`, `validate_runtime_completion.py` (which was
failing until `EV-SP-030-20260830-RECORD-INTEGRITY-01`), and
`validate_beta_readiness.py` ("valid and blocked"). Swift suite 1302 tests /
83 suites / 22 bundles, 0 failures; Python suite 58 tests, OK.
Mandatory closeout: `EV-SP-030-20260830-CLOSEOUT-01`.

**Status reconciled 2026-08-30** (`EV-SP-030-20260830-RECORD-INTEGRITY-01`): the
record previously asserted `in_progress`, `blocked_prompts: ["SP-030"]`, and
"BLOCKED/IN_PROGRESS" simultaneously. Resolved to `blocked` on the control
contract's definition — a blocked prompt has an explicit blocker and remains the
active prompt. Emptying `blocked_prompts` was rejected because it would hide the
blocker. The plumbing refactor is closed
(`EV-SP-030-20260830-A11Y-COVERAGE-02`), which surfaced that the confirmation
card — including the Deny and Allow Once buttons — was hardcoded English; it is
now localized. `accessibility_localization` remains **REFUSED**.

SP-029 is `completed` for its beta scope/consent/privacy/telemetry/kill-switch
contract scope. SP-028 is `completed` for the updater, lifecycle, recovery,
migration slice of OPEN-12 under
`EV-SP-028-20260829-LIFECYCLE-IMPLEMENTATION-01`,
`EV-SP-028-20260829-RUNTIME-API-02`, and `EV-SP-028-20260829-CLOSEOUT-03`.

**`SP-029` was `completed` for OPEN-13 (R12):** The beta scope/consent/privacy/
telemetry/kill-switch contract is defined in `EV-SP-029-20260829-BETA-CONTRACT-BLOCKED-01`
for an internal local-machine-only closed beta: supported macOS/Swift/Xcode
profiles, capability inclusion/exclusion, privacy notice, explicit opt-in, consent
withdrawal, retention/access/deletion rights, content-free aggregate telemetry
schema (event-class counts, latency histograms, error-code tallies — no transcript,
audio, screenshot, or content), kill switch, telemetry-off mode, rollback, and
incident containment. The release owner approved the contract
(`EV-SP-029-20260830-OWNER-APPROVAL-01`). The in-scope content-free aggregate
engine with no transport was implemented (`EV-SP-029-20260830-TELEMETRY-AGGREGATOR-01`)
and is dormant by default. Closeout recorded at `EV-SP-029-20260830-CLOSEOUT-01`.
The fail-closed `AURA_RUNTIME_COMPLETION/state/beta-readiness.json` contract was
validated and remains `blocked` (`authority.beta_enrollment: false`,
`telemetry.enabled: false`, `cohort.status: not_enrolled`, all signoffs
`not_obtained`, release_candidate `blocked`/`approved: false`). No telemetry was
transmitted, no cohort enrolled, no participant consent collected, no SLO measured,
no RC approved. The R12 direct-evidence gates still open (live SLO/scenario/incident
results, independent sign-offs) are owned by **SP-030**; the signed RC artifact +
ADR-047 are owned by **SP-031**. All control-plane projections were synchronized to
reflect SP-029 completed and SP-030 pending.

**`SP-028` is `completed`** for the local source/build/test/contract scope:
new `AuraLifecycle` library target with `ServiceManagement` linker dependency;
12 `Sources/AuraLifecycle/` files; 39 deterministic tests; full suite 89 tests in
16 suites pass; second-pass, runtime-completion, beta-readiness, repo-hygiene,
and supply-chain validators PASSED.

**`SP-027` is `completed`** for the local-only scope under
`EV-SP-027-20260828-LOCAL-ONLY-SCOPE-03`,
`EV-SP-027-20260828-SIGNING-PROCEDURE-02`, and
`EV-SP-027-20260828-LOCAL-LAUNCH-04` at `main` `37805cb0`: release owner decided
external distribution is out of scope; local nested signing + hardened runtime
passed; local launch smoke alive after 12s in an isolated `CFFIXED_USER_HOME`;
artifact hashes recorded. `RISK-NOT-NOTARIZED` accepted for the local-only scope.
No Developer ID, notarization, or clean-machine claim is made.

Release/deploy remains blocked on external distribution (local-only scope
accepted under SP-027). OPEN-12 R11 live slices (ServiceManagement login-item
enablement, real update download, clean-machine recovery, actual reset/uninstall/
factory-reset execution, ADR-046 operational acceptance) remain `in_progress` and
are not claimed by SP-028. OPEN-13 R12 RC gates (SLOs, scenarios, incidents,
independent sign-offs, signed RC artifact, ADR-047) remain open and are owned by
SP-030 and SP-031.

**R11 dependency planning (2026-08-30):** Under the owner option-A grant
("a go be perfect and premium"), a decision-ready R11 closure plan
(`AURA_RUNTIME_COMPLETION/context/R11_CLOSURE_PLAN.md`;
`EV-SP-029-20260830-R11-CLOSURE-PLAN-01`) maps the remaining R11 gates into
locally-closable / external-Apple-prerequisite-and-local-only-out-of-scope /
owner-decision buckets and reconciles the stale authority drift in
`current-state.json` (edit/test/state + launch + commit/push/merge true;
TCC/signing/release/telemetry/model/dependency/provider false). R11 remains
`in_progress`; the artifact stays `development_unverified`; `beta-readiness.json`
stays `blocked`; ADR-046 local-only acceptance is recommended but not formalized.

**`HEAD == origin/main == 37805cb0`** (working tree dirty with uncommitted
SP-028/SP-029 lifecycle/beta-contract evidence + control-plane projections).

**Next safe action:** SP-029 is completed. Open SP-030 (beta SLOs/scenarios/
incidents/sign-offs) under its own authority and read order; do not auto-execute it.
Fail-closed `beta-readiness.json` stays blocked until SP-030/SP-031 close the R12
direct-evidence gates.

## Verification correction — 2026-08-24T08:01:03Z

The SP-018 product commit remains `1d3efca0944334be19a2d68abbb4c199bba15d87`;
current `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`.
An independent default-runner recheck exposed
a scheduling-dependent `AuraAgentTests` failure under unrestricted Swift
Testing parallelism; the defect was in the test-runner boundary, not in the
SP-018 production reference-wiring path. `scripts/aura-test.sh` now bounds only
that bundle to one worker by default, with regression evidence under
`EV-SP-018-20260824-TEST-RUNNER-FIX-06`. The corrected 237-test bundle and
default 21-bundle matrix pass. The worktree intentionally contains uncommitted
verification/docs/ledger changes; no SP-019 implementation or delivery action
was performed.

## SP-018 / OPEN-09 — 2026-08-23T17:14:04Z — completed and delivered

SP-018 completed its bounded local production-reference-wiring gate. The real
`AuraKernel` composition now supplies typed active application/editor/workspace,
durable-task, and backend snapshots through `IntentEngine` into
`ContextBuilder`/`ReferenceResolver`; bounded dialogue and recent file/tool
salience is scope/expiry/authority filtered, deduplicated, and hard-bounded.
Safe resolved references bind only to closed typed slots, while missing,
ambiguous, stale, out-of-scope, or weak destructive references clarify before
routing. Evidence: `EV-SP-018-20260823-PRODUCTION-REFERENCE-WIRING-01`,
`EV-SP-018-20260823-FOCUSED-TESTS-02`,
`EV-SP-018-20260823-FULL-SUITE-03`, and
`EV-SP-018-20260823-GOVERNANCE-CLOSEOUT-04`.

Focused Context/Intent suites passed 37/37 and 132/132; the full regression
passed 21/21 bundles with exit 0; build, diff, second-pass, and governance
checks passed. R8 remains in progress: user-present restart/control, R9 UI,
remote/provider evidence, and ADR-043 remain open. `SP-019` is pending and
must start only under its own authority/read order; no SP-019 work occurred.
The SP-018 changes were committed as `1d3efca0944334be19a2d68abbb4c199bba15d87`
and pushed to `origin/main`; local and remote heads match and the worktree is
clean. No PR exists for `main`, so merge was not applicable. The local builder
produced only a validated `development_unverified` artifact; no production
deploy, signing, notarization, install, publish, or release action occurred.

## Delivery reconciliation — 2026-08-23T17:14:04Z

`EV-SP-018-20260823-DELIVERY-05` records the explicit current-turn delivery:
commit and push passed, `git ls-remote` confirmed `HEAD == origin/main`, and
`gh pr list --state open --head main` returned no PR. The repository's release
builder produced and validated the unsigned/unnotarized development artifact
at `/tmp/aura-sp018-delivery.PrUGnw/output/`; this is not deployment evidence.

## Delivery reconciliation — 2026-08-23T14:37:07Z

SP-017 / OPEN-08 is completed under the truthful PTT + system-TTS-only branch and
its product changes were committed as `4b33dc2365ea45a9c0547805d21190e24265f2c5`
and pushed to `origin/main`. No PR exists for `main`, so a separate merge was
not applicable. The repository's release builder produced and validated only a
`development_unverified` artifact; no signing, notarization, install, publish,
or production deploy occurred. CI run `32645953213` is queued and is not deploy
evidence. SP-018 remains pending/unopened and the broader program remains in
progress.

## Authoritative current status — 2026-08-23T14:16:40Z

The active second-pass prompt is **`SP-018` / `pending`**. **SP-017 / OPEN-08
is `completed`** at `main`, with product content delivered in commit
`4b33dc2365ea45a9c0547805d21190e24265f2c5` and pushed to `origin/main`.

**SP-017 completion (`EV-SP-017-20260823-CLOSEOUT-03`):** direct live system
TTS passed 14/14, with first chunk latency 0.733 s and full utterance latency
1.400 s; interruption/barge-in, pause/resume, stop, and anti-trigger lifecycle
tests passed. The release default is now `TTSAdapterChain() == ["system"]`.
The 16 GiB resource observation recorded an AURA final sample near 27 MiB RSS
and an earlier CPU Chatterbox helper sample near 3991 MiB; neural co-residency,
MPS/CPU neural quality, human listening, wake word, passive listening, energy /
thermal qualification, and physical speaker-to-microphone echo are therefore
explicitly outside this release scope rather than claimed as passed.

ADR-042 is **Accepted for the bounded PTT + system-TTS-only release** with
alternatives, scope, consequences, expiry/revisit, and evidence. The R7 track
and overall program remain `in_progress` because their broader residual risks
and other tracks are not closed. No commit, push, merge, release, deploy,
signing, install, download, provider, telemetry, beta, or TCC action was
performed. **SP-018 is safe to start but remains pending/unopened.**

## Authoritative current status — 2026-08-22T18:20:00Z

The active second-pass prompt is **`SP-016` / `in_progress`** at `main`, `HEAD ==
origin/main == 94ee2be355046cab97189764e2a9dfb4f7efd57a` (SP-015), with an expected
dirty worktree adding two intended product/test edits (STTPipeline turn-end metric
+ SP016 test) and the SP-016 control-plane projections.

**SP-016 deterministic metric/fail-closed slice (EV-SP-016-20260822-TURN-END-METRIC-01):**
added `STTPipeline.Metrics.turnEndLatencySeconds` (the R7-required turn-end
latency, activation→first-stable elapsed time, reset to 0 per turn) and a new
deterministic suite (`Tests/AURAIntegrationTests/SP016TurnEndLatencyTests.swift`,
3 tests) proving the metric, its cross-turn reset, and the fail-closed invariant
that non-stable/error transcripts are never promoted to a stable (command-eligible)
segment. `swift test --filter SP016TurnEndLatencyTests` → 3/3 PASS; AuraSTTTests
19/19; AuraAudioTests 35/35; AURAIntegrationTests 78/78;
`validate_second_pass_program.py` PASSED. **A computer-use live read-only
observation** (`EV-SP-016-20260822-LIVE-STATE-OBSERVATION-02`) confirmed the
running app's truthful live health: Microphone+Speech Granted, stt/audio ready,
voice-resources ready (16384 MB), tts ready (Yelda fallback), wake-word
unsupported (Push-to-Talk only); status `Idle — use Push to Talk`.

**SP-016 completion gate NOT MET:** the live bilingual WER/entity corpus and the
hardware recovery matrix (barge-in/echo/device/sleep/TCC/helper-crash) require a
speech-capable operator and were not exercised (the user is speech-disabled; no
speech-capable operator was present; no TCC mutation performed). **SP-016 remains
`in_progress`; SP-017 must NOT start.** No
commit/push/merge was performed (authority `commit:false`).

## Authoritative current status — 2026-08-22T17:30:00Z (historical: SP-015 completed)

The active second-pass prompt was **`SP-016` / `pending`** at `main`, `HEAD ==
origin/main == 389ea344652d3d1d8211e6ce244f909eff42bc6e` (SP-014 merge and its
pointer fix), with an expected dirty worktree adding the SP-015 control-plane
changes (inventory, evidence, state, and ledger projections).

**SP-015 wake-word decision COMPLETED (EV-SP-015-20260822-WAKE-EXCLUSION-01):**
wake word is **explicitly excluded from the release scope** (SP-015 Procedure
step 3). No licensed local candidate is provisioned or bundled (new inventory
`AURA_RUNTIME_COMPLETION/context/WAKE_MODEL_INVENTORY.md` records zero
candidates); the active authority forbids `download_models`/`install_dependencies`,
so qualification is not lawfully possible in this pass. Production remains
Push-to-Talk-only through `DisabledWakeWordDetector`; `MarkerWakeWordDetector` is
test-only (ADR-003). The truthful UI already states "no acoustic model is
installed; Push to Talk remains available" (onboarding stage `.wakeWord`, menu
"Activation: Push to Talk", runtime warning). No `ADR-042` file exists anywhere
(decision register path absent) — reconciled as a projection gap; ADR-042 stays
`Proposed`.

`validate_second_pass_program.py` PASSED; `AuraAudioTests` 35/35 (includes
`disabledWakeDetectorNeverClaimsProductionActivation`), 0 failed bundles.
**SP-015 is `completed`; SP-016 (bilingual STT quality and voice recovery) is
safe to start.** No
commit/push/merge was performed (authority `commit:false`).

## Authoritative current status — 2026-08-21T16:40:00Z (historical: SP-014 blocked)

The active second-pass prompt was **`SP-014` / `blocked`** at `main`, `HEAD ==
origin/main == 1d12c91` (merge of SP-012 + SP-013), with an expected dirty
worktree that adds only `Tests/AuraAgentTests/SP014LiveAcceptanceTests.swift`.

**SP-014 live acceptance attempt (EV-SP-014-20260821-LIVE-ACCEPTANCE-BLOCKED-01):**
the ten-step R6 user-present acceptance was run against the approved scratch repo
`~/.aura-sp014/approved-repo`. **P2 (write-capable with no diff fails closed via
`verifyCompletion`; worktree cleaned), P3 (disabled backend reports `.unavailable`
+ quota, never a false `.ready`), and P4 (no commit/push/merge/PR; HEAD unchanged)
PASS. P1 (read-only live claude turn) FAILS** because no backend can currently
produce a genuine model turn: `claude -p` returns the session limit (resets 8:50pm
Europe/Istanbul) and `--permission-mode dontAsk` blocks Write/Bash by design;
codex default `gpt-5.6-luna` needs a newer CLI and `gpt-5.1-codex` is rejected for
a ChatGPT account; copilot quota exhausted. The suite fails closed (`.failed`), it
does not fabricate a `.completed`. **SP-014 completion gate NOT met; SP-014 is
`blocked`; SP-015 must NOT be opened** until a working backend account lets P1/P2
run green. No commit/push/merge was performed (authority `commit:false`).

## Authoritative current status — 2026-08-20T11:03:26Z

Repository hygiene H-010 is terminally complete. The verified non-projection
control-plane baseline is `main` /
`bdedcb7c809087aaeaa572f862ae0d3edbcf229e`; later descendants are
projection-only delivery commits.
The hosted workflow/source evidence was executed on
`6d4d6da382cd94cd3ac006e26e6f0502eacb9ea8`; descendants after that SHA are
control-plane-only projection commits. H-010 state is `completed`, all H-000
through H-010 prompts are complete, and no H-011 exists. Earlier blocked H-010
paragraphs below are historical snapshots and do not override the machine state
or this terminal closure. Product, beta, signing, release, deployment, live,
ADR-034/044, and FINAL gates remain separate.

The terminal H-000…H-010 prompt definitions are archived under
`AURA_RUNTIME_COMPLETION/archive/repo-hygiene/2026-08-12/`; the hygiene prompt
manifest remains their canonical locator. The archive/cleanup delivery is
merged by PR #3; SP-000 state/validator delivery is merged to `main`. Main CI
run `31613321170` is a historical queued observation; no repository-defined
signed/notarized/public deployment target exists.

The active second-pass prompt is `SP-012` / `in_progress` / `blocked` at `main`
with `HEAD == origin/main == bdedcb7c809087aaeaa572f862ae0d3edbcf229e` and an
expected dirty SP-012 worktree. SP-011 was completed under
`EV-SP-011-20260820-CALENDAR-IDENTITY-AND-FREE-WINDOW-13`; the owed free-window
non-empty read passed live once AURA was launched through LaunchServices and
held its own Calendar grant. SP-011 fixtures were removed.

Under `EV-SP-012-20260820-DETERMINISTIC-BRIDGE-01`, SP-012's deterministic
source-side passed: the local VS Code file bridge was replaced with an
authenticated extension transport. A `VSCodeBridgeSecretStore` (`SecretStoring`
over the macOS Keychain) holds a user-controlled symmetric HMAC secret. The
companion `AuraVSCodeExtension/` TypeScript package uses VS Code `SecretStorage`
and Node `crypto` HMAC-SHA256 and emits signed envelopes binding extension
identity, protocol version, nonce, freshness, workspace, actor, and payload.
`AuraKernel` wires the bridge with `requireAuthentication: true`, derives VS Code
capability availability from live bridge health, and keeps VS Code capabilities
disabled until health reports `.ready`. `VSCodeAdapter` awaits `PolicyEngine`
authorization and fails closed for missing/denied/confirmation-required
decisions. Failure-mode tests cover disconnect, version-mismatch, replay,
stale-editor, dirty-buffer, and confirmation denial. `swift test --filter
AuraVSCodeTests` passed 31/31; the full Swift suite passed 21/21 bundles;
`python3 scripts/validate_second_pass_program.py` PASSED; ADR-041 is accepted.

A follow-up (same day) packaged the companion extension as
`AuraVSCodeExtension/aura-vscode-extension-0.1.0.vsix` (SHA-256 `d7a9072e…`) and
added the previously-missing AURA user-controlled provisioning path: `AuraKernel`
now retains `VSCodeBridgeSecretStore` and exposes `provisionVSCodeBridge`,
`revokeVSCodeBridge`, and `vscodeBridgeProvisioned`, binding the extension ID to
the configured value and refreshing capability availability. `AuraVSCodeTests`
31/31 and `SP011LiveAcceptanceReadinessTests` 23/23 pass.

SP-012 is **not completed** because the live extension acceptance path is
unproven: the `.vsix` has not been installed in VS Code, the shared secret has
not been mirrored into VS Code `SecretStorage`, and no live authenticated round
trip has run. The next safe action is to install the `.vsix`, set the three
bridge paths, provision a shared secret through AURA and the extension command,
and capture live evidence before marking SP-012 completed.

**2026-08-21 update (EV-SP-012-20260821-LIVE-ACCEPTANCE-02):** the live
authenticated round trip is now proven. The companion extension `0.2.0` is
installed and live in VS Code 1.134, both halves are paired with a matching
shared secret, and an env-gated in-process Swift suite read the Keychain secret
(via the production `KeychainSecretStore`) and drove live `.editor` and
`.workspace` commands end to end — all passing, with the secret value never in
the agent context. Two live-path product defects were found and fixed (a
response-timing race in `VSCodeFileBridge.execute`, and a cross-language
optional-collection decode mismatch). `AuraVSCodeTests` 40/40,
`SP011LiveAcceptanceReadinessTests` 24/24, validator PASSED. The live
disconnect/version-mismatch/replay/stale-editor/dirty-buffer/confirmation and
revoke-to-fail-closed legs remain unobserved and each requires a user-present
re-pair, so SP-012 stays `in_progress`/`blocked` and SP-013 is not started.


## Canonical State Notice — 2026-08-09

The authoritative current state is
`AURA_RUNTIME_COMPLETION/state/current-state.json`, with live repository
`HEAD == origin/main == 6e53e6a941756e4b34f24f5de3c9c29bdc8147bf`; its
audited product/content baseline remains
`47775180c224f87fa5a58703f793515ffcb2c35c` under ADR-045. R2 through R12 remain
`in_progress` with deferred/live/manual/security/release/beta gates recorded in
`AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`. FINAL/CLOSEOUT is active by
explicit user request for a blocked acceptance audit and maintainer handoff;
it cannot claim release-candidate verification or release. The R11 local
`development_unverified` artifact, manifest, SBOM, checksum, and fail-closed
validator remain the only release evidence; CI artifact retention is configured
but unobserved. This legacy projection is retained for historical compatibility;
the machine-readable state remains authoritative.

## Historical verification snapshots

### Repository Hygiene Refresh — 2026-08-11 (superseded)

The superseded 2026-08-11 hygiene snapshot recorded `H-010` / `blocked` at
`HEAD == origin/main == 63f1e67bf1457e53d07cf282d8b4af1bcc33cba5`. User-controlled
Xcode 27.0 beta 5 provisioning succeeded; `xcodebuild`, SourceKit, strict
formatter/build, and the default 21-bundle/794-test/70.18% wrapper gate pass.
The wrapper now discovers the full-Xcode `MacOSX.platform` Testing runtime.
Full SwiftLint executes with SourceKit but exits 2 with 1,330 serious findings
across 628 files, so that historical snapshot remained blocked on bounded source/test lint
remediation. No H-011 exists and no product/release completion claim follows.
Evidence: `EV-REPO-HYGIENE-TOOLCHAIN-XCODE-20260811-01` and
`EV-REPO-HYGIENE-H-010-REVALIDATION-20260811-01`.

### Repository hygiene program overlay — historical chronology

The repository-hygiene audit is now encoded as the canonical plan
`docs/operations/REPO_HYGIENE_PROGRAM.md` and the synchronized H-000–H-010
control plane under `AURA_RUNTIME_COMPLETION/repo-hygiene/`. H-000 through
H-009 were complete for chain-order purposes at that snapshot; H-010 was then
active and `blocked`
after the final gate preserved explicit evidence-backed limitations. H-007's explicit host-boundary scope
measured 70.02% against the unchanged 70% line-coverage ratchet; raw all-source
coverage remains 65.15%. The verified H-008 feature commit was pushed and
merged to `main` at `47775180c224f87fa5a58703f793515ffcb2c35c`; the synchronized
state projection follows that delivery. The H-008 duplicate-backup quarantine
was recoverable and SHA-validated; no original Git object recovery mutation has
been performed. The H-005 delivery is now
merged and pushed at `3b1aa85f8c55e17b49c43daea008f98fd6515f15`, followed by
the synchronized state projection commit at live `HEAD == origin/main ==
6c4cc993f86c029ce754c5e540399beb781899bb`. The worktree is clean after the
H-008 duplicate-backup quarantine; the six byte-identical mode-600 copies are
preserved outside the repository at
`/Users/m_ras/Desktop/AURA-H008-QUARANTINE-20260810`. H-006 removed production
`try!`, `as!`, and direct `print()` matches, bounded the AX bridges, and made reviewed diagnostics
metadata-only/private;
`Runtime/chatterbox/.gitignore` remains the intended H-003 control-plane
configuration change. The original checkout's `git fsck` remains non-zero
(exit 8; 199 bad SHA-1 file entries, 8,909 dangling objects, and two invalid
`refs/.DS_Store` records), while the fresh remote clone's strict fsck exits 0
and its main reachable closure matches. H-004 established the active
macOS 27+/arm64/Swift 6.4/SDK 27 baseline, reconciled 21 Swift test targets,
removes stale active prompt-path guidance, and uses discovered/fail-closed
Swift Testing paths. H-005 strict production build and the canonical
21-bundle/794-test wrapper pass; configured recursive formatter lint now exits
0 after bounded remediation of 1,019 findings across 116 Swift files.
SwiftLint 0.65.0 is provisioned, but full SourceKit-backed lint remains
explicitly blocked by the active CLT-only developer directory; its no-SourceKit
fallback is partial and not a pass. H-005 was delivered at
`3b1aa85f8c55e17b49c43daea008f98fd6515f15`; H-006 is complete for chain
order and H-007 is complete for chain order; H-008 and H-009 are complete for
chain-order purposes; H-010's final gate ran the available checks and preserved
formal blockers. H-008's fail-closed current-tree
secret/dependency/workflow validator passes, and the full local matrix is
21/21 bundles and 794/794 tests. Evidence:
`EV-REPO-HYGIENE-H-005-20260810-02` and
`EV-REPO-HYGIENE-H-005-CLOSEOUT-20260810-02`,
`EV-REPO-HYGIENE-H-006-20260810-01`, and
`EV-REPO-HYGIENE-H-006-CLOSEOUT-20260810-01`, and
`EV-REPO-HYGIENE-H-007-20260810-01`, and
`EV-REPO-HYGIENE-H-008-20260810-01`, and
`EV-REPO-HYGIENE-H-009-20260810-01`, and
`EV-REPO-HYGIENE-H-010-20260810-01`.

Separate remediation evidence `EV-REPO-HYGIENE-REMEDIATION-20260810-01` records
the recoverable backup, independently verified clean clone, formatter/source
fix, provisioned scanners, exact false-positive policies, pre-commit/local
validation, and the remaining original-Git, full-Xcode/SourceKit, dependency,
and hosted-CI blockers. Follow-up evidence
`EV-REPO-HYGIENE-DEPENDENCY-REMEDIATION-20260811-01` closes the current
lock-graph dependency advisory risk: OSV and Grype are zero under the explicit
generated-environment boundary, and runtime/audio/helper checks pass. H-010
remains blocked only by full-Xcode/SourceKit and hosted-CI evidence; the
original `.git` was adopted from the fsck-clean candidate and its damaged
pre-adoption copy is preserved for rollback. This remediation does not create
or authorize H-011.

- R11 local artifact/manifest evidence `EV-R11-20260809-ARTIFACT-MANIFEST-01`
  remains valid: the reproducible ZIP is `development_unverified`, its recorded
  SHA-256 is
  `31073b4051d1ef1c8ca5761278370e353c030fc7d6e7d6add032c4a4ed3c5e22`, and
  focused/governance tests are green.
- The CI workflow statically parses and invokes the same fail-closed builder,
  then retains only the ZIP/manifest for 14 days. This configuration is not
  observed CI evidence until a real post-change run is inspected.
- No commit, push, merge, signing, notarization, installation, release, or
  deployment was performed for the R11 worktree.
- R12 transition and the blocked readiness contract are recorded as edit-only
  beta-readiness work. No cohort, telemetry, SLO, incident, independent
  sign-off, or release-candidate evidence exists; ADR-047 is absent.
- FINAL/CLOSEOUT reconciliation is recorded under
  `EV-FINAL-20260809-CLOSEOUT-BLOCKED-01` and
  `docs/operations/FINAL_OPERATIONAL_HANDOFF.md`; no release, beta enrollment,
  telemetry activation, signing, installation, commit, push, merge, or deploy
  was performed.

The older status sections below are historical and must not override the
canonical machine state.

## Historical Verification Snapshot — 2026-08-08

- R2/R3/R4 runtime and governance changes are present at live `daf062a`; the worktree is intentionally dirty; R5, R6, R7, R8, and R9 first-pass changes remain local and uncommitted. R5 full regression passed 21/21 bundles, 747/747 tests; R6 full regression passed 21/21 bundles, 751/751 tests, both with 0 failed bundles. R8 focused memory/context validation passed 30/30 and 33/33; full R8 regression passed 21/21 bundles and 782/782 tests with zero failed bundles, and governance passed. R9 `swift build --target AURA` passed; the direct R9 UI-state run passed 3/3.
- R2 bilingual NLU/dialogue implemented and system-tested but not formally closed (live hardware evidence pending).
- R3 capability registry/typed planner architectural core implemented and tested (ADR-038 accepted) but not complete.
- R4 computer-use productization deterministic core and registry wiring implemented and tested (ADR-039 accepted) but not complete (live beta-app evidence pending).
- R5 browser/mail/calendar/contacts adapters, R6 coding-agent routes, and R7 voice/resource governance remain open; **ADR-040 is Accepted**, while ADR-041, ADR-042, and ADR-043 remain Proposed. R8 memory/context is locally bounded and explainable, but production reference wiring, user-present controls, remote transport evidence, and live acceptance remain open.
- `swift-format`/full Xcode and release gates remain unavailable or open.

- Code revision `20571de` contains the verified sequential Swift test runner and serialized system-TTS latency suite.
- Full repository validation passes: 20 test bundles, 665 tests, 0 failed bundles. The release `AURA.app` bundle and PluginHost/AutomationHelper/ShellHelper payloads also build successfully under `/tmp/aura-app-after`.
- An unsigned AURA executable launched from a workspace-local bundle with an isolated `HOME` and stayed alive for the 12-second watchdog window without crash output. This is a bounded startup smoke only; it does not prove signing, TCC, GUI, microphone, Screen Recording, real wake-word, or release behavior.
- `git diff --check` and shell syntax checks pass. `swift-format` is unavailable on this host.
- R6's policy/bridge and typed-route slices remain source/build verified, with live extension/backend acceptance open. R8 focused evidence is recorded under `EV-R8-20260808-MEMORY-POLICY-01` and `EV-R8-20260808-CONTEXT-PRODUCT-02`; these are subsystem/integration evidence, not live product acceptance.
- Next safe action: perform user-present R9 VoiceOver/keyboard/localization/onboarding/manual acceptance and complete or explicitly scope remaining product-control gaps; keep R2-R8 open and stop before R10 until R9 is evidenced.

- Phase: Phase 25 adversarial safety harness and red-team evaluation suite is
  implemented, verified, and closed. Phase 24 layered configuration is
  committed and pushed at `HEAD == origin/main == ba9842f`.
  The 20-phase implementation roadmap (`prompts/implementation/00_00` through
  `20_20_RELEASE`) is complete; remaining work is release gates and optional
  master-prompt phases 26–30.
  ADR-034 (Accessibility/CLI privilege separation) is **In Progress**.
  Milestone 1 is complete: `AuraAutomationHelper` and `AuraShellHelper` sandboxed
  executables, shared `AuraCore` IPC types, helper entitlements, and updated
  build/sign/verify scripts all build and self-attest. Milestone 2 (protocol
  boundary, in-process fallback, and `AuraKernel` selection) is pending.
- Chatterbox V3 model download: completed 2026-07-30. The pinned snapshot from
  `ResembleAI/chatterbox` revision `5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18`
  (multilingual-v3) is present under
  `~/Library/Application Support/AURA/chatterbox-model` (~3.5 GB, 6 files).
  `AURA_MODEL_MANIFEST.json` was generated and all SHA-256 hashes were verified
  against the manifest.
- Live neural-synthesis diagnostic benchmark: completed 2026-07-30 on CPU.
  First offline Turkish WAV synthesized at
  `~/Library/Application Support/AURA/chatterbox-test-output/98578148-80db-4965-8402-7d0bf52762a1.wav`
  (24 kHz mono IEEE Float, 266 KB, 68,160 frames, ~8,268 ms synthesis time).
  MPS sampling stalled at ~10% on this host session; CPU fallback succeeded.
- Phase 25 deliverables:
  - New `Tests/AuraAdversarialTests` Swift Testing target with `Fakes.swift` and
    nine eval files: 61/61 tests pass.
  - `scripts/aura-test.sh` default loop builds and runs the new bundle.
  - `AURA_ENABLE_COVERAGE=1 AURA_COVERAGE_MIN=70 ./scripts/aura-test.sh` reports
    `line coverage 70.24% meets 70%` (re-run on 2026-07-30 after TTS latency
    stabilized).
  - New ops docs: `docs/operations/ADVERSARIAL_INCIDENT_RESPONSE.md` and
    `docs/operations/SECURITY_REVIEW_SCHEDULE.md`, referenced from ADR-033 and
    `Sources/AuraCore/ResidualRiskRegistry.swift`.
  - `PromptInjectionClassifier` extended with a deterministic non-English
    instruction-override rule.
- Git state: Phase 24 and Phase 25 changes remain committed and pushed to
  `origin/main == ba9842f`. ADR-034 milestone-1 changes are local-only. The
  `.vscode/launch.json` change is now part of ADR-034 because it adds launch
  configurations for the new helper executable targets.
- Next safe action: Continue ADR-034 milestone 2 (protocol boundary and
  `AuraKernel` selection). Pending release gates otherwise remain consented
  reference audio / human listening (deferred by user choice), Screen Recording
  consent, Developer ID signing/notarization, public plugin PKI, real acoustic
  wake-word model, and completing main-process Accessibility/CLI privilege
  separation. Optionally begin master-prompt Phase 26 after explicit user
  authorization.

  The earlier voice implementation
  `4ffa2139f38ba343707d3c8b393be11259851265` and evidence commit
  `b635b59fd64359d9d3f9a918890bb239161b76f1` were pushed on
  `feature/native-voice-chatterbox-v3`, then merged by explicit no-fast-forward
  commit `e2d7396319c0431b17164284d83ca76624a04e31`. Local `main`,
  `origin/main`, and the transport ref were equal at that merge commit. The
  pre-existing `.vscode/launch.json` change remains outside scope and is not
  part of Phase 24.
- Product lifecycle:
  - Native SwiftUI dashboard window, retained menu-bar control, and Settings
    scene.
  - Settings includes user-controlled local recommendation opt-in, effective
    configuration inspection, changed-value/source display, and audit count.
  - Clean-profile `0700` Application Support bootstrap before `AuraStore`.
  - Missing Speech/microphone authorization is recoverable and never triggers a startup prompt.
  - Explicit voice onboarding, push-to-talk, status, recent tasks, runtime warnings, confirmations, settings/privacy links, and visible/global emergency stop.
  - Explicit Screen Recording onboarding uses
    `CGRequestScreenCaptureAccess`; the manual System Settings route remains a
    fallback.
  - Voice capture is deferred until explicit permissions are granted, so a
    clean TCC profile reaches onboarding without blocking in CoreAudio.
  - Push-to-Talk sessions close after speech plus configured VAD silence, with
    a hard fallback below the conversation timeout. Native final callbacks and
    consecutive STT turns remain consumable; STT errors cannot enter intent.
  - The AVFoundation tap copies callback-owned PCM before crossing actor
    isolation. Real frames are looked up by exact sequence and ingested once;
    no empty placeholder frame reaches native Speech. Concrete STT failures
    end the listening turn as visible errors instead of a later generic timeout.
  - No trained acoustic wake-word model is bundled; the UI discloses
    push-to-talk as the supported path, and production samples do not feed the
    synthetic marker detector.
- Runtime composition:
  - Core audio/STT/intent/conversation/task pipeline remains wired.
  - Implemented Screen, Computer Use, Security, Plugin, VS Code, Ollama, worktree, and multi-agent services are constructed behind existing policy, permission, trust, and configuration gates.
  - Confirmation challenges use one nonce/hash/expiry-bound UI presenter and deny on missing UI, dismissal, timeout, shutdown, or overlap.
  - `AuraConfig.ConfigurationEngine` is constructed before policy/runtime
    services and persists one versioned state envelope through `AuraStore`.
  - Configuration resolution is secure defaults → machine policy → user →
    project → session. Project/session settings cannot weaken registered
    security bounds; session overrides expire on restart.
  - Feature flags are owner/purpose/expiry/rollback/kill-switch governed with
    stable bounded rollout. Local aggregate recommendations are opt-in,
    explainable, and never auto-applied.
- Security boundary:
  - `AuraPluginHost`, `AuraAutomationHelper`, and `AuraShellHelper` are
    separately packaged, App Sandbox entitled helpers with network denied and
    live self-attestation (`--attest-only` prints `sandbox-ok`).
  - The main app remains intentionally non-sandboxed while Accessibility and
    CLI execution remain in-process. Main-process network controls are
    policy/allowlist controls, not OS sandbox enforcement. ADR-034 milestone 1
    delivers the helper executables; milestone 2 will add the protocol boundary
    and switch `AuraKernel` to use the helper-backed path when configured.
  - Local packages prefer the trusted `AURA Stable Local Signing` Keychain
    identity and retain Hardened Runtime plus the existing least-privilege
    entitlements. The stable designated requirement preserves TCC identity
    across rebuilds. This is not Developer ID or notarization.
  - Accessibility and Screen Recording remain user-controlled macOS TCC
    grants, not fabricated signing entitlements.
  - The immediate fallback explicitly selects local female `tr-TR` Yelda and
    maps `1.0` to AVFoundation's normal rate rather than its absolute maximum.
  - Chatterbox Multilingual V3 runs in a separate persistent Python 3.11
    process with pinned source/model revisions, offline runtime mode, bounded
    stdin/stdout JSON, hash-manifest enforcement, private WAV containment and
    cleanup, and PerTh watermark preservation.
  - Neural speech is consent-gated: without an owned/consented bounded PCM
    female reference WAV, AURA remains on Yelda.
- Verified evidence:
  - `AuraConfigTests` passes 17/17. Tests cover atomic persistence failure,
    restart-surviving rollback, ephemeral session expiry, forward/reverse
    migration, non-weakening project/machine policy, flag expiry/kill switch,
    stable rollout, and explicit recommendation acceptance.
  - Phase 25 `AuraAdversarialTests` passes 61/61 tests, including prompt
    injection (multi-language and authority-boundary), tool spoofing, policy
    bypass/deny precedence, memory poisoning with seeded baseline, structured
    output, plugin supply-chain tampering, configuration non-weakening, and
    residual-risk registry references.
  - `AURA_ENABLE_COVERAGE=1 AURA_COVERAGE_MIN=70 ./scripts/aura-test.sh` passes
    all 19 + 1 bundles and reports `TOTAL line coverage 70.23%` with
    `PASSED: line coverage 70.23% meets 70%`.
  - ADR-034 milestone 1: `swift build --product AuraAutomationHelper --product
    AuraShellHelper` succeeds; `AURA_ENABLE_COVERAGE=0
    ./scripts/aura-test.sh /tmp/aurabuild-adr034-smoke` passes all 20 bundles;
    `./scripts/build-app-bundle.sh` packages the new helpers into
    `AURA.app/Contents/Helpers/`; `zsh -n` passes for the three modified shell
    scripts; `git diff --check` passes.
  - Phase 24 release app/helper packaging, stable local signing, and deep/strict
    verification pass under `/tmp`. Main package CDHash:
    `988b4cc89093eadb46c1df21d5f4a98029ba0989`.
  - Current-run Phase 24 line coverage is at least 80.00% per new source file;
    `ConfigurationEngine` is 80.83%.
  - Changed Swift files pass strict `swift format lint`; the repository diff
    passes `git diff --check`.
  - `AURA` passes a fresh warnings-as-errors build after the permission/TTS
    changes.
  - All 18 test bundles pass from a fresh final build path: 587/587 tests.
  - Post-Chatterbox LLVM line coverage is 70.12%; it meets the 70% CI ratchet,
    with 80% retained as the next target.
  - Natural-voice scoped gates pass: `AuraAudioTests` 33/33,
    `AuraCoreTests` 7/7, `AuraAgentTests` 205/205, and
    `AURAIntegrationTests` 16/16. Integration passed again after the explicit
    Screen Recording request correction.
  - Release app build, stable main/helper signing, and deep/strict validation
    pass. Two packages have the same certificate-root designated requirement.
  - Installed-package CDHash:
    `d7a5b529e63b0377682d1192504952542fc5d30a`; signature flags include
    `runtime`, and authority is `AURA Stable Local Signing`.
  - Final packaged clean-profile smoke remained alive for eight seconds until watchdog exit, created `aura.db`, and verified directory mode `0700`.
  - The latest capture-transport repair also passes `AuraAudioTests` 32/32 on
    rerun, `AuraSTTTests` 14/14, and `AURAIntegrationTests` 16/16. One initial
    unrelated wall-clock System TTS latency check exceeded its 2.0 s budget at
    2.754 s and passed on immediate isolated rerun.
  - The post-Chatterbox full repository gate passes all 18 Swift Testing
    bundles, 587/587 tests. `AuraAudioTests` passes 33/33 including fallback,
    warm-up, prompt-bound, path-escape, cleanup, and stop cases.
  - Four Python integrity/reference tests pass; Python sources pass
    `py_compile`; the live helper rejects the incomplete snapshot before model
    import with a bounded fatal JSON envelope.
  - The pinned Python 3.11.15 environment is installed externally and imports
    Chatterbox 0.1.7 from official source commit `5de7a54`, Torch/Torchaudio
    2.6.0, and available MPS support.
  - A release app containing the exact audited helper source passes stable
    signing and strict/deep verification. Package CDHash:
    `d7a5b529e63b0377682d1192504952542fc5d30a`.
  - Microphone and Speech Recognition are granted to the stable identity and
    persisted across a subsequent rebuild/reinstall. Accessibility is enabled
    for AURA in System Settings.
  - Clean-permission launch reaches restricted onboarding without touching
    CoreAudio. Deterministic tests prove one-shot finalization, hard timeout,
    consecutive turns, and error isolation.
  - Main/helper plists pass `plutil -lint`.
  - Phase 24 closure: `AURA_ENABLE_COVERAGE=1 ./scripts/aura-test.sh
    /tmp/aurabuild-phase24-final` passed all 19 Swift Testing bundles with
    70.11% line coverage (≥70% ratchet).
- Phase 25 closure: `AURA_ENABLE_COVERAGE=1 AURA_COVERAGE_MIN=70
    ./scripts/aura-test.sh /tmp/aurabuild` passed all 20 Swift Testing bundles
    with 70.23% line coverage (≥70% ratchet).
- Manual/release gates still open:
  - The post-Phase-24 19-bundle run now passes all 19 bundles with 70.11% line
    coverage. The transient `AVSpeechSynthesizer` callback stall recovered
    without a system service restart; no test or timeout was weakened.
  - Real `CGEvent`, VoiceOver reading order, contrast, Dynamic Type, and live
    screen-content behavior still require release-hardware validation.
  - Screen Recording was reset from the old ad-hoc identity and is not yet
    granted to the stable identity. The installed app now provides a supported
    explicit request button; its secure consent and post-restart preflight
    remain required.
  - ✅ The pinned ~3.5 GB Chatterbox V3 model snapshot downloaded from the
    official Hugging Face revision `5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18`
    and `AURA_MODEL_MANIFEST.json` was generated with SHA-256 bindings.
  - ✅ Live neural-synthesis diagnostic benchmark completed on CPU (MPS stalled
    at ~10% on this host session; CPU fallback succeeded). WAV is valid
    24 kHz mono IEEE Float, 266 KB, 68,160 frames, ~8,268 ms synthesis time.
  - ⏸️ Owned/consented bounded female reference WAV and one human-listened
    Turkish turn are deferred by user choice. AURA remains fail-closed on the
    local female `tr-TR` Yelda system voice until an owned/consented reference
    is supplied.
  - Real acoustic wake-word model, Developer ID signing/notarization, public plugin vendor PKI/catalog, and real third-party payload execution remain unavailable external-material/release gates.
  - The main-process Accessibility/CLI privileges should ultimately move behind least-privilege helpers before claiming OS-enforced network confinement.
- Release status: the earlier voice repair is committed, feature-pushed,
  merged, and remotely verified. Phase 24 and Phase 25 are committed locally
  at `HEAD == bdc1ccd`; `origin/main == a116332` because the most recent push
  failed with a 403 network error. No release, deploy, notarization, public
  marketplace publication, application install/launch, or TCC mutation was
  performed. A verified Phase 24 package exists only under `/tmp`; AURA remains
  closed.
- Next safe action: Implement the `AuraAdversarialTests` target scaffold, add
  the first deterministic eval cases (prompt injection, tool spoofing, policy
  bypass, memory poisoning, structured-output abuse, capability-boundary
  violation), then run the full repository coverage gate. Do not commit, push,
  merge, or release without explicit authorization.

### H-010 current hygiene overlay — 2026-08-12 (superseded intermediate snapshot)

H-010 bounded `Sources/Tests` remediation was executed under explicit user
authority. Xcode/SourceKit, strict formatter, strict build, and full strict
tests pass. The exact SwiftLint policy still exits 2 with 528 serious findings;
the canonical wrapper runs all 21 bundles with zero bundle failures but exits 1
at 66.10% coverage under the unchanged 70% threshold. This intermediate snapshot
was blocked,
the original six-file scope is preserved, and no H-011 or Git delivery action
occurred. Evidence: `EV-REPO-HYGIENE-H-010-SWIFTLINT-REMEDIATION-20260812-01`.

Historical Git delivery snapshot: feature commit `ab83672` was pushed and merged
to `main` at `f6958c4fe21c838f4956e3cd59d96f6e42d1de4f`, which is also
`origin/main`. The later final local/hosted evidence superseded its blocked
disposition; no H-011 exists. Evidence:
`EV-REPO-HYGIENE-H-010-DELIVERY-20260812-01`.

Post-merge read-only ownership verification found 219 untracked ` 2.swift`
copy artifacts, all byte-identical to tracked counterparts (`219/219`), with
no other untracked path and no product tracked diff. They remain preserved and
unstaged pending explicit cleanup/quarantine authority; worktree state is
`dirty_expected`.

### H-010 final local-gate overlay — 2026-08-12T11:28:10Z

The H-010 local blockers are resolved on feature commit
`de320a05ba9195b982e887e13c2116ba3698bc8a`: strict SwiftLint exits `0` with
zero violations in 1,066 files; strict formatter, warnings-as-errors build,
full tests, and adopted-repository fsck pass; and the canonical wrapper exits
`0` with 21/21 bundles, 795 tests, and 70.57% line coverage against the
unchanged 70% threshold. The formatter-compatible SwiftLint contract contains
no `disabled_rules`, no new path exclusions, and no threshold change.

The 219 byte-identical copy artifacts were moved without deletion to the
recoverable external quarantine
`/Users/m_ras/Desktop/AURA-H010-QUARANTINE-20260812`; the repository's current
in-repository untracked count is zero. Feature push is complete. H-010 remains
blocked only until the no-ff merge/main push and exact final hosted-CI result
are observed and projected; no H-011 or product/release completion claim
follows. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`.

The feature was then merged no-ff and pushed to `main` at
`d0527d923d2ed02be3daf291e8181c900508a59a`; `HEAD == origin/main`. The
post-merge state projection is synchronized to this SHA. Hosted run
`31592649228` for the merge SHA remained queued and is not a pass; the final
synchronized-main hosted result remains required.

Final hosted observation is currently fail-closed: run `31593417301` for
`d1e77129c607a40a209b5d1c5207cc83f38a5851` is queued, governance job
`94103274792` has no completed steps, and the GitHub self-hosted runner
inventory is empty. No hosted PASS/FAIL is inferred. Evidence:
`EV-REPO-HYGIENE-H-010-HOSTED-BLOCKED-20260812-01`.

### H-010 terminal hosted-CI closure — 2026-08-12T13:00:00Z

The hosted runner availability blocker and the two discovered artifact-path
contract defects are resolved. Final run `31598491689` on main SHA
`6d4d6da382cd94cd3ac006e26e6f0502eacb9ea8` passed governance and
build-and-test, including 38 governance tests, 21/21 Swift bundles, 70.59%
coverage against the unchanged 70% threshold, release-manifest validation, and
two-file artifact upload. Artifact `9142197938` is unexpired for 14 days;
hosted log SHA-256 is `8cab37029015b5b159a34d54dbcedd5cb4344a6fe22e55e8a95562220b9ed960`.
The temporary runner was deregistered and the runner inventory is zero.

H-010 is complete only for the repository-hygiene program. The manifest has no
H-011; stop at the terminal boundary. Product, beta, signing, release,
deployment, live-hardware, ADR-034/ADR-044, and broader FINAL gates remain
independent and are not claimed complete. Evidence:
`EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`.

### SP-001 live attempt — 2026-08-14T08:44:20Z

The active second-pass overlay is `SP-001 / blocked` after the authorized
user-present local AURA run. Direct evidence `EV-SP-001-20260814-LIVE-TRACE-03`
proves speech observation, displayed confirmation, one safe/reversible
Calculator termination with `NOT_RUNNING` verification, deny, changed-plan,
emergency-stop/re-arm, and restart no-replay behavior. The live UI did not
expose redacted correlation/causation IDs, and no durable event-chain artifact
was available; explicit confirmation-timeout, distinct dismissal,
failed-verification, and concurrent-turn traces remain unproven. Authority is
reset to edit-only. `SP-002` is not safe to start.

### SP-001 OPEN-02 source-side mitigation — 2026-08-14T11:11:19Z

The narrowly authorized source/test fix is recorded under
`EV-SP-001-20260814-TRACE-FIX-04`. A dedicated redacted trace projection now
persists only correlation/causation/request/action/outcome fields, confirmation
terminal outcomes are recorded fail-closed, and opaque trace prefixes are
visible in confirmation/conversation UI. `swift build --product AURA`, the six
focused suites (28/28, 10/10, 22/22, 19/19, 214/214, 35/35), all local
governance validators, 38 deterministic Python tests, compileall, shell syntax,
and diff checks pass. No app launch, TCC, install, commit, push, merge, release,
or deploy occurred. This mitigates the source-side residual only; target-Mac
live trace/store capture and distinct failed-verification, concurrent-turn,
timeout, and dismissal evidence remain open. `SP-001` is still blocked and
`SP-002` is not safe to start.

### SP-001 post-fix bounded live rerun — 2026-08-14T12:10:25Z

The current local build was tested under explicit user-present authority limited
to `/bin/date` and one Calculator close. The confirmation/result UI displayed
opaque trace prefixes. Date allow/deny, Calculator confirmation expiry, one
successful reversible Calculator close, distinct execution/verification, and
read-only no-process verification passed. The local redacted trace table held
12 matching outcome rows. Evidence:
`EV-SP-001-20260814-LIVE-TRACE-FIX-05`.

Post-fix changed-plan, replay, dismissal, cancellation, and concurrent-turn
cases were not authorized in this bounded run. `SP-001` remains blocked and
`SP-002` is not safe to start; no delivery action follows.

### SP-001 mandatory session closeout — 2026-08-14T12:16:54Z

Closeout evidence `EV-SP-001-20260814-CLOSEOUT-06` records the verified
repository state, current build, JSON, second-pass/runtime/hygiene/supply-chain
validators, 38/38 deterministic Python tests, compileall, shell syntax, and
diff checks. Authority is reset to edit-only. SP-001 remains blocked because
the post-fix changed-plan, replay, dismissal, cancellation, and concurrent-turn
matrix was outside the explicit live authority; SP-002 remains unopened.

### SP-001 post-fix dismissal wiring — 2026-08-15T09:32:18Z

The red AURA WindowGroup close path now resolves a pending confirmation as
`dismissed`; the focused integration test and current build passed. The
user-present rerun on `/tmp/aura-sp001-live-fix-02.app` produced redacted
requested → dismissed → policy-blocked rows for `/bin/date` with no execution.
Evidence: `EV-SP-001-20260815-LIVE-DISMISSAL-07`. SP-001 remains blocked for
the remaining post-fix live matrix; SP-002 remains unopened.

### SP-001 mandatory session closeout — 2026-08-15T09:45:50Z

The delivery merge `fd72707…` and pushed pointer projection `c14e39e` are
recorded. Local runtime, second-pass, hygiene, supply-chain, 38/38 Python,
compile, shell, and diff checks passed. SP-001 remains blocked for changed
plan, replay, cancellation, concurrent-turn, and required failed-verification
evidence; SP-002 remains unopened. Evidence:
`EV-SP-001-20260815-CLOSEOUT-09`.

### SP-011 launch-path defect, free-window, acceptance harness — 2026-08-19T17:20:00Z

`AuraKernel.construct()` probed external availability inline; a process sample
showed it stopped inside `SecItemCopyMatching` waiting on securityd, and
because an `LSUIElement` app with no window cannot be activated, AURA neither
finished launching nor offered any way in. `construct()` now records the
affected components as `.loading` and `start()` dispatches
`probeExternalAvailability()` detached.

The `agenda/free-window` leg had no implementation; `CalendarFreeWindows` now
derives free windows from the agenda `calendar.read` already returns, selected
by a slot rather than by a second capability. Two accessibility defects were
fixed: the section pills and composer buttons had no accessible name, and the
transcript's messages were unlabelled `AXUnknown` nodes, unreadable to
assistive technology. `scripts/sp011-acceptance/` adds a resumable live-run
harness. 21/21 bundles, 1068/1068 tests, 0 failed.

SP-011 remains `blocked`: the approved-page summary, the browser
injection-ignore leg, the browser revocation leg, and the contacts non-empty
read are still unexecuted. Evidence:
`EV-SP-011-20260819-LAUNCH-AND-HARNESS-11`. SP-012 is not safe to start.

### SP-011 live browser and contacts legs — 2026-08-19T18:55:00Z

Four legs passed live with the operator present: the approved page summary
(blocked since 2026-08-18), the browser injection-ignore leg, the browser
revocation leg, and the contacts non-empty read. Three defects were found by
running them — an observation lifetime of 30 seconds that could not cover the
~13 s extension cold start plus one local-model turn, and two Contacts-framework
calls that aborted the whole application through Objective-C exceptions Swift
cannot catch. 21/21 bundles, 1070/1070 tests, 0 failed.

SP-011 remains `blocked`: the free-window non-empty read is owed, because this
attempt destroyed the calendar authorization by running `tccutil reset Calendar`
against a working grant and could not restore it. Evidence:
`EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12`. SP-012 is not safe to start.

### 2026-08-24T08:45:49Z — SP-019 local control attempt

SP-019 remains **in_progress**. The production kernel now wires the bounded
preference profile store, and the Privacy surface exposes purpose/scope/
retention, search, conflict, correction/deletion/export, and retention
controls. `EV-SP-019-20260824-LOCAL-CONTROLS-01` records a clean production
build, focused 83/83, full 21/21 bundles with 1,141 tests and zero failures,
the second-pass validator, and 39 governance tests.

`EV-SP-019-20260824-LAUNCH-SMOKE-02` proves only LaunchServices startup and
exact-process stop. Temporary HOME did not isolate Application Support; no UI
operation or explicit memory mutation was performed. All eight user-present
R8 scenarios remain open, ADR-043 remains Proposed, and SP-020 is not safe to
start. The next safe action is a user-present save/quit/relaunch plus the eight
redacted scenario checks. No commit, push, merge, release, or deploy occurred.

### 2026-08-24T10:50:50Z — SP-019 direct user-present controls attempt

`EV-SP-019-20260824-LIVE-CONTROLS-04` adds partial direct evidence from the
final app in a `CFFIXED_USER_HOME`-isolated profile: `Concise` survived a real
menu quit/relaunch; purpose, scope, retention, inspect/correct controls,
audit exclusion, retention cleanup, and local-only rejection were observed.
The verified tool fact, resolved reference, destructive clarification,
contradiction resolution, export artifact, deletion receipt, and direct
transport trace remain open. SP-019 stays `in_progress`; the Delete action is
paused for action-time confirmation and SP-020 remains unopened.
### 2026-08-24T10:58:37Z — SP-019 closeout validation reconciliation

`EV-SP-019-20260824-CLOSEOUT-05` records a successful rerun of the required
runtime-completion validator, second-pass validator, 39 governance tests, JSON
checks, and `git diff --check` after correcting the bounded evidence-ID
projection. SP-019 remains `in_progress`; live verified-tool, reference,
contradiction, export, deletion, and transport evidence remain open. Delete is
paused for action-time confirmation and SP-020 remains unopened.
### 2026-08-24T11:15:56Z — SP-019 live export reconciliation

The Privacy export control passed its live postcondition under
`EV-SP-019-20260824-LIVE-CONTROLS-06`: `/tmp/aura-memory-sp019-export.json`
exists, contains 203 records, excludes audit data, and has the recorded SHA-256
`b00a4e3958adb932e2772def68bea59970fd29fd9ba237f56271c4aae87f2857`.
SP-019 remains `in_progress`; Delete is paused for action-time confirmation and
the verified tool fact, reference, contradiction, and transport scenarios are
still open. SP-020 remains unopened.
### 2026-08-24T11:19:13Z — SP-019 closeout after export evidence

`EV-SP-019-20260824-CLOSEOUT-07` records a green rerun of the required runtime,
second-pass, governance, JSON, and diff checks after export evidence was
reconciled. SP-019 remains `in_progress`; Delete is paused for action-time
confirmation and SP-020 remains unopened.

### 2026-08-24T15:07:21Z — SP-019 tool-evidence wiring and live acceptance

Four of the five scenarios still open were traced to **missing product paths,
not failed procedures**: nothing in production wrote `MemoryClass.projectFact`,
produced `MemoryProvenance.observed`, or used
`MemoryWriteSource.verifiedToolEvidence`; `ContradictionDetector` was
unreachable because the only live subject was the globally unique
`intent:<uuid>`; `ReferenceResolver.explicitlyConfirmedTargetID` had no
producer; and `AuraKernel.deleteMemoryRecord` discarded the engine's
`MemoryDeletionReceipt`.

A bounded `ToolObservation` seam, a stable fact key with global scope, the
reference-clarification round trip, and a surfaced deletion receipt were wired
and covered by 19 new tests — full matrix **21/21 bundles, 1,160 tests, 0
failed**, no new formatter or lint findings.

Live acceptance in an isolated `CFFIXED_USER_HOME` profile then produced a
verified tool fact (`projectFact shell.execute:/bin/date`, provenance
`observed`), a real contradiction and its user-selected resolution
(`{"supersededExisting":{}}`), restart persistence, an authorized permanent
deletion with a user-visible receipt, a live `Blocked: confirmationDenied`
refusal of a risky action, and two socket-table traces of the live process with
**zero** non-loopback peers.

Evidence: `EV-SP-019-20260824-TOOL-EVIDENCE-WIRING-08`,
`-LIVE-PROJECT-FACT-09`, `-LIVE-DELETION-RECEIPT-10`, `-TRANSPORT-TRACE-11`,
`-MEMORY-AUTHORITY-12`.

SP-019 remains `in_progress`: the multi-turn reference scenario is proven only
deterministically because the production rule-based classifier cannot emit an
intent carrying an unresolved implicit reference
(`RISK-SP-019-REFERENCE-UNREACHABLE`). SP-020 remains unopened.

### 2026-08-24T16:19:20Z — SP-019 multi-turn reference closed

The last open scenario was traced to one guard: `classifyFileCommand` accepted
an open-prefixed target only when `looksLikePath` held, so `open the file` fell
through to application matching and became `.unknown`, leaving the entire
reference resolver unreachable in the shipped app. `ProductionReferenceWiringTests`
had masked it with a fixture classifier that already behaved correctly.

A known reference phrase now yields the intent with its target slot empty
(`.fileOpen`, `.appActivate` for `the app`) at confidence 0.7, and the phrase
list — previously three diverging literals — is defined once in `AuraCore`.

Live: `open the file` returned `Blocked: ambiguous` with a clarifying question
while two candidates were plausible; `open the file alpha` resolved to **alpha**,
bound `filePath`, and opened the real file. Full matrix **21/21 bundles, 1,164
tests, 0 failed**, including a new suite driven by the real classifier.

Evidence: `EV-SP-019-20260824-LIVE-REFERENCE-13`.
`RISK-SP-019-REFERENCE-UNREACHABLE` is closed.

All eight R8 scenarios now carry direct live evidence. SP-019 stays
`in_progress` pending one consolidated acceptance pass on a single build, since
the evidence currently spans three. SP-020 remains unopened.

### 2026-08-25T06:43:51Z — SP-019 completed

All eight R8 live/product scenarios re-run and passed against one build
(`fccf15204202b7c3f71815a2ff547e5706907dfe2caa1d30dea29d0157989f00`) in a single
isolated profile, so the completion claim no longer spans three binaries.
Evidence: `EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14`.

`RISK-SP-019-LIVE-MEMORY-CONTROLS` and `RISK-SP-019-REFERENCE-UNREACHABLE` are
closed. SP-020 is next. Release/deploy remains blocked on signing and
notarization (SP-026/SP-027); only a `development_unverified` artifact is
producible today.
