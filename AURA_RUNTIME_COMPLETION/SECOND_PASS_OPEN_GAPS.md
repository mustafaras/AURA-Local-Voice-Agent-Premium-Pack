# AURA Second-Pass Open Gaps

**Status:** Open tracking record; these items are intentionally not closed.
**Recorded:** 2026-08-09; full 0–15 audit `EV-OPEN-GAPS-20260809-FULL-AUDIT-01`
**Authority:** `AURA_RUNTIME_COMPLETION/state/current-state.json`, the active prompt files, and the append-only program/project ledgers.

This document is the canonical handoff list for incomplete gates deferred to a
second implementation pass. An item may be marked complete only after its
own prompt gate, evidence requirement, and relevant live acceptance have
actually passed. Local unit or contract tests do not close a live gate.

## Synchronized second-pass control plane

The open-gap register is deliberately coupled to the anti-amnesia context,
machine state, prompt manifest, focused ledger, and validator below. These are
projections of one chain, not independent checklists:

- **Gap truth:** this file, `SECOND_PASS_OPEN_GAPS.md`.
- **Execution order:** [`SECOND_PASS_PROMPT_MANIFEST.json`](second-pass/SECOND_PASS_PROMPT_MANIFEST.json).
- **Active state:** [`SECOND_PASS_STATE.json`](second-pass/SECOND_PASS_STATE.json), currently `SP-000` / `pending`.
- **Prompt contract:** [`SECOND_PASS_PROMPT_CONTRACT.md`](second-pass/SECOND_PASS_PROMPT_CONTRACT.md).
- **Control invariants:** [`SECOND_PASS_CONTROL_CONTRACT.md`](second-pass/SECOND_PASS_CONTROL_CONTRACT.md).
- **Tiered context:** [`SECOND_PASS_READ_FIRST.md`](context/SECOND_PASS_READ_FIRST.md).
- **Focused append-only ledger:** [`SECOND_PASS_LEDGER.md`](second-pass/SECOND_PASS_LEDGER.md).
- **Human chain index:** [`SECOND_PASS_PROMPT_PROGRAM.md`](SECOND_PASS_PROMPT_PROGRAM.md).
- **Machine validator:** `scripts/validate_second_pass_program.py`.

The manifest contains 34 prompts (`SP-000` through `SP-033`). A prompt may
only become `completed` when its named `OPEN-*` item is objectively resolved,
its cognitive completion questions and evidence are recorded, every required
projection is synchronized, and the validator passes. If any projection
disagrees, the active prompt remains blocked/in progress and the next prompt
cannot start. The mandatory `15_SESSION_CLOSEOUT.prompt.md` procedure remains
required after every attempt.

## Full 0–15 audit verdict

This audit reconciles all ordered prompts in `prompt-manifest.json`, the
mandatory out-of-manifest session-closeout procedure, `current-state.json`,
the capability/evidence/risk registers, both ledgers, the existing open-gap
entries, and the relevant source/test/ADR surfaces. The live repository
relation at audit start is `HEAD == origin/main ==
e1004795e56df8c171422261eace96543649cf51`; the worktree is
`dirty_expected` because the first-pass state and release-readiness records are
local.

The result is intentionally conservative:

- BOOTSTRAP and R0 are complete for repository-governance scope.
- R1 is complete for the recorded development/integration scope, but its
  prompt-level user-present live demonstration and universal postcondition
  evidence remain final cross-track prerequisites.
- R2–R12 remain `in_progress`; R12 is blocked by missing R11 and beta/RC
  evidence. FINAL remains `in_progress`/blocked and cannot claim a release
  candidate or release.
- Prompt 15 is mandatory after every step and is a procedure, not a product
  track. The previous closeout is recorded, but every future edit must produce
  a new closeout record.
- No item below is closed by source existence, an ADR draft, a fake/simulated
  boundary, a local test, or a statically valid workflow alone.

## Prompt-by-prompt status matrix

| Order | Prompt | Live status | Unapplied completion scope | Depends on / owner | Closure evidence required |
|---:|---|---|---|---|---|
| 00 | BOOTSTRAP | `completed` | No new product gap; revalidate live state, authority, manifest, schemas, and dirty-file ownership at every resumed session. | None / session owner | Fresh repository/state/schema/manifest/toolchain evidence and closeout |
| 01 | R0 | `completed` | Governance gate is met for the recorded scope. The unobserved CI run and full-Xcode limitation are forwarded to R11, not silently treated as R0 proof. | BOOTSTRAP / governance owner | Validator, capability audit, toolchain, legacy-pointer and CI-configuration evidence |
| 02 | R1 | `completed` for development/integration scope | User-present safe observation + reversible mutation trace, confirmation denial/expiry, and universal capability postcondition coverage remain open before full product closure. | R0 / runtime owner | Authorized live trace, execution/verification pair, confirmation behavior, regression |
| 03 | R2 | `in_progress` | Real microphone/TCC Push-to-Talk gate and seven Turkish/English/mixed live scenarios; review accepted model-variance risk before external beta. | R1 / dialogue owner | Live voice and 7-scenario evidence, bounded model-quality decision |
| 04 | R3 | `in_progress` | Filesystem/URL adapters, NLU/UI reachability, automatic planner-to-dialogue wiring, and seven-scenario demonstration. | R2 / capability owner | Registry/health inspection, natural-language plan traces, live scenarios |
| 05 | R4 | `in_progress` | Live planner/allowlist execution in at least three approved apps with permissions, semantic verification, injection refusal, confirmation and emergency-stop evidence. | R3 / computer-use owner | Redacted live beta-app evidence bundle |
| 06 | R5 | `in_progress` | Packaged/authenticated browser bridge, provider/account transport, composition/UI reachability, revocation/degraded/injection acceptance, and separately gated mutation/send flows. | R3; R4 fallback / productivity owner | Authorized test-account live evidence and post-action verification |
| 07 | R6 | `in_progress` | Real authenticated extension transport, live workspace routes, backend readiness/auth/model/cancellation/budget checks, durable task restart/resume, and user-present acceptance. | R3 / coding-agent owner | Extension/backend/task evidence with no unauthorized delivery |
| 08 | R7 | `in_progress` | Wake-word qualification or explicit exclusion, bilingual STT quality, barge-in/echo/device recovery, 16 GB soak, neural-TTS qualification or system-TTS-only scope, ADR-042. | R2 / voice owner | Live audio dataset/protocol, hardware/recovery/soak evidence |
| 09 | R8 | `in_progress` | Production reference-candidate wiring, live restart/reference/conflict/control demonstrations, actual remote-boundary evidence if enabled, and ADR-043. | R2 + R3 / memory owner | User-present product evidence and privacy-safe transport evidence |
| 10 | R9 | `in_progress` | Manual VoiceOver/keyboard/layout/localization pass, full task/capability/model/privacy/recovery controls, onboarding denial/restart, and support/recovery UX. | R4–R8 / UI owner | Clean/configured profile accessibility and usability evidence |
| 11 | R10 | `in_progress` | Authenticated peer boundary/real helper execution, all-network-path enforcement, OAuth lifecycle, plugin trust, injection corpus, incident response, independent review, ADR-044. | R4–R6 and R9 surfaces / security owner | Adversarial, independent-review, and production-boundary evidence |
| 12 | R11 | `in_progress` | Full-Xcode reproducible release artifact, observed CI, Developer ID/notarization/Gatekeeper, launch-at-login, updater/rollback, recovery/migration/uninstall/support bundle. | R9 + R10 / release owner | Release-class clean-machine and CI evidence, ADR-046 |
| 13 | R12 | `in_progress`/blocked | Approved cohort/consent, content-free telemetry, SLO/scenario/incident results, independent sign-offs, and provenance-bound RC package. | R11 / beta owner | Authorized beta evidence, SLO report, sign-offs, RC approval, ADR-047 |
| 14 | FINAL | `in_progress`/blocked | Full capability acceptance, clean-Mac E2E, security/privacy review, documentation cleanup, state closure, and operational handoff. | R12 / release owner | All mandatory evidence and explicit release authority |
| 15 | SESSION CLOSEOUT | mandatory procedure | No product gap; must be rerun after every implementation/audit session with exact branch, commit, files, tests, evidence, blockers, authority, and next action. | Every order / session owner | New append-only ledger/evidence/state/handoff validation |

## Ordered closure algorithm

The following is the only safe order for closing the remaining work. The
historical out-of-order transitions remain recorded; this plan governs the
second-pass closure sequence.

1. **S00 — Reconcile baseline.** Run BOOTSTRAP/R0 validation against live
   `HEAD`, remote, worktree, authority, schemas, manifest, capability matrix,
   evidence/risk/decision references, and toolchain. Preserve unrelated dirty
   files. If any projection differs, repair state first and stop.
2. **S01 — Close R1 live residuals.** With explicit user-present authority,
   capture one safe observation, one reversible mutation requiring confirmation,
   execution/verification states, spoken/visual truthful result, and denied or
   expired confirmation. Resolve the durable-confirmation policy as
   fail-closed or explicitly accepted; do not broaden R1 from local evidence.
3. **S02 — Close R2.** Verify microphone/TCC Push-to-Talk, then run the seven
   Turkish/English/mixed scenarios with trace, language, model, clarification,
   latency, and degradation evidence. Keep raw audio/model output out of
   ledgers. Re-evaluate the accepted local-model variance before external beta.
4. **S03 — Close R3.** Implement and test the filesystem/URL adapters, expose
   the currently direct-call-only capabilities through NLU/UI, wire typed
   multi-step planning into production dialogue, and run the seven R3
   scenarios. Every unavailable capability remains visibly disabled.
5. **S04–S08 — Close R4, R5, R6, R7, and R8 in dependency-safe parallel
   tracks.** Each track must first finish its local contract/test work, then
   its live/manual evidence, then its ADR and state transition. R4–R8 cannot
   borrow another track's local tests as live proof.
6. **S09 — Close R9.** After R4–R8 evidence is available, run clean and
   configured profiles through Turkish and English UI, VoiceOver, keyboard,
   Dynamic Type/scaled layout, permissions denied/revoked, offline/no-model,
   task failure, confirmation, emergency stop, and recovery. Wire only
   capabilities that have truthful health and authority states.
7. **S10 — Close R10.** Complete the authenticated process boundary, real
   helper execution, mandatory network-client audit, OAuth/provider lifecycle,
   plugin trust/update, injection corpus, incident response, and independent
   security review. No external-beta claim is allowed while a critical finding
   is open or ADR-044 is only Proposed.
8. **S11 — Close R11.** On an authorized full-Xcode/CI environment, build a
   reproducible nested-signed artifact, notarize/staple it, validate Gatekeeper
   on a clean Mac, and exercise launch-at-login, update/rollback, recovery,
   migration, low-disk/corrupt-artifact, support-bundle, uninstall, and factory
   reset. The local `development_unverified` ZIP is not a substitute.
9. **S12 — Close R12.** Only after R11 passes, obtain authorized beta scope,
   consent, privacy notice, kill-switch owner, opt-in content-free telemetry,
   SLO definitions, scenario matrix, incident process, independent sign-offs,
   and the approved RC package. Keep experimental capabilities excluded unless
   their own gates passed.
10. **S13 — Run FINAL.** Reconcile all capability claims against evidence,
    perform clean end-to-end acceptance, review security/privacy/support
    artifacts, remove only genuinely stale scaffolding, and set
    `release_candidate_verified` or `released` only with direct evidence and
    explicit authority.
11. **S14 — Run SESSION CLOSEOUT.** Append the phase result, including blocked
    results, update state/handoff/evidence/risk/decision references, validate
    every closure artifact, and state the exact next prompt. This step is
    mandatory after every earlier step as well.

## Closure record format

Every numbered item below is closed only when its acceptance evidence is
appended to `EVIDENCE_INDEX.md`, its residual risks are updated in
`RISK_REGISTER.md`, its status is reflected in `current-state.json`, and the
relevant runtime and project ledgers receive an append-only entry. Each live
item must include the user/account/hardware authority, exact procedure,
timestamp, result, artifact path/hash where relevant, and limitations.

## OPEN-00 — BOOTSTRAP revalidation

Status: no unresolved bootstrap implementation gap. On every resumed session:

1. Verify branch, `HEAD`, `origin/main`, worktree and user-owned files.
2. Validate state, handoff, manifest, schemas, evidence/risk/decision refs and
   toolchain without installing anything unless authorized.
3. Record authority and exact next prompt before editing.

The existing BOOTSTRAP evidence proves the historical baseline only; it does
not make later live gates pass.

SP-000 closeout: the resumed baseline was revalidated at live
`main`/`origin/main` `05af25de7d0e21a5fff114a7fb2cba083009a923`; the active
second-pass state, handoff, context, manifest, gap register, and validator
now agree on `SP-001` / `pending`. This closes the baseline-lock objective
only; it does not close product or live acceptance gates. Evidence:
`EV-SP-000-20260813-BASELINE-01`.

## OPEN-01 — R0 governance residual boundary

Status: R0 governance gate passed for its bounded scope. Preserve these
forwarded items as R11 evidence requirements rather than claiming they are
R0 failures:

1. Observe a real CI run separately from local workflow parsing.
2. Keep the CommandLineTools/full-Xcode limitation explicit until R11 proves
   the release toolchain.
3. Re-run the fail-closed validator after every state or capability change.

SP-000 closeout: the runtime-completion, hygiene, supply-chain, and
second-pass validators passed after the pointer reconciliation; the
second-pass validator now derives its handoff/context expectation from the
active state instead of hard-coding `SP-000/pending`. The forwarded R11 and
release-toolchain limitations remain unchanged. Evidence:
`EV-SP-000-20260813-BASELINE-01`.

## OPEN-02 — R1 live trace residuals

1. Run the authorized user-present observation/reversible-mutation demo with a
   complete correlated trace and displayed confirmation.
2. Prove allow executes exactly once; deny, timeout, dismissal, replay,
   restart, and changed-plan cases do not execute.
3. Capture distinct execution and verification outcomes, including failed
   verification reported as failure rather than success.
4. Confirm cancellation and concurrent-turn isolation on the live path.

R1 remains marked completed only for the recorded development/integration
scope; these items are prerequisites for the program-wide final gate.

### SP-001 attempt — 2026-08-14T07:06:42Z

`SP-001` remains **blocked**, not completed. The prompt-relevant AuraCore,
AuraPolicy, AURAIntegration, AuraAgent, and AuraAudio suites passed (316 tests
total), but those deterministic/integration results are not the required live
target-Mac evidence. The prompt's hard boundary does not authorize app
launch/install, so no user-present displayed confirmation, reversible mutation,
correlated live execution/verification trace, or live deny/timeout/dismissal/
restart bundle was captured. No denied action was executed and no product file
was changed. Evidence: `EV-SP-001-20260814-ATTEMPT-01`. Obtain explicit
target-Mac/app-launch authority and retry only `SP-001`; do not advance to
`SP-002`.

### SP-001 authorized live attempt — 2026-08-14T08:44:20Z

The user then explicitly authorized local AURA launch and one safe/reversible
mutation. The direct live bundle is recorded as
`EV-SP-001-20260814-LIVE-TRACE-03` with redacted artifact
`AURA_RUNTIME_COMPLETION/state/EV-SP-001-20260814-LIVE-TRACE-03.md` (SHA-256
`74ce3d9b5073a6fa4fef5aa011f5ad2917fe12e302e7908cb93faa066a066855`). A local
unsigned bundle was launched with `/usr/bin/open`; no installation, TCC
mutation, dependency/model/provider, signing, release, deploy, commit, push,
or merge action occurred.

The user-present speech observation was visible and truthful. A read-only
`/bin/date` request was allowed once. A repeated request was denied and showed
`Blocked: confirmationDenied`. A manually opened Calculator was terminated
through a displayed `app.terminate` confirmation; the UI reported
`Quit com.apple.calculator.` and a read-only process check returned
`NOT_RUNNING`. An untouched confirmation disappeared without an execution
result; the UI ended at `thinking timeout`, so no side effect was observed but
the label is not an explicit confirmation-timeout result. Submitting a new
`pwd` plan while the prior date flow was active blocked the prior flow and no
`pwd` success appeared. Emergency-stop/re-arm and app quit/reopen were
observed; after restart the conversation was empty and no old confirmation was
present.

This reduces the live safety residual, but does not close it. The live UI did
not expose a redacted correlation/causation ID, the in-memory event bus did not
provide a durable event-chain artifact, and a distinct UI dismissal,
failed-verification, and concurrent-turn-isolation trace was not captured.
Therefore `SP-001` remains **blocked**, `OPEN-02` remains open, and `SP-002`
must not start. Preserve the prior attempt wording above as historical
record; this entry is its authorized live successor, not a deletion or rewrite.

### SP-001 source-side mitigation — 2026-08-14T11:11:19Z

The narrowly authorized source/test correction is recorded as
`EV-SP-001-20260814-TRACE-FIX-04`. A dedicated redacted trace projection now
persists correlation/causation/request/action/outcome fields in
`redacted_trace_records`; raw prompt, transcript, command-argument, output,
screenshot, audio, nonce, and plan-hash data are excluded. Confirmation
requested/accepted/denied/expired/dismissed/superseded outcomes and tool/policy
outcomes are projected into the local store, and short opaque trace prefixes
are displayed in confirmation and conversation UI. Core/store/integration and
the prompt-relevant Policy/Agent/Audio suites pass, as do the local governance
validators.

This mitigates the source-side residual but does not close `OPEN-02`: no live
target-Mac rerun was authorized in this source-only attempt. The direct live
bundle still requires independently captureable UI/store trace evidence plus
distinct failed-verification, concurrent-turn-isolation, timeout, and
dismissal cases. `SP-001` remains **blocked** and `SP-002` must not start.
The original live-attempt wording above remains historical and is not deleted
or rewritten.

### SP-001 post-fix bounded live rerun — 2026-08-14T12:10:25Z

The user-present rerun is recorded as
`EV-SP-001-20260814-LIVE-TRACE-FIX-05`. The current local build displayed
opaque trace prefixes in confirmation and result rows. The live evidence and a
read-only local store query prove `/bin/date` allow, repeated-date deny,
Calculator confirmation expiry, one fresh allowed Calculator close, distinct
execution/verification, and no running Calculator process. The redacted store
contains the matching requested/accepted/denied/expired/verified sequences and
does not receive raw event payloads.

This bounded rerun reduces the residual substantially but does not close
`OPEN-02`: the user’s authority covered only date and one Calculator mutation,
so post-fix changed-plan, replay, dismissal, cancellation, and concurrent-turn
cases were not rerun. Prior live evidence covers some pre-fix cases, but it is
not promoted to post-fix proof. `SP-001` remains **blocked** and `SP-002` must
not start until the complete post-fix matrix is separately authorized and
captured.

### SP-001 post-fix dismissal wiring — 2026-08-15T09:32:18Z

The red close path initially closed the WindowGroup without reaching the
application-menu `quit()` method, so no `confirmation.dismissed` row was
persisted. A narrow WindowGroup `onDisappear` hook now resolves only an
existing pending confirmation as `dismissed`; the focused integration test
passed. The user-present rerun on the updated local build produced matching
redacted `confirmation.requested` → `confirmation.dismissed` → `policy
intent.blocked` rows and no `/bin/date` execution. Evidence:
`EV-SP-001-20260815-LIVE-DISMISSAL-07`.

This closes the post-fix dismissal sub-residual only. Changed-plan, replay,
cancellation, concurrent-turn isolation, and required failed-verification
evidence remain open; `SP-001` remains blocked and `SP-002` must not start.

## OPEN-03 — R2: Bilingual NLU and Dialogue

Prompt: [`03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md`](archive/first-pass-prompts/2026-08-12/03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md)

- Perform the user-present microphone/TCC Push-to-Talk verification and record
  `EV-R2-20260804-LIVE-VOICE-DEMO-01`.
- Perform the required seven-scenario Turkish/English/mixed-language live
  completion demonstration and record
  `EV-R2-20260804-LIVE-7SCENARIO-01`.
- Keep `RISK-STT-MIC-NOT-CAPTURING` open until hardware evidence passes and
  `RISK-ENGLISH-ONLY-INTENT` mitigating until the live scenario gate passes.
- Do not treat local model, text-demo, or unit/integration evidence as a
  substitute for the user-present hardware gate.

## OPEN-04 — R3: Capability Registry and Typed Planner

Prompt: [`04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`](archive/first-pass-prompts/2026-08-12/04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md)

- Build the remaining filesystem and URL adapters.
- Add NLU/UI reachability for the four capabilities that currently have only
  direct-call reachability.
- Wire the typed planner into `DialogueEngine`/`ToolRouter` for real
  multi-step natural-language plans.
- Run and record the required seven-scenario live completion demonstration.
- Preserve truthful registry state; unavailable capabilities remain disabled.

## OPEN-05 — R4: Computer-Use Productization

Prompt: [`05_R4_COMPUTER_USE_PRODUCTIZATION.prompt.md`](archive/first-pass-prompts/2026-08-12/05_R4_COMPUTER_USE_PRODUCTIZATION.prompt.md)

- Keep `computerUse.run` disabled until explicit live validation authorizes
  the approved applications.
- With the user physically present, run safe tasks in at least three approved
  beta applications with Accessibility and Screen Recording permissions.
- Capture live confirmation, emergency-stop, modal/secure-field/no-progress,
  and screen-content prompt-injection evidence.
- Verify semantic postconditions and ensure no push, merge, release, or deploy
  occurs without separate authority.
- Close `RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` only after the live gate and
  its evidence bundle pass.

## OPEN-06 — R5: Browser, Mail, Calendar, and Contacts Adapters

Prompt: [`06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md`](archive/first-pass-prompts/2026-08-12/06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md)

The deterministic first slice is recorded by
`EV-R5-20260808-READ-FIRST-ADAPTERS-01`, but R5 remains `in_progress`.

- Package and authenticate the Safari Web Extension/native messaging bridge;
  the current Swift bridge is a structured contract, not a live extension.
- Add real provider transports and explicitly authorized account/profile
  onboarding.
- Wire browser/mail/calendar/contacts through `AuraKernel`, Dialogue, and UI
  reachability while keeping the four manifests disabled until verified.
- Run live offline/degraded, permission, account ambiguity, revocation, and
  injection-acceptance tests with the user present where required.
- Keep compose/send, calendar/contact mutation, and any OAuth scope escalation
  behind separate immutable confirmation, least-privilege escalation, and
  post-action verification gates.
- Do not mark R5 complete based only on `AuraProductivityTests` or the full
  local Swift regression.

## OPEN-07 — R6: VS Code and Coding-Agent Completion

Prompt: [`07_R6_VSCODE_AND_CODING_AGENTS.prompt.md`](archive/first-pass-prompts/2026-08-12/07_R6_VSCODE_AND_CODING_AGENTS.prompt.md)

R6's first-pass implementation is recorded by
`EV-R6-20260808-POLICY-BRIDGE-01` and
`EV-R6-20260808-TYPED-ROUTES-02`; the items below are preserved for the future
second pass and do not close the R6 prompt gate.

- Complete and provision the real authenticated VS Code extension transport;
  the current file bridge is a bounded local contract and has no live extension
  package or shared-secret onboarding evidence.
- Connect the typed workspace/editor/diagnostics/task/test/terminal routes to a
  real extension and verify disconnect, version mismatch, stale state, dirty
  buffers, and user confirmation behavior on the live path.
- Complete the coding-agent backend gate for exact interface/version,
  authentication, model availability, sandbox/approval, cancellation,
  network, workspace, cost/time/file budgets, and actionable disabled states.
- Exercise durable read-only, review-only, and write-capable flows with
  explicit workspace resolution, isolated worktrees, progress/checkpoints,
  cancellation, restart/resume, diff/test/evidence verification, and cleanup.
- Keep the repository-wide test gate honest: the clean scratch SwiftPM run
  passed 21/21 bundles and 763/763 tests after placing the existing
  CommandLineTools `Testing.framework` and interop library in the temporary
  scratch `@rpath`; the repository runner still reports `AuraAudioTests`
  helper `exit 142` after its assertions pass. Existing safety guidance
  requires approval before any system-service intervention. Do not convert
  that unrelated audio limitation into a false R6 product claim.
- Run the required user-present live acceptance, including no unauthorized
  commit/push/merge/release/deploy, before closing R6 or accepting ADR-041.

## OPEN-08 — R7: Wake Word, STT/TTS Routing, and Resource Governor

Prompt: [`08_R7_VOICE_WAKE_STT_TTS_RESOURCE_GOVERNOR.prompt.md`](archive/first-pass-prompts/2026-08-12/08_R7_VOICE_WAKE_STT_TTS_RESOURCE_GOVERNOR.prompt.md)

R7's first local implementation slice is recorded from the first pass;
the unresolved gates below are recorded for the future second pass as required
by the per-prompt workflow. The slice is not a substitute for live acceptance
or ADR-042 approval.

- A real licensed/local wake-word candidate has not been selected or qualified.
  Production remains explicitly Push-to-Talk-only through
  `DisabledWakeWordDetector`; the marker detector remains test-only. FAR/FRR,
  Turkish support, noise/distance, self-trigger, energy, debounce, privacy,
  model hash/license, and soak evidence remain open.
- Apple on-device Speech capability checks and the reusable STT router are
  implemented, but there is no live Turkish/English/mixed-language WER/entity
  corpus, qualified local Whisper/equivalent fallback, or user-present
  microphone/TCC acceptance. Locale fallback is fail-closed on engine start,
  not a silently quality-switching transcript rewrite.
- Bounded incomplete-turn continuation, duplicate-result suppression, and
  TTS interruption/cancellation paths are covered locally, but live barge-in,
  acoustic echo/self-transcription, headset/device switching, sleep/wake,
  interruption, permission revocation, and helper-crash recovery remain
  unverified on release hardware.
- Resource admission is integrated for STT and neural TTS with memory-pressure,
  thermal, budget, reservation, and circuit-breaker controls. NLU/reasoning,
  screen, and coding workloads are not yet admitted through the governor, and
  measured 16 GB resident-memory/thermal/energy/long-soak evidence is open.
- Neural TTS has a bounded helper timeout and system-Yelda fallback; CPU is
  the safe default and MPS is opt-in pending qualification. Consented
  reference-voice provenance, model/hash/license verification, first-audio
  latency, CPU quality/latency, cache safety, and human listening acceptance
  remain open. System-TTS-only release remains the truthful fallback scope.
- The required Turkish/English/mixed technical/noisy/far-field evaluation
  datasets and protocols, latency/WER/entity/turn-end/TTS/barge-in/resource
  measurements, and extended soak package are not yet recorded.
- ADR-042 remains `Proposed`; its full context/alternatives/consequences and
  explicit user acceptance are not recorded. Do not mark R7 complete or move
  to R8 based on simulated tests alone.

## OPEN-09 — R8: Memory, Personalization, and Explainability

Prompt: [`09_R8_MEMORY_PERSONALIZATION_EXPLAINABILITY.prompt.md`](archive/first-pass-prompts/2026-08-12/09_R8_MEMORY_PERSONALIZATION_EXPLAINABILITY.prompt.md)

R8's local first-pass slice is implemented and focused-tested under
`EV-R8-20260808-MEMORY-POLICY-01` and
`EV-R8-20260808-CONTEXT-PRODUCT-02`; the full local regression and governance
gate passed under `EV-R8-20260808-REGRESSION-03`. R8 nevertheless remains
`in_progress`. The local contracts do not replace the required product, live,
or decision-acceptance gates.

- A user-present restart-safe preference demonstration has not been run through
  the launched application; the second-store-handle test proves persistence
  only at the subsystem/integration level.
- Production reference-candidate population is incomplete. Resolver and
  ContextBuilder contracts exist, but the full salience/tool candidate assembly
  is not yet wired for multi-turn references such as “that repo”, “last file”,
  “previous test”, “ask Claude”, or “send the draft”. Ambiguous or destructive
  references must still clarify and require the real policy/confirmation path.
- Authority-ranked active beliefs and unresolved contradiction surfacing are
  implemented and tested, but all conflict classes, supersession outcomes, and
  user correction behavior lack a user-present product demonstration.
- Search, browse, correct, supersede, delete, and export controls are not yet
  exposed through the R9 user interface; audit/security retention and
  user-visible explainability acceptance remain open.
- Purpose, provenance, sensitivity, token budget, exclusions, and local-only
  remote fail-closed delivery are tested. No actual remote transport/provider
  evidence exists; a separately redacted and user-approved remote-summary path
  must not be inferred from the current fail-closed behavior.
- Poisoning, secret-like input, raw/model/untrusted write rejection, and local
  policy non-weakening have local evidence, but there is no end-to-end live
  model/tool material-improvement, latency/soak, or privacy-audit package.
- ADR-043 remains `Proposed`; explicit user acceptance and the R8 completion
  gate are still required. R9 was started by explicit user continuation; this
  R8 entry remains historical and does not close R8's deferred gates.

## OPEN-10 — R9: Product UI, Accessibility, and Onboarding

Prompt: [`10_R9_PRODUCT_UI_AND_ACCESSIBILITY.prompt.md`](archive/first-pass-prompts/2026-08-12/10_R9_PRODUCT_UI_AND_ACCESSIBILITY.prompt.md)

The first-pass R9 product slice is implemented locally and source-build
verified. The menu-bar/window surface now has conversation, task,
capability/permission, model/voice, privacy/memory, and recovery sections;
truthful local/cloud and degraded/disabled indicators; staged onboarding;
keyboard shortcuts/native controls; confirmation presentation; memory
inspection/correction/deletion/export wiring; and English/Turkish shell copy.
Evidence is recorded under `EV-R9-20260808-UI-BUILD-02` and
`EV-R9-20260808-UI-TESTS-03`. This does not close R9.

- VoiceOver reading order, keyboard-only navigation, confirmation focus
  containment/expiry, contrast, non-color status, scaled text/reflow,
  reduced-motion behavior, and Turkish/English layout must still be exercised
  manually on the target macOS hardware. The local SwiftPM test runner also
  requires the CommandLineTools Testing framework/rpath workaround in this
  host; full Xcode UI automation is unavailable.
- The task projection currently exposes the durable `TaskStatus` fields only.
  Backend/model/workspace/account/app scope, diff/test/artifact/evidence
  review, pause/resume/retry controls, and universal truthful verification
  presentation are not yet available from that backend contract.
- The capability center is currently an inspectable health projection. Grant
  expiry/revoke/disable/test controls and live TCC/permission repair evidence
  are not yet wired into the product surface; unavailable capabilities remain
  visibly disabled rather than being presented as executable.
- The model/voice center reports configured system voice and coding-backend
  health, but model download/remove, routing/fallback controls, benchmark
  health, local-model readiness, and reference-voice consent evidence remain
  open. No model or dependency was downloaded by R9.
- Memory controls are wired to the R8 append-only policy, but user-present
  restart, correction/conflict, deletion, export, retention, and privacy
  acceptance have not been demonstrated. Integrations/account-scope/network
  summaries, support-bundle generation, safe-mode/reset flows, and update or
  uninstall guidance remain incomplete.
- Onboarding denial/revocation/restart recovery and live clean/configured
  Turkish/English profiles have not been demonstrated. Wake word, local model,
  integrations, and launch-at-login steps remain truthful optional/deferred
  steps; R11 owns launch-at-login. R9 remains `in_progress`.

## OPEN-11 — R10: Security and Privilege Separation

Prompt: [`11_R10_SECURITY_PRIVILEGE_SEPARATION.prompt.md`](archive/first-pass-prompts/2026-08-12/11_R10_SECURITY_PRIVILEGE_SEPARATION.prompt.md)

R10's first-pass slice followed the user-authorized commit/push/merge and
continuation. R9 remains `in_progress`; its open manual,
live, TCC, task/capability/model/privacy/recovery, and accessibility gates are
preserved above. A bounded first implementation slice is now source/build and
focused-test verified under `EV-R10-20260809-BOUNDARY-SLICE-01`, but R10 is not
complete and every unverified completion gate remains open:

- `HelperIPCRequestEnvelope`/`HelperIPCResponseEnvelope` now bind helper kind,
  capability, actor, target, plan hash, payload hash, freshness, nonce replay,
  and sandbox attestation for the two parent-launched helper executables. This
  is an application-level pipe contract, not authenticated XPC peer identity;
  helper execution is still echo-only and the main process retains broad
  Accessibility, generated-input, shell, CLI, and network authority.
- `NetworkEndpointPolicy` and the Ollama client now constrain scheme, host,
  port, path, userinfo, response size, cookies/cache, and redirects for the
  covered loopback path. A mandatory factory for every `URLSession`, DNS/IP
  pinning/revalidation, proxy/TLS policy, download bounds, provider transport,
  and subprocess network audit remain open.
- OAuth PKCE/state/redirect/scope contracts and Keychain token expiry/revoke
  deletion are now locally tested. Actual provider token exchange/callback
  wiring, CSRF/account isolation, live revocation, and leakage prevention
  across args/env/logs/events/crashes/support remain open.
- untrusted-content provenance, instruction/content separation, schema and
  capability validation, redaction, action-time policy re-evaluation, and
  indirect-injection corpus coverage;
- plugin/package signature, hash, vendor-root, revocation, quarantine,
  update/rollback, SBOM/checksum, and unverified-code rejection evidence;
- incident response, review schedule, vulnerability reporting, grant
  revocation, containment, independent security review, and ADR-044 acceptance.

The focused source/build tests prove contracts only; they do not close OS
confinement, live provider, independent-review, injection-corpus, plugin trust,
or incident-response gates. These residuals must remain until independently
verified or explicitly accepted by the authorized release owner.

## OPEN-12 — R11: Release Engineering and Continuous Operations

Prompt: [`12_R11_RELEASE_ENGINEERING_AND_OPERATIONS.prompt.md`](archive/first-pass-prompts/2026-08-12/12_R11_RELEASE_ENGINEERING_AND_OPERATIONS.prompt.md)

R11 was activated after explicit user approval following R10 delivery. The first
safe slice is release-readiness work only; no external release authority is
implied. Every completion gate remains open:

- full Xcode/Swift/SDK/toolchain pinning and an observed release CI run;
- reproducible archive/build metadata covering the app, nested helpers,
  entitlements, plists, resources, symbols, checksums, SBOM, and provenance;
- Developer ID signing, secure timestamp, notarization, stapling, Gatekeeper,
  clean-machine, quarantine, nested-helper, and TCC identity evidence;
- user-controlled launch-at-login, sleep/wake/crash/update behavior, safe mode,
  diagnostics/support bundle review, reset/recovery, uninstall, and factory
  reset semantics;
- signed update manifest/package, transport, version/channel policy,
  downgrade/replay protection, atomic install, migration backup, staged rollout,
  kill switch, rollback, and compatibility checks;
- configuration/database/memory/plugin/model migration and interrupted/failed/
  low-disk/corrupt-artifact recovery tests;
- R9/R10 prerequisite gates and all external-beta/release gates remain open.

The local first-pass target is to add deterministic artifact/manifest/checksum
validation and explicit fail-closed placeholders/tests. These contract checks
do not prove signing, notarization, installation, updater operation, or clean
machine behavior. ADR-046 must remain `Proposed` until its operational and
security alternatives are directly reviewed and accepted.

The CI workflow now contains an edit-only step that builds and retains the same
clearly named `development_unverified` artifact and manifest for up to 14 days
after a successful build/test job. The workflow definition is statically
validated, but no post-change CI run has been observed; retention, provenance,
runner compatibility, and artifact inspection therefore remain open evidence
gates.

## OPEN-13 — R12: Beta Validation and Release Candidate

Prompt: [`13_R12_BETA_VALIDATION_AND_RC.prompt.md`](archive/first-pass-prompts/2026-08-12/13_R12_BETA_VALIDATION_AND_RC.prompt.md)

R12 was activated by explicit user request even though R11 remains `in_progress`.
This is a deliberate dependency exception recorded in the canonical state; it
does not close R11 or authorize beta/release operations. All R12 completion
gates remain open:

- no controlled internal/external beta cohort, supported hardware/profile
  matrix, capability inclusion/exclusion list, duration, sample minimum, issue
  SLA, rollback/kill-switch authority, or privacy notice is approved;
- no opt-in content-free telemetry implementation or consent evidence exists;
- no percentile SLO report, Turkish/English/mixed scenario matrix, false-success
  or unauthorized-action result, crash/recovery/update/uninstall result exists;
- no severity-1/2 incident review, root-cause/remediation regression record,
  independent security/privacy/accessibility/localization/release sign-off, or
  accepted ADR-047 exists (`ADR-047` is not present in the repository);
- no reproducible signed/notarized release-candidate artifact, clean-install,
  update/rollback/recovery evidence package, beta window, or authorized beta
  participant evidence exists.

The edit-only R12 target is a local readiness matrix and fail-closed evidence
package contract. That conservative contract now exists under
`EV-R12-20260809-READINESS-CONTRACT-01`; it does not enroll participants,
activate telemetry, launch or install the app, publish a release, or establish
beta/RC readiness. Continue auditing the contract and preserve every missing
direct-evidence gate.

## OPEN-14 — FINAL: Acceptance, Cleanup, and Operational Handoff

Prompt: [`14_FINAL_ACCEPTANCE_AND_CLEANUP.prompt.md`](prompts/14_FINAL_ACCEPTANCE_AND_CLEANUP.prompt.md)

FINAL is active by explicit user request, despite the required R12 dependency
not being `release_candidate_verified`. The final audit therefore cannot mark
the program complete, `release_candidate_verified`, or `released`. Mandatory
closure gates remain open and return to their owning tracks:

- R2-R10 live, manual, security, accessibility, integration, and privilege
  gates remain open as recorded above;
- R11 has no full-Xcode reproducible signed/notarized clean-machine artifact,
  updater, launch-at-login, recovery, migration, uninstall, or observed CI run;
- R12 has no beta cohort/consent, telemetry, percentile SLO results, scenario
  matrix, incident remediation, independent sign-offs, or approved RC package;
- no complete clean-Mac end-to-end acceptance, support-bundle privacy review,
  rollback/uninstall/factory-reset evidence, or authorized release action exists;
- ADR-047 is absent; no final decision or release waiver is invented.

The FINAL/CLOSEOUT deliverable is a blocked maintainer handoff and exact
owning-track return, not a release claim. Stale prose may be reconciled only
where it conflicts with canonical state; historical ledger entries remain
append-only.

Closeout evidence: `EV-FINAL-20260809-CLOSEOUT-BLOCKED-01`. The handoff is
recorded at [`FINAL_OPERATIONAL_HANDOFF.md`](../docs/operations/FINAL_OPERATIONAL_HANDOFF.md);
runtime governance and 23/23 deterministic script tests pass, but those checks
do not satisfy the missing live, release, beta, or clean-machine gates above.

## OPEN-15 — SESSION CLOSEOUT procedure

This is mandatory after every numbered step, including a blocked or failed
step. The last closeout was recorded under
`EV-FINAL-20260809-CLOSEOUT-BLOCKED-01`; it does not close future sessions.

1. Record branch, exact `HEAD`, remote relation, dirty worktree, user-owned
   changes, active prompt, and authority.
2. Review the diff for accidental scope, secrets, stale claims, weakened
   assertions, generated-file drift, and missing documentation.
3. Append one result entry to both runtime/project ledgers with objective,
   files, commands, evidence, acceptance verdict, residual risks, authority,
   and exact next action.
4. Update evidence, risk, decision, capability, current-state, and handoff
   references atomically; reset authority unless the user explicitly grants it.
5. Validate state/handoff/capability/schema/manifest/dependency/evidence/risk
   references and record the closeout evidence ID.

No session may report “all gaps closed” while any `OPEN-03`–`OPEN-14` item is
unverified or while the current state is not `release_candidate_verified` or
`released` with matching direct evidence.

## Current first-pass workflow boundary

The FINAL/CLOSEOUT audit is complete for edit-only scope and remains
`in_progress`/blocked because the owning R11/R12 gates are incomplete. Return to
R11, then R12, with separately authorized evidence; rerun FINAL only after
those gates pass. After each later prompt, append its unresolved gates to this
file for the future second pass; do not treat an entry as permission to skip
current first-pass work.

## Cross-cutting constraints for the second pass

- Preserve dirty worktree changes, frozen evidence, anonymization, and
  user-owned local files.
- No commit, push, merge, release, deploy, installation, dependency/model
  download, or TCC mutation is authorized by this tracking document.
- `swift-format` and full Xcode/release validation remain host/toolchain gaps;
  do not convert their absence into a false release claim.
- Every live evidence record must identify the exact command/path, result,
  hardware/account authority, and residual limitations.

## Prompt transition approval rule

- After each prompt reaches its own completion gate, perform commit/push/merge/
  deploy only if the user explicitly authorizes that delivery and record exact
  evidence for each action. R9 delivery was explicitly authorized and recorded
  under `EV-R9-20260809-DELIVERY-07`.
- R11 and R12 transitions were explicitly approved and their edit-only slices
  are recorded. FINAL transition is now explicitly approved by the user despite
  the R12 dependency blocker. FINAL remains blocked; do not infer beta
  enrollment, telemetry, release, or deploy authority from any transition.

## Reopening rule

When a second-pass item is completed, append evidence to the relevant ledger,
update the machine state and risk register, and retain the original open-gap
wording as historical context. Do not delete or rewrite this list to make a
gate appear complete.
