# AURA Runtime Completion — Active Context

> **Program:** AURA Runtime Completion Program v1.0.0  
> **Current prompt:** `R5`
> **Current program state:** In progress; R1 completed, R2 in progress (deferred closeout), R3 in progress, R4 in progress, R5 in progress (user-directed parallel start)
> **Audited baseline:** `808cf64f1804fc9ba433ea5a85beedcdabeacdb2`

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
risks: `RISK-MISSING-PRODUCTIVITY-ADAPTERS` and `RISK-INDIRECT-PROMPT-INJECTION`.
ADR-040 is Proposed in `DECISION_REGISTER.md` but the file does not yet exist on
disk and must be authored before implementation.

**R5 is NOT complete.** No browser/mail/calendar/contacts adapters exist yet;
ADR-040 must be authored; and live acceptance requires explicitly authorized
test accounts/profiles.

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

R5 is the active prompt (in_progress), started by user-directed deviation while
R2/R3/R4 remain open. The next concrete R5 work, in dependency order:

1. **Author ADR-040** (`docs/decisions/ADR-040-productivity-integrations-oauth.md`
   — Proposed in `DECISION_REGISTER.md` but the file does not yet exist on
   disk) and record it, defining the browser/mail/calendar/contacts
   least-privilege OAuth/Keychain trust boundaries.
2. **Build read-first browser/mail/calendar/contacts adapters** with
   least-privilege OAuth scopes and Keychain token references.
3. **Add injection resistance and offline/degraded behavior** (provenance
   tagging, content isolation, sanitized model context, adversarial fixtures).
4. **Run live acceptance** with explicitly authorized test accounts/profiles.

R4, R3, and R2 remain open (deferred/parallel) — see the R2 closeout status, R3
status, and R4 status sections above. Do not mark R2, R3, R4, or R5 complete
before their respective remaining items are resolved or explicitly accepted. Do
not start Phase 26 or any optional historical roadmap phase merely because older
prose names it as the next action.

## Current major risks

- live-model/hardware proof for the bilingual path;
- no durable confirmation checkpoint/resume after restart;
- universal capability-specific postcondition verification is incomplete;
- no production computer-use planner;
- VS Code policy not enforced in the adapter path;
- no browser/mail/calendar/contacts adapters;
- no real wake word;
- model memory/thermal contention on 16 GB hardware;
- main-process privilege concentration;
- no Developer ID notarized release or signed updater;
- no independent beta evidence.

## Compact success definition

AURA is complete only when a clean target Mac can install and run a bilingual assistant that understands natural speech/text, answers through a real reasoning backend, executes registered capabilities through policy and bound confirmation, verifies results, handles practical desktop/productivity/coding workflows, exposes memory/privacy/health controls, survives restart/update/recovery, and passes release and beta gates without false-success claims.
