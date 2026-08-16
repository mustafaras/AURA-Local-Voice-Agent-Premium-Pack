# AURA Runtime Completion — Active Context

> **Program:** AURA Runtime Completion Program v1.0.0  
> **Current prompt:** `FINAL`
> **Current program state:** In progress; R1 completed, R2/R3/R4/R5/R6/R7/R8/R9/R10/R11/R12 remain open, FINAL active for blocked acceptance and closeout audit
> **Live repository lineage:** `main` contains the delivered control-plane projections, with verified non-projection baseline `d82fde6be6e95bc8d3ccb64341bd2538baf12a92`; later descendants are control-plane-only projections. Main CI run `31613321170` remains a historical queued observation and is not used as a pass for this control-plane session. No repository-defined signed/notarized/public deployment target exists.
> **Audited content baseline:** `47775180c224f87fa5a58703f793515ffcb2c35c` under ADR-045 (projection-only descendants are not new product audits)

## Canonical status

## Current second-pass overlay — 2026-08-16 (SP-005 closure; OPEN-04 closed)

`SP-006` / `completed` — `SP-005` / `OPEN-04` (NLU/UI reachability half) is
**completed** under `EV-SP-005-20260816-REACHABILITY-01`, superseding the
SP-004 closure overlay below. The four filesystem/URL capabilities are now
reachable through NLU classification (`RuleBasedUtteranceClassifier`),
production routing (`ToolRouter` → `CapabilityRegistry` → `PolicyEngine` →
`FileSystemURLOpener`), and `CapabilityPlanner` validation. `OPEN-04` is
**closed** (both SP-004 adapter half and SP-005 reachability half completed).
Verified: strict build green, **21/21 bundles, 870/870 tests, 0 failed**,
governance validators green. All changes local and uncommitted; authority
edit-only. `SP-006` is **pending and unopened**.

Forwarded residual risks: `RISK-SP-004-TOCTOU-RACE`,
`RISK-SP-004-HANDLER-COMPROMISE` (R10 scope); seven-scenario live
demonstration (live-gate track). `RISK-SP-004-CASE-SENSITIVITY` is **closed**.

### Superseded overlay — 2026-08-16 (SP-004 closure)

`SP-005` / `completed` — `SP-004` / `OPEN-04` (adapter half) is **completed**
under `EV-SP-004-20260816-ADAPTERS-01`, superseding the 10:08:19Z overlay below.
The four capabilities `filesystem.open_file`, `filesystem.open_folder`,
`filesystem.reveal`, and `url.open` are now real, typed, policy-controlled,
verified adapters (`AuraAutomation.FileSystemURLOpener` +
`OpenTargetValidator`: refuse-before-effect, `PathConfinement` canonicalization
before containment, http/https/mailto scheme allowlist, real `NSWorkspace`
Boolean postcondition) and are truthfully registered `.ready` — reachable only
through direct policy-gated `AuraKernel` calls, the same non-NLU path
`app.discover`/`app.hide`/`task.status`/`task.cancel` use. Verified: strict
build green, **21/21 bundles, 850/850 tests, 0 failed**, governance validators
green. All changes are local and uncommitted; authority is edit-only.
Read the overlay pair as the program convention defines it: `active_prompt` is
the *next eligible* prompt (`SP-005`, **pending and unopened**) and
`active_state` is the state of the prompt just closed (`SP-004`). The
authoritative guard is `completed_prompts` = `SP-000`…`SP-004`. **`OPEN-04`
remains open** — `SP-005` owns NLU/UI reachability, planner wiring, and the
seven-scenario live demonstration.

New bounded residual risks: `RISK-SP-004-TOCTOU-RACE`,
`RISK-SP-004-HANDLER-COMPROMISE`, `RISK-SP-004-CASE-SENSITIVITY` (registered
with owners and closure criteria). Forwarded unchanged:
`RISK-INJECTION-COVERAGE-NON-DIALOGUE`, `RISK-SP-003-MODEL-LATENCY`,
`RISK-SP-003-LIVE-VOICE-RESIDUAL`, `RISK-STT-MIC-NOT-CAPTURING`.

### Superseded overlay — 2026-08-16T10:08:19Z (handoff audit; SP-004 then pending)

`SP-004` / `completed` — control-plane reconciliation after a handoff-accuracy
audit, recorded under `EV-SECOND-PASS-20260816-HANDOFF-AUDIT-21`. **No prompt was
opened and no gap was closed.** Read the overlay pair as the program convention
defines it: `active_prompt` is the *next eligible* prompt and `active_state` is
the state of the prompt just **closed** (`SP-003`). `SP-004` is **`pending` and
unopened** — the authoritative non-completion guard is `completed_prompts`,
which contains only `SP-000`…`SP-003`. Prompt frontmatter `state:` reads
`pending` for *every* SP prompt including finished ones, so frontmatter alone
never proves a prompt is unopened.

Re-verified at `e8f5f434c8741d8a13231698030dcf7768140746`: worktree clean,
**21/21 bundles, 816 tests, 0 failures** (`Package.swift` declares exactly 21
test targets, so no bundle was skipped), all four governance validators at exit
0, and **38/38** deterministic governance tests. The audit corrected two false
claims in `NEXT_SESSION_STARTER.md` — a stale `HEAD` pointer naming `d55aebb`,
which was that document's own parent commit, and the claim that `SP-004` closes
`OPEN-04` when `SP-005` carries the identical `gap_ids: OPEN-04` and `SP-004`'s
completion gate disclaims UI/NLU reachability. It then brought this control
plane forward: `SECOND_PASS_STATE.json` and `session-handoff.json` had never
been updated past 2026-08-15 despite the 2026-08-16 work under
`EV-SP-003-*-18`, `-19` and `-20`, and `session-handoff.json` still credited the
**retracted** `EV-SP-003-20260815-R2-DIALOGUE-TESTS-15` in its `completed[]`
array. Every validator passed throughout, because none of those fields are
validator-enforced.

Forwarded residual risks: `RISK-INJECTION-COVERAGE-NON-DIALOGUE`,
`RISK-SP-003-MODEL-LATENCY`, `RISK-SP-003-LIVE-VOICE-RESIDUAL`, and
`RISK-STT-MIC-NOT-CAPTURING`. `RISK-SP-003-NLU-DOWNGRADE-VARIANCE` is **closed**
under `EV-SP-003-20260816-RISKS-AND-UI-19` and is no longer forwarded. Authority
is edit-only. `OPEN-04` must not be marked closed at the end of `SP-004`.

### Superseded overlay — 2026-08-15T18:23:13Z (SP-003 closure; state reconciled 2026-08-16)

`SP-004` / `completed` — `SP-003` / `OPEN-03` is **completed**, superseding the
18:03:11Z blocked overlay below. The seven R2 scenarios were run live against
`gemma4:latest` under `EV-SP-003-20260815-LIVE-7SCENARIO-16`, which exposed a
real defect: prompt-injection content inside an approved `DialogueContextItem`
displaced the user's request and the model replied exactly `PWNED`. Root cause
was missing enforcement, not missing detection —
`PromptInjectionClassifier` already scored the payload as `.blocked` but was
never invoked on the dialogue path. `DialogueEngine` now screens every context
summary before prompt assembly, withholding blocked content while preserving
provenance, and screens as non-authoritative regardless of the item's
self-declared `authority`. Verified under
`EV-SP-003-20260815-INJECTION-FIX-17`: three deterministic regression tests,
`AuraIntentTests` 70/70, and a live re-run passing 25/25 with 0 failed bundles;
scenario 7 now answers substantively in Turkish with provenance intact. All
inferences were local; cloud inference count 0. `SP-004` is next eligible but
remains `pending` and unopened. Authority resets to edit-only. Forwarded
residual risks: `RISK-INJECTION-COVERAGE-NON-DIALOGUE`,
`RISK-SP-003-NLU-DOWNGRADE-VARIANCE`, `RISK-SP-003-MODEL-LATENCY`, and
`RISK-SP-003-LIVE-VOICE-RESIDUAL` — none owned by SP-003 or blocking SP-004.

### Superseded overlay — 2026-08-15T18:03:11Z (blocker, since resolved)

`SP-003` / `blocked` — `SP-003` / `OPEN-03` is **blocked**, superseding the
2026-08-15T14:44:48Z entry preserved below. The seven scenarios of the R2
completion demonstration were run live through the real `IntentEngine`,
`RuleBasedUtteranceClassifier`, `DialogueEngine` and `OllamaAdapter` against
`gemma4:latest`, the only genuinely local model, under
`EV-SP-003-20260815-LIVE-7SCENARIO-16`. All 6 inferences were local and the
cloud inference count was 0. Six scenarios met their typed safety and
truthful-degradation criteria. **Scenario 7 failed:** prompt-injection content
carried inside an approved `DialogueContextItem` displaced the user's request
and the model replied exactly `PWNED`, so R2's "prompt-injection content
treated as data" requirement is not met on the live path. Root cause:
`PromptInjectionClassifier` is constructed at
`Sources/AURA/AuraKernel_Construction.swift:216` but is never applied to
dialogue context items, and `DialogueEngine.makePrompt` defends only with a
natural-language instruction the local model ignores. Also measured: 2 of 4
model-backed turns were failed closed from `.converse` to `.unknown`/`.clarify`
by the typed guard — safe, but it costs a clarification round-trip on an
ordinary question — and model-backed latency ran 19.8–24.9 s against
0.08–0.42 ms on the deterministic fast path. `SP-004` must not be opened.
Authority is edit-only. The earlier evidence ID
`EV-SP-003-20260815-R2-DIALOGUE-TESTS-15` is retracted: it recorded a pass of
the pre-existing regression suite, mapped test names onto the seven scenarios
instead of running them, and wrote its artifact only to `/tmp`.

### Superseded overlay — 2026-08-15T14:44:48Z (retained, no longer authoritative)

`SP-003` / `OPEN-03` is completed for its bounded second-pass gate under
`EV-SP-003-20260815-R2-DIALOGUE-TESTS-15`: the source-side R2 bilingual NLU and dialogue contract is verified
by the passing Swift test suite (21/21 bundles, 0 failed bundles) and focused
R2 coverage of Turkish/English/mixed handling, clarification, degradation,
provenance, and slot expiry. `SP-004` is the next eligible prompt but remains
`pending` and unopened. Authority is edit-only. First-pass R2 live
microphone/TCC Turkish/English/mixed scenarios, live Ollama inference, and
R3–R12 / `FINAL` / beta / signing / release / deploy / telemetry gates remain
open and are not advanced by this simulated-boundary evidence.

## Current terminal H-010 closure

Repository hygiene H-010 is `completed` at current `main` / `origin/main`
`d82fde6be6e95bc8d3ccb64341bd2538baf12a92`. The hosted workflow/source proof
was executed on `6d4d6da382cd94cd3ac006e26e6f0502eacb9ea8`; descendants after
that SHA are control-plane-only projections. SwiftLint, formatter, build, full
tests, fsck, coverage, local validators, hosted governance/build/test, and
development-unverified artifact upload passed for the recorded boundaries. H-010
is the terminal hygiene prompt; all H-000…H-010 prompts are complete and no
H-011 exists. The chronology below is historical and cannot reopen H-010.

## Repository hygiene overlay — historical chronology

The repository-hygiene program is a separate, synchronized control overlay at
`docs/operations/REPO_HYGIENE_PROGRAM.md`. Its machine state is
`AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json`, currently
`H-010` / `completed`; its 11-prompt manifest, focused ledger, contracts,
Tier-0/Tier-1 read order, and validator must agree before a hygiene prompt can
advance. This overlay does not close R2–R12, FINAL, beta, release, security,
permission, or live-hardware gates. The current authority is reset at closeout;
no standing mutation authority remains:
no cleanup, Git object mutation, install, release, or deploy is authorized;
the H-008 delivery was separately authorized and is recorded at merge commit
`47775180c224f87fa5a58703f793515ffcb2c35c`. H-000 is complete for chain order. After exact user
authority to create a clean clone, H-001 verified a fresh remote clone with
strict fsck exit 0, matching main tip/closure, clean status, and a current
worktree preservation mapping. The original local object database still fails
fsck and remains untouched. H-001 is complete for chain order. Exact
`ONAY: H-002` was received and H-002 completed a read-only ownership and
disposition inventory: 18 tracked control-plane modifications, 0 untracked,
and 69,939 ignored paths. Every path has an explicit disposition and recovery
reference in `/tmp/aura-h002-worktree-inventory.sV4ynZ/`; generated `.build`,
Python environment/cache, and macOS metadata groups remain in place. Exact
`ONAY: H-003` was received. H-003 added the minimum explicit root `/.venv/`
rule, documented generated boundaries, and added positive/negative
clean-fixture regression coverage; no generated artifact is tracked and source,
fixture, manifest, and evidence paths remain visible. Exact `ONAY: H-004` was
then received. H-004 reconciled the active macOS 27+/arm64/Swift 6.4 baseline,
21 Swift test targets, active prompt references, and Swift Testing path
discovery/fail-closed behavior. Exact `ONAY: H-005` was then received.
H-005 added `.swift-format` schema version 1 and explicit CI
strict-concurrency/warnings-as-errors flags. Under explicit bounded-remediation
authority, all 1,019 configured formatter findings across 116 files were
resolved in reviewed batches; recursive strict formatter lint, strict build,
and the 21-bundle/794-test wrapper pass. Historical intermediate SwiftLint evidence reported exit 2 with 1,330 findings; the later final H-010 evidence resolved that result. H-005 was delivered and is complete
for chain order; H-006 is complete under exact `ONAY: H-006`, with
`EV-REPO-HYGIENE-H-006-20260810-01` recording the bounded unsafe/debug audit,
strict build, focused tests, and cognitive gate. H-007 is complete for chain
order and H-008 is complete after its verified delivery. H-009 is complete for
chain-order purposes after its bounded context summary and architecture audit
were synchronized. Historical intermediate H-010 evidence was blocked on explicit
limitations; the terminal H-010 closure above supersedes it. The raw all-source matrix is
65.15%, while the explicit four-file host-boundary scope passes at 70.02%
against the unchanged 70% ratchet. H-007 edit-only authority expired at
closeout; no standing cleanup/deletion/quarantine authority remains. H-009 was
started under exact `ONAY: H-009`: its source-of-truth map, bounded context
summary, package/dependency audit, and privileged-boundary audit are recorded
under `EV-REPO-HYGIENE-H-009-20260810-01` and
`EV-REPO-HYGIENE-H-010-20260810-01`; the six H-008 duplicate backups remain
SHA-validated in the recoverable quarantine
`/Users/m_ras/Desktop/AURA-H008-QUARANTINE-20260810`. Historical H-010 wording below is superseded; the
original damaged database is preserved for rollback, while Xcode/SourceKit
capability and wrapper discovery are now resolved. The strict full SwiftLint
policy later reached zero violations in the final run. Merged-main hosted CI is observed and passing
under `EV-REPO-HYGIENE-MAIN-CI-FINAL-20260811-01`; current formatter, lock-graph
vulnerability/SBOM, and local validator gates pass. No H-011 exists and no
automatic transition is permitted.

Post-merge read-only ownership verification found 219 untracked Swift paths
ending in ` 2.swift`; each is byte-identical to its tracked counterpart, with
zero different or missing pairs and no other untracked path. They remain
preserved and unstaged pending explicit cleanup/quarantine authority. This was
an intermediate ownership snapshot and does not override the terminal H-010
closure above.

Separate remediation authorization `ONAY: HYGIENE-REMEDIATION-01` produced
`EV-REPO-HYGIENE-REMEDIATION-20260810-01`: the clean clone passes strict fsck,
the formatter/source and local scanner gates pass, and the original `.git`
remains untouched. Follow-up evidence
`EV-REPO-HYGIENE-DEPENDENCY-REMEDIATION-20260811-01` closes the current
lock-graph OSV/Grype dependency risk with zero findings under the documented
generated-environment boundary and passing runtime/audio/helper checks.
`EV-REPO-HYGIENE-GIT-ADOPTION-20260811-01` closes current object integrity and
reachable-history secret scanning; the damaged pre-adoption `.git` remains
preserved for rollback. `EV-REPO-HYGIENE-HOSTED-CI-FINAL-20260811-01` closes the
hosted-CI observation for the pushed remediation commit. Xcode/SourceKit
capability is resolved. The 1,330-finding result and blocked wording are
superseded by the final zero-finding local and hosted evidence. No H-011 exists.

The strict BOOTSTRAP preflight and R0 governance repair are complete. Canonical machine state is in
`AURA_RUNTIME_COMPLETION/state/current-state.json`; the ordered manifest has
15 implementation prompts and `15_SESSION_CLOSEOUT.prompt.md` remains the
mandatory out-of-manifest session procedure. Legacy status prose is historical
compatibility context and is guarded by the R0 validator. R1 runtime
integration and trace correctness are complete for local development/integration
scope. R2 bilingual NLU and dialogue is implemented and system-tested but **not
formally closed** (see "R2 closeout status" below). R3 capability registry and
typed planner is implemented and system-tested but **not complete** (see "R3
status" below). R4 computer-use productization core and registry wiring are
implemented and tested but **not complete** (see "R4 status" below). R5
browser/mail/calendar/contacts adapters, R6 coding-agent routes, and R7
voice/resource governance remain open; R8 memory/context is locally
implemented but remains open on live gates and ADR-043; R9/R10/R11 first-pass
slices remain open, R12 is blocked by its beta/RC gates, and FINAL is now active
for a blocked acceptance and closeout audit by user-directed transition request.

## Second-pass synchronized overlay

The separate second-pass chain is defined by
`AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json` and is currently
`SP-003` / `completed`; `SP-000` completed the baseline and synchronization lock,
`SP-001` completed its bounded `OPEN-02` gate, and `SP-002` completed its
bounded `OPEN-03` gate under `EV-SP-002-20260815-PTT-MOCK-14` with a documented
mock-STT accessibility accommodation. `SP-003` is next eligible but remains
unopened and `pending`.
Its manifest, gap register, Tier-0/Tier-1 context order, focused append-only
ledger, prompt contract, and validator remain synchronized before any further
second-pass prompt can run. This overlay does not overwrite the first-pass
canonical state above: first-pass `FINAL` remains blocked, while second-pass
`SP-002` is the next pending prompt and has not been opened. The user-authorized
live attempts captured direct safe observation, displayed confirmation, redacted
correlation/causation, allow, deny, expiry, dismissal, changed-plan, replay,
cancellation, concurrent-turn isolation, truthful failure, reversible mutation,
independent verification, and restart no-replay behavior for `SP-001`. Authority
is reset to edit-only.

## SP-000 baseline and synchronization lock — 2026-08-13

The live branch, remote, worktree, state projections, manifest, gap register,
toolchain, and control-file references were revalidated at
`05af25de7d0e21a5fff114a7fb2cba083009a923`. The second-pass validator was
corrected to validate the active prompt dynamically rather than hard-coding
`SP-000/pending`. SP-000 is complete; no product source, app, permission,
provider, beta, release, commit, push, merge, or deployment action occurred.
Evidence: `EV-SP-000-20260813-BASELINE-01`.

## SP-001 live trace attempt — 2026-08-14

The prompt-relevant AuraCore, AuraPolicy, AURAIntegration, AuraAgent, and
AuraAudio suites passed at `main` `76ce21ab423bd3c828e3386fb7174bf11ec56862`
(316 tests total across the five bundles). The authorized live attempt then
captured direct speech observation, displayed confirmation, one reversible
Calculator termination with `NOT_RUNNING` verification, deny, changed-plan,
emergency-stop/re-arm, and restart no-replay behavior. It remains blocked
because the UI/runtime exposed no redacted correlation/causation IDs or durable
event chain; explicit confirmation-timeout, distinct dismissal,
failed-verification, and concurrent-turn traces remain unproven. Evidence:
`EV-SP-001-20260814-ATTEMPT-01` and
`EV-SP-001-20260814-LIVE-TRACE-03`. Retry only SP-001 when that missing direct
evidence is available; do not start SP-002.

## SP-001 redacted trace source mitigation — 2026-08-14T11:11:19Z

Under explicit edit-only authority, the OPEN-02 source/test residual was
mitigated with `RedactedTraceRecord`/`AuraTracePersistence`, a dedicated
`redacted_trace_records` store table, EventBus wiring, confirmation terminal
outcome records, and opaque trace prefixes in confirmation/conversation UI.
Generic raw event payload persistence remains excluded. `swift build --product
AURA`, the six focused suites, all local governance validators, and 38
deterministic script tests pass under `EV-SP-001-20260814-TRACE-FIX-04`.
This does not replace live evidence: target-Mac store/UI capture and distinct
timeout, dismissal, failed-verification, and concurrent-turn traces remain
open. SP-001 stays blocked; authority remains edit-only; SP-002 must not begin.

## SP-001 post-fix bounded live rerun — 2026-08-14T12:10:25Z

With explicit user-present authority limited to `/bin/date` and one Calculator
close, the current unsigned build displayed redacted trace prefixes and
persisted the matching local sequences. Date allow/deny, Calculator expiry,
one successful reversible close, distinct tool verification, and read-only
no-process verification passed under
`EV-SP-001-20260814-LIVE-TRACE-FIX-05`. The authority did not cover post-fix
changed-plan, replay, dismissal, cancellation, or concurrent-turn cases; the
active second-pass state therefore remains `SP-001 / blocked` and `SP-002` must
not begin.

## R2 closeout status (2026-08-07)

R2 is **not formally complete**. The production dialogue path is model-backed,
typed, bilingual, and passes 20/20 bundles with 0 failures, but two live
verification evidence classes are still absent and physically require the user
present:

- `RISK-STT-MIC-NOT-CAPTURING` — **Open**. Candidate fix applied to
  `AuraAppModel.pushToTalk()` (proactively calls
  `PermissionCoordinator.requestVoicePermissions()` + `kernel.startSpeechRecognition()`)
  but unconfirmed pending a live Push-to-Talk test. Evidence:
  `EV-R2-20260804-PTT-PERMISSION-AUDIT-01`.
- `RISK-ENGLISH-ONLY-INTENT` — **Mitigating**. The Mitigating→Closed transition
  requires the live 7-scenario bilingual completion demonstration, not yet
  performed.

`RISK-STRUCTURED-NLU-MODEL-QUALITY` sub-finding 3 (residual `dialogue_act`
sampling variance on `gemma4:latest` 8B) was **Accepted as bounded residual
risk** (Option A) on 2026-08-07 with owner/expiry/release-impact documented.
Evidence: `EV-R2-20260807-STRUCTURED-NLU-SUBFINDING3-ACCEPT-01`.

**To close R2**, with the user physically present: (1) reset TCC if `.denied`
(System Settings → Privacy & Security → Microphone and Speech Recognition),
relaunch via `open /Applications/AURA.app`, enable voice permissions, press
Command-Shift-T and speak "Merhaba AURA, hava nasıl?" — record
`EV-R2-20260804-LIVE-VOICE-DEMO-01`; (2) run the 7-scenario completion
demonstration — record `EV-R2-20260804-LIVE-7SCENARIO-01`. Only if both pass
can R2 be marked `completed` and those two risks closed. Do not fabricate this
evidence.

## R3 status

R3's architectural core is implemented and tested with zero regression:
`CapabilityManifest`/`CapabilityRegistry`/`CapabilityPlanner` replace the closed
five-intent `ToolRouter` switch (`ToolRegistry`/`ToolContract` deleted); 14
capabilities are registered (10 truthfully `.ready`, 4 truthfully `.disabled`
with no adapter yet); ADR-038 documents the design and known gaps. Full
regression: 20/20 bundles, 717/717 tests, twice, no flakiness. Evidence:
`EV-R3-20260804-CAPABILITY-REGISTRY-PLANNER-01`.

**R3 is NOT complete.** Remaining: filesystem/URL adapters are unbuilt; the 4
newly-ready capabilities (`app.discover`/`app.hide`/`task.status`/`task.cancel`)
are reachable only via direct `AuraKernel` calls (no NLU/UI path yet); the
planner is not yet wired into `DialogueEngine`/`ToolRouter` for real multi-step
natural-language plans; and the required 7-scenario live completion
demonstration has not been performed.

## R4 status

R4 computer-use productization is `in_progress`. Its **deterministic productization core** and **registry/composition wiring** are implemented and tested
(`EV-R4-20260807-PRODUCTIZATION-CORE-01`, `EV-R4-20260807-WIRING-REGISTRY-01`, ADR-039 accepted): a production observation contract
(`ComputerUseObservation`), a beta allowlist (`ComputerUseBetaAllowlist.initial`, closed until explicit live validation), the first production planner
(`DeterministicComputerUsePlanner` — emits only closed `ComputerUsePlan` values and stops/clarifies for unapproved apps, unknown objectives, secure fields,
or modals), resumable hash-bound confirmation (`ComputerUseConfirmationStore`), semantic postcondition verification (`ComputerUseVerifier`), and the
`computerUse.run` capability registered in the registry (truthfully `.disabled`) with `AuraKernel.computerUseRun` wiring the bounded loop through policy +
allowlist. Focused suites: AuraComputerUseTests 62/62, AuraIntentTests 67/67; `swift build --target AURA` clean.

**R4 is NOT complete.** Remaining: (1) `computerUse.run` remains `.disabled` until an app is explicitly live-validated; (2) the required live beta-app
evidence — safe tasks in ≥3 approved apps on granted Accessibility/Screen-Recording hardware, live confirmation, live emergency stop, and a live
screen-content injection fixture — has not been performed and requires the user physically present. `RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` is mitigated
but not closed.

## R5 status

R5 browser/mail/calendar/contacts adapters is `in_progress`, started by
user-directed deviation while R2/R3/R4 remain open (recorded in the program
ledger). Scope per `06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md`: read-first
browser/mail/calendar/contacts capabilities, least-privilege OAuth/Keychain,
injection resistance, offline/degraded behavior, and live acceptance. Primary
risks: `RISK-MISSING-PRODUCTIVITY-ADAPTERS`, `RISK-INDIRECT-PROMPT-INJECTION`,
and `RISK-OAUTH-OVERPRIVILEGE`. **ADR-040 is now Accepted** (authored at
`docs/decisions/ADR-040-productivity-integrations-oauth.md` and recorded in
`DECISION_REGISTER.md` on 2026-08-07), defining the browser/mail/calendar/
contacts least-privilege OAuth/Keychain trust boundaries: read-first default,
incremental least-privilege OAuth scopes, Keychain-only revocable tokens,
deny-by-default `NetworkAllowlist` enforcement, untrusted-content provenance/
isolation, closed account/profile scope, immutable send/mutation confirmation,
and computer use as explicit bounded fallback.

**R5 is NOT complete.** The first typed read-first adapter slice is implemented
and tested under `EV-R5-20260808-READ-FIRST-ADAPTERS-01`: structured Safari
active-tab and Gmail read-only contracts, EventKit/Contacts native read
adapters, OAuth/Keychain scope boundaries, provenance/injection guards, and
truthful disabled registry manifests. The slice is not wired into the live
composition/NLU/UI path; Safari extension packaging, provider transports,
authorized accounts/permissions, mutation/send, and live acceptance remain.
The full local regression is 21/21 bundles, 747/747 tests, 0 failures; the
focused `AuraProductivityTests` result is 9/9. Live acceptance requires
explicitly authorized test accounts/profiles and the user physically present
for permission prompts.

## R6 status

R6 — VS Code and Coding-Agent Completion — is the active prompt after the
user-directed transition from R5. The local policy/bridge slice remains
verified under `EV-R6-20260808-POLICY-BRIDGE-01`; the current first-pass
typed-route continuation is recorded under
`EV-R6-20260808-TYPED-ROUTES-02`. It adds typed signed command
and response routes, fail-closed workspace precedence/ambiguity handling,
backend health probing that does not confuse executable presence with auth or
model readiness, production router wiring through the coding-task coordinator,
and durable deadline/inactivity/latest-checkpoint controls.

R6's unresolved gates are also copied into
[`SECOND_PASS_OPEN_GAPS.md`](../SECOND_PASS_OPEN_GAPS.md) for the future second
pass. That record does not defer the current first-pass R6 work: extension
provisioning, live route acceptance, backend readiness, durable reviewable
flows, and user-present acceptance remain the active next gates.

The file bridge is not yet a packaged/provisioned extension bridge. Live
extension transport, secret onboarding, complete route acceptance, backend
authentication/model readiness, user-facing progress/review, restart/resume,
and user-present acceptance remain open. A clean scratch runtime run passed
21/21 bundles and 763/763 tests after placing the existing CommandLineTools
`Testing.framework` and interop library at the temporary test `@rpath`; the
repository runner still reports `AuraAudioTests` helper `exit 142` after its
assertions pass. Existing safety guidance requires approval before system
service intervention. ADR-041 is Proposed and must remain so until explicit
approval plus its implementation/evidence gate. The installed local VS Code
CLI remains `1.132.0` (`arm64`); no live extension command was executed.

## R7 status

R7 — Wake Word, STT/TTS Routing, and Resource Governor — is the active first-pass
prompt. The local slice now keeps production wake detection explicitly
Push-to-Talk-only until a real model qualifies; preserves exact audio frames by
sequence; routes between local Speech adapters only when their on-device
capability is real; adds bounded incomplete-turn continuation; makes system-TTS
interrupt/pause/resume operations real; bounds Chatterbox helper timeouts and
resource reservations; and records thermal/memory/circuit decisions through
`VoiceResourceGovernor`.

R7 is **not formally complete**. Real wake-word model/FAR-FR evidence, live
Turkish/English/mixed microphone WER/entity quality, user-present barge-in and
device/sleep/TCC recovery, measured 16 GB multi-workload soak, consented neural
reference/human quality, and explicit ADR-042 approval remain open. These gates
are recorded in [`SECOND_PASS_OPEN_GAPS.md`](../SECOND_PASS_OPEN_GAPS.md) for
future second-pass completion. R8 was started only after the user's explicit
continuation; R7's unresolved gates remain historical open gaps.

## R8 status

R8 — Memory, Personalization, and Explainability — was the preceding first-pass
prompt. Its local slice adds an explicit `MemoryWriteRequest` policy boundary,
purpose metadata with an additive SQLite migration, restart-safe bounded user
preference profiles, authority-ranked active-belief retrieval, visible
unresolved contradictions, provenance/budget/exclusion metadata, a bounded
classifier summary instead of raw transcript persistence, and local-only /
remote fail-closed context delivery.

Focused validation is green: `AuraMemoryTests` 30/30 and `AuraContextTests`
33/33. The full available regression is also green: 21/21 bundles and 782/782
tests, with runtime-completion validation and 13 governance tests passing under
`EV-R8-20260808-REGRESSION-03`. R8 is **not formally complete**. Production
reference-candidate wiring, user-present restart/multi-turn/ambiguity/
contradiction/control demonstrations, R9 UI controls, actual remote transport
exclusion evidence, and explicit ADR-043 acceptance remain open. Do not treat
local tests as live product acceptance.

## R9 status

R9 — Product UI, Accessibility, and Onboarding — was the delivered first-pass
prompt. The local slice replaces the single control panel with conversation,
durable task, capability/permission, model/voice, privacy/memory, and recovery
surfaces. It adds truthful health/degraded/disabled projections, staged
onboarding, persisted tab/language state, confirmation/emergency controls,
non-audit memory controls, and English/Turkish shell copy. `swift build
--target AURA` passed and the R9 reducer/localization/export tests passed 3/3
under `EV-R9-20260808-UI-BUILD-02` and
`EV-R9-20260808-UI-TESTS-03`, with final source evidence
`EV-R9-20260808-FAIL-CLOSED-06` and authorized delivery
`EV-R9-20260809-DELIVERY-07`.

R9 is **not formally complete**. User-present VoiceOver/keyboard/focus,
contrast/scaled-layout/reduced-motion, TCC denial/revocation, onboarding
restart/recovery, full task scope/review metadata, capability grant lifecycle,
model lifecycle, integrations/account controls, support bundles, and complete
privacy/recovery acceptance remain open in `SECOND_PASS_OPEN_GAPS.md`.

## R10 status

R10 — Security and Privilege Separation — was the preceding first-pass prompt
and remains `in_progress`.
The first bounded slice is now implemented and locally verified under
`EV-R10-20260809-BOUNDARY-SLICE-01`: versioned/hash-bound/replay-protected
helper envelopes, endpoint restrictions for the covered Ollama path, and
PKCE/state/Keychain expiry contracts. R10 remains `in_progress`: the pipe is
not authenticated XPC, helper executors are not wired, universal network
factory/DNS/provider enforcement is absent, OAuth transport and live revocation
are absent, and provenance/injection, plugin supply-chain, operations, and
independent-review gates remain open. R2-R9 remain `in_progress` and their
open gates are preserved. R11 was the preceding first-pass prompt.

## R11 status

R11 — Release Engineering and Continuous Operations — was the preceding prompt
after explicit user approval following R10 delivery. This was an edit-only
release-readiness pass. The repository currently has SwiftPM/ad-hoc or local
development signing preparation and design-only update/recovery documentation;
it does not have a verified Developer ID/notarized artifact, clean-machine
Gatekeeper evidence, signed updater, launch-at-login path, safe-mode/support
bundle/uninstall implementation, or observed release CI run. R9 and R10 remain
`in_progress`; their open gates are preserved and R11 cannot claim release
readiness from local contract tests alone.

## R12 status

R12 — Beta Validation and Release Candidate — was the preceding prompt. Its
blocked readiness contract exists, but no beta/RC gate passed. R11, R9, and
R10 open gates remain blockers and are preserved in `SECOND_PASS_OPEN_GAPS.md`.
ADR-047 is absent and was not invented.

## FINAL status

FINAL — Acceptance, Cleanup, and Operational Handoff — is active by explicit
user request despite the incomplete R12 dependency. This is an edit-only final
audit and maintainer-handoff pass. It cannot mark the program
`release_candidate_verified` or `released`; all failed gates are returned to
R2-R12 and recorded without deleting historical evidence.

## Why this program exists

AURA contains many implemented and tested subsystems, but they do not yet form one complete assistant. The primary deficit is integration and product truthfulness, not raw code volume.

The immediate program must:

1. repair repository/state truth;
2. create one correlated production orchestration spine;
3. connect bilingual NLU and real model-backed dialogue;
4. replace the closed five-intent router with a typed capability registry;
5. productize computer use;
6. add structured browser, mail, calendar, and contacts workflows;
7. complete VS Code and coding-agent product paths;
8. add real wake/STT/TTS routing and resource governance;
9. activate memory and explainability;
10. build the full assistant UI;
11. separate privileges and enforce network/secret boundaries;
12. create signed, notarized, updateable distribution;
13. prove beta reliability and final acceptance.

## Immediate next action

FINAL is the active acceptance/closeout prompt (in_progress) after explicit
user approval following the R12 first-pass slice. R2/R3/R4/R5/R6/R7/R8/R9/R10/R11/R12 remain open and all
deferred gates are recorded in [`SECOND_PASS_OPEN_GAPS.md`](../SECOND_PASS_OPEN_GAPS.md).
The edit-only FINAL/CLOSEOUT work is now recorded. The next concrete safe action is:

1. **Return to R11** for full-Xcode, signing/notarization, clean-machine,
   updater, recovery, migration, uninstall, and observed-CI evidence.
2. **Return to R12** for separately authorized beta consent, content-free
   telemetry/SLO/scenario/incident evidence, independent sign-offs, and a
   provenance-bound RC package.
3. **Rerun FINAL** only after those owning-track gates pass; do not enroll
   participants, activate telemetry, launch/install, publish, or deploy without
   separate explicit authority.

R2, R3, R4, R5, R6, R7, and R8 remain open — see the status sections above and
`SECOND_PASS_OPEN_GAPS.md`. Do not mark any of them
complete before their respective remaining items are resolved or explicitly
accepted. Do not start Phase 26 or any optional historical roadmap phase merely
because older prose names it as the next action.

FINAL is active by explicit user request. Do not mark FINAL complete,
`release_candidate_verified`, or `released`, accept ADR-047, or start session
closeout as successful until R11/R12 and all final acceptance gates have direct
proof.

## Current major risks

- live-model/hardware proof for the bilingual path;
- no durable confirmation checkpoint/resume after restart;
- universal capability-specific postcondition verification is incomplete;
- no production computer-use planner;
- VS Code policy not enforced in the adapter path;
- no live-wired browser/mail/calendar/contacts provider path;
- no real wake word;
- model memory/thermal contention on 16 GB hardware;
- main-process privilege concentration;
- no Developer ID notarized release or signed updater;
- no independent beta evidence.

## Compact success definition

AURA is complete only when a clean target Mac can install and run a bilingual assistant that understands natural speech/text, answers through a real reasoning backend, executes registered capabilities through policy and bound confirmation, verifies results, handles practical desktop/productivity/coding workflows, exposes memory/privacy/health controls, survives restart/update/recovery, and passes release and beta gates without false-success claims.
R12 now has a machine-readable blocked readiness contract, schema, validator,
focused negative tests, and runbook under `EV-R12-20260809-READINESS-CONTRACT-01`.
This remains static/contract evidence only; no beta or release-candidate gate
has passed.

## Repository-hygiene overlay — H-010 (2026-08-12)

H-010 remains active/blocked after explicit bounded `Sources/Tests` SwiftLint
remediation. Xcode 27.0 beta 5/SourceKit, strict swift-format, strict build,
and strict full tests pass. Full SwiftLint remains `exit 2` with 528 findings
across 112 files, and the canonical 21-bundle wrapper remains `exit 1` at
66.10% coverage against the unchanged 70% threshold. The original six-file
coverage scope was restored; no policy weakening or exclusion expansion was
accepted. Evidence: `EV-REPO-HYGIENE-H-010-SWIFTLINT-REMEDIATION-20260812-01`
and `EV-REPO-HYGIENE-H-010-CLOSEOUT-20260812-01`. H-011 does not exist; stop
at H-010 and do not claim global hygiene, product, or release completion.

## Repository-hygiene overlay — H-010 final local gates (2026-08-12T11:28:10Z)

The local H-010 blockers are resolved on feature commit
`de320a05ba9195b982e887e13c2116ba3698bc8a`: strict SwiftLint exits `0` with
zero violations in 1,066 files; strict formatter/build/full tests/fsck pass;
and the canonical wrapper exits `0` with 21/21 bundles, 795 tests, and 70.57%
coverage against the unchanged 70% threshold. The repository has zero
in-repository untracked paths. The 219 byte-identical copy artifacts are
preserved in recoverable external quarantine. Feature push is complete; the
later no-ff main push and final hosted-CI observation supersede the earlier
pending wording. Evidence:
`EV-REPO-HYGIENE-H-010-FINAL-20260812-01`. No H-011 exists.

The feature was merged no-ff and pushed to `main` at
`d0527d923d2ed02be3daf291e8181c900508a59a`; `HEAD == origin/main`, and the
state projections now point to that SHA. Hosted run `31592649228` was queued
for the merge SHA without completed steps; it is not a pass. The final
synchronized-main hosted result remains required.

The final hosted run `31593417301` for synchronized main projection
`d1e77129c607a40a209b5d1c5207cc83f38a5851` is queued with governance job
`94103274792` and no completed steps. GitHub reported no active self-hosted
runner at that historical timestamp. This observation is superseded by the
final hosted run below. Evidence:
`EV-REPO-HYGIENE-H-010-HOSTED-BLOCKED-20260812-01`.

## H-010 terminal hosted-CI closure — 2026-08-12T13:00:00Z

The previous empty-runner blocker is superseded by final hosted run
`31598491689` on `main` SHA `6d4d6da382cd94cd3ac006e26e6f0502eacb9ea8`.
Governance and build-and-test completed successfully: 38 governance tests,
all 21 Swift bundles, 70.59% coverage against 70%, valid
development-unverified manifest, and exactly two uploaded artifact files.
Artifact `9142197938` is retained for 14 days with digest
`69b0854b5bd4bf08ef4958053f280428933b5c45803cd74ba83092dcc3b6e1ae`.
The temporary runner was deregistered and the runner inventory is zero.

H-010 is complete for repository hygiene and is the manifest terminal prompt.
No H-011 exists. Product, beta, signing, release, deployment, live-hardware,
ADR-034/ADR-044, and FINAL acceptance remain independent and are not claimed
complete. Evidence: `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`.

## SP-001 post-fix dismissal update — 2026-08-15T09:32:18Z

The red AURA WindowGroup close path now records a pending confirmation as
`dismissed`; the focused integration test passed and the user-present rerun
recorded requested → dismissed → policy blocked with no `/bin/date` execution.
Evidence: `EV-SP-001-20260815-LIVE-DISMISSAL-07`. SP-001 remains blocked for
the remaining post-fix live matrix; authority remains bounded to the explicitly
authorized work and no SP-002 transition follows.

## SP-001 delivery closeout — 2026-08-15T09:45:50Z

The bounded source/evidence checkpoint was pushed and merged at `fd72707…`;
state pointers were reconciled in pushed projection commit `c14e39e`. Closeout
validators passed. SP-001 remains blocked for the remaining post-fix live
matrix, authority is reset to edit-only, and SP-002 remains unopened. Evidence:
`EV-SP-001-20260815-CLOSEOUT-09`.

## SP-001 residual live matrix — 2026-08-15T10:44:08Z

The current post-fix user-present bundle is recorded under
`EV-SP-001-20260815-LIVE-RESIDUAL-10`. It directly proves accepted safe
execution/verification, expiry, changed-plan supersession, replay deny/no
replay, concurrent-turn correlation isolation, truthful failed-result handling,
and reversible Calculator close with no-process verification. Emergency-stop
was exercised against a pending safe confirmation and prevented execution, but
the runtime emitted no distinct `confirmation.cancelled` terminal trace; the
request later expired and was policy-blocked. Therefore `SP-001` remains
blocked, authority is reset to edit-only, and `SP-002` must not begin.
## SP-001 OPEN-02 completion — 2026-08-15T11:17:34Z

The current unsigned bundle `/tmp/aura-sp001-live-cancel-20260815/AURA.app`
produced the missing redacted cancellation chain for a pending safe
`/bin/sleep 20` request: `confirmation.requested` → `confirmation.cancelled`
→ `policy intent.blocked`, with no execution. The same authorized run accepted
one reversible Calculator close, recorded `app.quit verified`, independently
found no Calculator process, and showed no replay after normal quit/reopen.
Evidence: `EV-SP-001-20260815-CANCELLATION-12`. `SP-001` is complete for
bounded `OPEN-02`; `SP-002` is next pending and unopened. First-pass R2–R12 and
FINAL remain independent open gates.
