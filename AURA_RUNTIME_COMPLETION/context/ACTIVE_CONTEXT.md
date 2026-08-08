# AURA Runtime Completion — Active Context

> **Program:** AURA Runtime Completion Program v1.0.0  
> **Current prompt:** `R7`
> **Current program state:** In progress; R1 completed, R2/R3/R4/R5/R6 remain open, R7 active after a user-directed transition
> **Audited baseline:** `daf062aefc8b2eaa516769fdf27e6fc816111002` on `main` (`HEAD == origin/main`; working tree intentionally dirty)

## Canonical status

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
browser/mail/calendar/contacts adapters was started by user-directed deviation
while R2/R3/R4 remain in_progress.

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
future second-pass completion. After authorized R7 delivery, stop and request
explicit user approval before R8.

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

R6 is the active prompt (in_progress) after the user-directed R5 transition.
R5 remains open and all R2/R3/R4/R5 deferred gates are recorded in
[`SECOND_PASS_OPEN_GAPS.md`](../SECOND_PASS_OPEN_GAPS.md). The next concrete R6
work, in dependency order:

1. **Package and provision the authenticated extension bridge** while retaining
   the existing fail-closed policy gate and bounded envelope contract.
2. **Complete live typed workspace/task/test/agent routes** with durable,
   isolated, reviewable write flows; repair the host test-runner framework path;
   then run the R6 live acceptance gate.

R5, R4, R3, and R2 remain open (deferred/parallel) — see the status sections
above and `SECOND_PASS_OPEN_GAPS.md`. Do not mark R2, R3, R4, R5, or R6
complete before their respective remaining items are resolved or explicitly
accepted. Do not start Phase 26 or any optional historical roadmap phase merely
because older prose names it as the next action.

After R7's commit/push/merge delivery, stop and obtain explicit user approval
before moving to R8.

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
