# AURA Runtime Completion — Active Context

> **Program:** AURA Runtime Completion Program v1.0.0  
> **Current prompt:** `FINAL`
> **Current program state:** In progress; R1 completed, R2/R3/R4/R5/R6/R7/R8/R9/R10/R11/R12 remain open, FINAL active for blocked acceptance and closeout audit
> **Live repository:** `repo-hygiene/h010-swiftlint-remediation-20260812` at current projection base `63f1e67bf1457e53d07cf282d8b4af1bcc33cba5`; the delivery branch is pending push/merge, and the latest full hosted-CI verification remains the prior projection-only parent `a20617302591628c704a6cf099f4c18b0525c80b` (merge base `68a6b6730334a5b0175ba5f4c2c271699b8ae146`); PR #2 is merged
> **Audited content baseline:** `47775180c224f87fa5a58703f793515ffcb2c35c` under ADR-045 (projection-only descendants are not new product audits)

## Canonical status

## Repository hygiene overlay

The repository-hygiene program is a separate, synchronized control overlay at
`docs/operations/REPO_HYGIENE_PROGRAM.md`. Its machine state is
`AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json`, currently
`H-010` / `blocked`; its 11-prompt manifest, focused ledger, contracts,
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
and the 21-bundle/794-test wrapper pass. SwiftLint 0.65.0 is provisioned and now loads SourceKit under the selected Xcode toolchain, but its strict policy run exits 2 with 1,330 serious findings across 628 files. H-005 was delivered and is complete
for chain order; H-006 is complete under exact `ONAY: H-006`, with
`EV-REPO-HYGIENE-H-006-20260810-01` recording the bounded unsafe/debug audit,
strict build, focused tests, and cognitive gate. H-007 is complete for chain
order and H-008 is complete after its verified delivery. H-009 is complete for
chain-order purposes after its bounded context summary and architecture audit
were synchronized. H-010 ran the final gate and is blocked on explicit
evidence-backed limitations. The raw all-source matrix is
65.15%, while the explicit four-file host-boundary scope passes at 70.02%
against the unchanged 70% ratchet. H-007 edit-only authority expired at
closeout; no standing cleanup/deletion/quarantine authority remains. H-009 was
started under exact `ONAY: H-009`: its source-of-truth map, bounded context
summary, package/dependency audit, and privileged-boundary audit are recorded
under `EV-REPO-HYGIENE-H-009-20260810-01` and
`EV-REPO-HYGIENE-H-010-20260810-01`; the six H-008 duplicate backups remain
SHA-validated in the recoverable quarantine
`/Users/m_ras/Desktop/AURA-H008-QUARANTINE-20260810`. H-010 is blocked; the
original damaged database is preserved for rollback, while Xcode/SourceKit
capability and wrapper discovery are now resolved. The strict full SwiftLint
policy still exits 2 with 1,330 serious findings across 628 files. Merged-main hosted CI is observed and passing
under `EV-REPO-HYGIENE-MAIN-CI-FINAL-20260811-01`; current formatter, lock-graph
vulnerability/SBOM, and local validator gates pass. No H-011 exists and no
automatic transition is permitted.

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
capability is resolved, but the strict full SwiftLint policy remains blocked by
1,330 owned findings and H-010 remains blocked. No H-011 exists.

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
`SP-000` / `pending`. Its manifest, gap register, Tier-0/Tier-1 context order,
focused append-only ledger, prompt contract, and validator must agree before
any second-pass prompt can run. This overlay does not overwrite the first-pass
canonical state above: first-pass `FINAL` remains blocked, while second-pass
`SP-000` is the only prompt eligible for an explicitly authorized start.

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
