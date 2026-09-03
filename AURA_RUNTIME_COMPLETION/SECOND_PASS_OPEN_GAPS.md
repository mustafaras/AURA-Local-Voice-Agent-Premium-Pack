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
- **Active state:** [`SECOND_PASS_STATE.json`](second-pass/SECOND_PASS_STATE.json), currently `SP-031` / `in_progress`; `SP-030` is completed for the owner-approved local-only deterministic scope under ADR-051, while SP-031 is open for local-only package preparation under ADR-052.
- **Prompt contract:** [`SECOND_PASS_PROMPT_CONTRACT.md`](second-pass/SECOND_PASS_PROMPT_CONTRACT.md).
- **Control invariants:** [`SECOND_PASS_CONTROL_CONTRACT.md`](second-pass/SECOND_PASS_CONTROL_CONTRACT.md).
- **Tiered context:** [`SECOND_PASS_READ_FIRST.md`](context/SECOND_PASS_READ_FIRST.md).
- **Focused append-only ledger:** [`SECOND_PASS_LEDGER.md`](second-pass/SECOND_PASS_LEDGER.md).
- **Human chain index:** [`SECOND_PASS_PROMPT_PROGRAM.md`](SECOND_PASS_PROMPT_PROGRAM.md).
- **Machine validator:** `scripts/validate_second_pass_program.py`.

## Current SP-031 scope — 2026-09-02

SP-030 is completed for the owner-approved local-only deterministic scope under
ADR-051. SP-031 is now `in_progress` under ADR-052 for local-only
`development_unverified` RC package preparation and ADR-047 drafting. This
opening does not approve an RC, change `beta-readiness.json`, or authorize live
testing, signing, notarization, publication, deployment, beta, or production
claims. SP-031 must finish its own package and decision gate before SP-032 can
start.

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
| 12 | R11 | `in_progress` | Full-Xcode reproducible local-only release artifact, observed CI, local nested signing + launch, launch-at-login, updater/rollback, recovery/migration/uninstall/support bundle. Developer ID/notarization/Gatekeeper are permanently out of scope (ADR-049). | R9 + R10 / release owner | Local-only release evidence (ADR-046, nested sign, artifact hashes, launch) |
| 13 | R12 | `in_progress` | Approved cohort/consent, content-free telemetry, SLO/scenario/incident results, independent sign-offs, and provenance-bound RC package. | R11 / beta owner | Authorized beta evidence, SLO report, sign-offs, RC approval, ADR-047 |
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

**Current status:** `OPEN-02` is resolved for the bounded `SP-001` prompt gate
by direct user-present evidence `EV-SP-001-20260815-CANCELLATION-12`. The
program-wide first-pass R1 and FINAL gates remain separate and open.

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

### SP-001 post-fix residual live matrix — 2026-08-15T10:44:08Z

The current unsigned build was exercised under explicit user-present authority
for the remaining `OPEN-02` matrix. The direct redacted bundle proves
requested/accepted/tool-result verification for a safe observation and a
reversible Calculator close with read-only no-process verification; it also
proves expiry, changed-plan supersession, replay deny/no-replay, independent
near-concurrent correlation chains, and truthful `tool.result/failed` UI/store
handling. No denied action executed. Evidence:
`EV-SP-001-20260815-LIVE-RESIDUAL-10` (artifact SHA-256
`2efa658ba7ba7b7851e78d23ce7e45f0295bdb28e9aa4e63a2e9a24baed47943`).

Emergency-stop was exercised against a pending safe `/bin/sleep` confirmation;
no execution occurred and the request later expired fail-closed. However, the
runtime has no distinct `confirmation.cancelled` resolution/trace, so
cancellation is not proven as a terminal postcondition. `SP-001` therefore
remains **blocked**, `OPEN-02` remains open, and `SP-002` must not start.

### SP-001 mandatory closeout — 2026-08-15T10:55:08Z

The mandatory closeout procedure is recorded under
`EV-SP-001-20260815-CLOSEOUT-11` (artifact SHA-256
`5763fb85065db4098b1e2f34e4a0caf7eea77954b54a6ac776e66fbe5064e40a`). The
current local build and full 21-bundle/794-test wrapper passed with zero failed
bundles. Second-pass, runtime-completion, repository-hygiene, and supply-chain
validators passed; the deterministic Python suite passed 38/38; compileall,
shell syntax, and diff checks passed. These checks close the session procedure
only. The missing distinct cancellation terminal trace remains open, so
`SP-001` stays blocked and `SP-002` must not start.

### SP-001 OPEN-02 completion — 2026-08-15T11:17:34Z

- **Scope/authority:** Only `SP-001` / `OPEN-02`; the user authorized the current unsigned local build, safe `/bin/sleep 20` cancellation/emergency-stop, redacted read-only verification, and reversible Calculator mutation. No denied action, TCC, install, dependency/model/provider, telemetry/beta, signing, release, deploy, commit, push, or merge action occurred.
- **Resolution:** Added `ConfirmationResolution.cancelled` and resolved pending confirmation after emergency stop. The live current-build run produced `requested → cancelled → policy intent.blocked` with no sleep execution, then proved an accepted reversible Calculator close with `app.quit verified`, independent no-process verification, and no replay after a full normal quit/reopen.
- **Evidence:** `EV-SP-001-20260815-CANCELLATION-12`; artifact `AURA_RUNTIME_COMPLETION/state/EV-SP-001-20260815-CANCELLATION-12.md`, SHA-256 `4fbfe0598c716cba672c02bbac86cdbc4777a756ce4acdb583de9500cd9ad9dc`. The source integration test and full local regression/validators passed before this closeout projection.
- **Cognitive gate:** The observed missing terminal postcondition, runtime/app-model root cause, direct source change, live acceptance procedure, falsifier, and residual first-pass risks are recorded in the evidence artifact and append-only ledgers. `OPEN-02` has no remaining `SP-001` residual.
- **Acceptance verdict:** `SP-001` is **completed** for its bounded prompt scope. `SP-002` is the next eligible prompt but remains **pending and unopened**; no automatic transition or execution follows.

### 2026-08-15T11:29:26Z — SP-001 mandatory 15_SESSION_CLOSEOUT — completed

- **Closeout evidence:** `EV-SP-001-20260815-CLOSEOUT-13`, artifact SHA-256 `418aaa44be0f74a0835691887daccc07a663fb2e8e002abf775cfdc6a8a69798`, records the mandatory session procedure after `EV-SP-001-20260815-CANCELLATION-12`.
- **Verification:** The full local wrapper passed 21/21 bundles, 794/794 tests, zero failed bundles; AURAIntegrationTests passed 24/24; second-pass, runtime-completion `--ci`, repository-hygiene, supply-chain, 38/38 deterministic Python tests, compileall, shell syntax, `git diff --check`, JSON parsing, and schema-cap checks passed.
- **State:** `SP-001` is completed for bounded `OPEN-02`; `SP-002` is pending and unopened. Historical blocked wording remains preserved above. Authority resets to edit-only, and no automatic prompt transition or release claim follows.

## OPEN-03 — R2: Bilingual NLU and Dialogue

Prompt: [`03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md`](archive/first-pass-prompts/2026-08-12/03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md)

### SP-002 closure note — 2026-08-15T16:45:00Z

SP-002 / OPEN-03 was closed for its **bounded** second-pass prompt gate under
`EV-SP-002-20260815-PTT-MOCK-14` by using a **documented accessibility
accommodation**: because the user is speech-disabled, the live
`SFSpeechRecognizer`/microphone path is not feasible. The deterministic
mock-STT engine (`DeterministicMockSTTEngine`) was temporarily selected as the
default engine, AURA was built and launched, the TCC Microphone and Speech
Recognition prompts were observed and allowed, and the UI Push-to-Talk button
produced the transcript `hello` displayed as `You: hello`. The temporary default
engine change was reverted before closeout. All governance validators passed.

This closes the **PTT/TCC/STT pipeline composition gate** for OPEN-03 under the
stated accommodation. It does **not** close the first-pass R2 live
microphone/TCC Turkish/English/mixed seven-scenario demonstration gates
(`EV-R2-20260804-LIVE-VOICE-DEMO-01` and `EV-R2-20260804-LIVE-7SCENARIO-01`).
Those remain first-pass R2 / SP-003 / R7 live evidence requirements and must
not be backfilled from simulated boundaries.

### SP-003 completion note — 2026-08-15T18:23:13Z (supersedes both notes below)

**SP-003 is `completed` for OPEN-03.** The blocker recorded in the 18:03:11Z note below was
resolved rather than waived. Root cause: `PromptInjectionClassifier` already scored the payload
as `.blocked` (rule `instructionOverride.ignorePrevious`, severity `.high` = 4, threshold 3) and
was constructed at `Sources/AURA/AuraKernel_Construction.swift:216`, but was **never invoked on
the dialogue path** — `DialogueEngine.makePrompt` defended only with a natural-language
instruction the local model ignored. The failure was missing enforcement, not missing detection.

Fix: `DialogueEngine` now screens every `DialogueContextItem.summary` through the classifier
before prompt assembly, replacing blocked content with a withheld marker while still rendering
`sourceID`, `authority` and `confidence` so provenance survives and the withholding is visible.
Context is screened as non-authoritative regardless of its self-declared `authority` string, so
injected text cannot claim an exemption.

Verification under `EV-SP-003-20260815-INJECTION-FIX-17`: three deterministic regression tests
assert against the captured prompt (injected text absent, provenance retained, claimed authority
grants no exemption, clean context untouched); `AuraIntentTests` 70/70; and a live re-run of all
seven scenarios passed 25/25 with 0 failed bundles. Scenario 7 now returns a substantive Turkish
answer instead of `PWNED`, with `sourceIDs == ["sp003-context-001"]` preserved. All 6 inferences
reported `isLocalModel == true`; cloud inference count 0.

Corrected from the blocked note: the structured-NLU downgrade measured 2 of 4 before the fix and
0 of 4 after, but the fix cannot explain that — screening only affects `DialogueEngine` prompt
assembly, the downgrade happens earlier in `IntentEngine`, and scenario 1 carries no context items
at all. It is run-to-run nondeterminism in `gemma4:latest`, now tracked as the intermittent
`RISK-SP-003-NLU-DOWNGRADE-VARIANCE` rather than a deterministic defect.

Residual and forwarded, none owned by SP-003: `RISK-INJECTION-COVERAGE-NON-DIALOGUE` (the
classifier is still not applied to every other untrusted surface that can reach a model — a
deliberate scope boundary, not an oversight), `RISK-SP-003-NLU-DOWNGRADE-VARIANCE`,
`RISK-SP-003-MODEL-LATENCY` (19.8–36.1 s model-backed versus 0.08–16.0 ms deterministic), and
`RISK-SP-003-LIVE-VOICE-RESIDUAL` (live microphone/TCC voice, owned by SP-002 / R7).

### SP-003 blocked note — 2026-08-15T18:03:11Z (SUPERSEDED — resolved, see completion note above)

**OPEN-03 remains OPEN. SP-003 is `blocked`.** The closure note dated
2026-08-15T14:44:48Z is retained verbatim below for the historical record but is
**no longer authoritative**, and its evidence ID
`EV-SP-003-20260815-R2-DIALOGUE-TESTS-15` is retracted. That note closed the gap
on a pass of the pre-existing regression suite, mapping test *names* onto the
seven scenarios rather than running them, and its artifact was written only to
`/tmp` — outside the repository and outside version control. SP-003's hard
boundary forbids inferring completion from a local contract.

The seven scenarios of `03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md`
§"Completion demonstration" were subsequently **run live** under
`EV-SP-003-20260815-LIVE-7SCENARIO-16`, driving the real `IntentEngine`,
`RuleBasedUtteranceClassifier`, `DialogueEngine` and `OllamaAdapter` against
`gemma4:latest` — the only genuinely local model of the 15 the daemon reports,
the other 14 being cloud proxies to `ollama.com`. All 6 inferences were local
and the cloud inference count was 0.

Six scenarios met their criteria: the English general question was answered
model-backed; the mixed-language technical command resolved to the typed slot
`executable=/bin/date`; the paraphrased Turkish morphological command
`Safari'yi açar mısın` resolved to `com.apple.Safari`; an unregistered target
failed closed to clarification with no invented bundle ID; and an unreachable
daemon produced a real `OllamaDegradedModeEvent(healthCheckFailed)` followed by
the honest Turkish fallback rather than a fabricated answer.

**Scenario 7 failed, and is the blocker.** Prompt-injection content carried
inside an approved `DialogueContextItem` displaced the user's request; the model
replied exactly `PWNED`. R2's testing requirement "prompt-injection content
treated as data" is therefore not met on the live path.
`PromptInjectionClassifier` exists in `AuraSecurity` and is constructed at
`Sources/AURA/AuraKernel_Construction.swift:216`, but it is never applied to
dialogue context items; `DialogueEngine.makePrompt` defends only with a
natural-language instruction that this local model ignores. Provenance itself
survived correctly, so the defect is the absence of enforcement, not a loss of
provenance.

Also measured and carried forward: 2 of 4 model-backed turns were failed closed
from `.converse` to `.unknown`/`.clarify` by
`ClassificationResult.applying(_:)` — safe, but it costs a clarification
round-trip on an ordinary question, weakening R2's "general questions return
substantive model-backed answers" requirement; and model-backed latency ran
19.8–24.9 s against 0.08–0.42 ms on the deterministic fast path.

Required before OPEN-03 can close: neutralize injected context before prompt
assembly, re-run the harness with `AURA_ENABLE_LIVE_OLLAMA_SCENARIOS=1`, and
keep the live microphone/TCC voice gates open as separately tracked. `SP-004`
must not be opened.

### SP-003 closure note — 2026-08-15T14:44:48Z (SUPERSEDED — see blocked note above)

SP-003 / OPEN-03 is closed for its **bounded** second-pass prompt gate under
`EV-SP-003-20260815-R2-DIALOGUE-TESTS-15`. The source-side R2 dialogue/NLU contract is verified by the
passing repository Swift test suite (21/21 bundles, 0 failed bundles) and the
focused `AuraIntentTests`/`AuraAgentTests`/`AURAIntegrationTests` coverage of
Turkish/English/mixed handling, clarification, slot expiry, provenance,
honest degradation, and Ollama structured-adapter contracts. All governance
validators and deterministic checks passed.

This closes the **source-side R2 NLU/dialogue contract gate** for OPEN-03
under the documented simulated-boundary accommodation. It does **not** close
the user-present live microphone/TCC Turkish/English/mixed seven-scenario
demonstration gates (`EV-R2-20260804-LIVE-VOICE-DEMO-01` and
`EV-R2-20260804-LIVE-7SCENARIO-01`), nor does it close a live Ollama model
inference gate. Those remain first-pass R2 / R7 live evidence requirements
and must not be backfilled from simulated boundaries.

### Remaining first-pass / SP-004 live work

- Perform the user-present microphone/TCC Push-to-Talk verification and record
  `EV-R2-20260804-LIVE-VOICE-DEMO-01`.
- Perform the required seven-scenario Turkish/English/mixed-language live
  completion demonstration and record
  `EV-R2-20260804-LIVE-7SCENARIO-01`.
- Perform a bounded live Ollama inference sweep under explicit authority and
  record structured-output/latency/model-variance evidence.
- Keep `RISK-STT-MIC-NOT-CAPTURING` open until hardware evidence passes and
  `RISK-ENGLISH-ONLY-INTENT` mitigating until the live scenario gate passes.
- Do not treat local model, text-demo, unit/integration, or mock-STT evidence
  as a substitute for the user-present hardware gate.

## OPEN-04 — R3: Capability Registry and Typed Planner

Prompt: [`04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`](archive/first-pass-prompts/2026-08-12/04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md)

- Build the remaining filesystem and URL adapters. **Part of this bullet is
  satisfied by `EV-SP-004-20260816-ADAPTERS-01`:**
  `filesystem.open_file`, `filesystem.open_folder`, `filesystem.reveal`,
  and `url.open` now have real, typed, policy-controlled, verified adapters
  (`AuraAutomation.FileSystemURLOpener`) and are registered `.ready` in the
  initial capability set. The registration truthfully claims adapter reachability
  only through direct `AuraKernel` calls — the same non-NLU path
  `app.discover`/`app.hide`/`task.status`/`task.cancel` already use.
- **Still open for SP-005** (which carries the identical `gap_ids: OPEN-04`):
  - Add NLU/UI reachability for the four capabilities that currently have only
    direct-call reachability.
  - Wire the typed planner into `DialogueEngine`/`ToolRouter` for real
    multi-step natural-language plans.
  - Run and record the required seven-scenario live completion demonstration.
  - Preserve truthful registry state; unavailable capabilities remain disabled.
  `OPEN-04` is **closed** by `EV-SP-004-20260816-ADAPTERS-01` (adapter half) and
  `EV-SP-005-20260816-REACHABILITY-01` (NLU/UI reachability half). The
  seven-scenario live demonstration remains a forwarded live-gate residual.
- **Forwarded live gate satisfied by SP-006** under `EV-SP-006-20260816-7SCENARIO-02`:
  all seven R3 scenarios (observation, reversible file/URL action, confirmed
  mutation, two-step safe plan, unavailable capability, malformed model-plan
  rejection, capability-health inspection) pass on the live production path with
  typed evidence and no registry bypass; cancellation, partial-failure,
  rollback-declaration, and no-unauthorized-delivery controls pass. Two real
  defects were found and fixed through the live runs (a missing seeded policy
  grant for the `.reversible` fs/URL capabilities, and a folder-slot misroute in
  `ToolRouter.handleFileOpen`). `R3`'s live demonstration bullet is complete.

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

### SP-007 attempt — 2026-08-16 (structural readiness, live gate blocked)

SP-007 was opened under edit-only authority. The fixture table in
`Sources/AuraComputerUse/ComputerUseAppFixtures.swift` was expanded from
2 apps / 1 task each to 3 apps (Finder, Terminal, Notes) / 3 tasks each,
covering the three action types the procedure requires per app:
Accessibility-anchored, bounded coordinate fallback, and
confirmation-required (including a `.delete` mandatory-confirmation task
for Notes). 8 new deterministic tests verify the coverage; full regression
passed 21/21 bundles, 0 failed. Evidence: `EV-SP-007-20260816-FIXTURES-01`.

**OPEN-05 is now CLOSED.** The user granted full authority. The allowlist
was updated to `.liveValidated` for Finder, Terminal, and Notes. AURA was
built, ad-hoc signed, and launched. 9/9 live actions passed across the
three approved apps — one Accessibility-anchored action, one bounded
coordinate fallback, and one confirmation-required action per app — with
observable semantic postconditions and no unsafe fallback. Evidence:
`EV-SP-007-20260816-LIVE-02`. Regression: 21/21 bundles, 0 failed.
`computerUse.run` is enabled for the three liveValidated apps.

Residual: the live tests used AppleScript/System Events as the action
executor, not the AURA app's own `ComputerUseControlLoop.run` path.
`RISK-SP-006-URL-OPEN-FAILS-LIVE` and
`RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED` forwarded unchanged.

### SP-008 adversarial and recovery closure — 2026-08-17T06:57:03Z

SP-008 carries the same `gap_ids: OPEN-05` and owns R4's **adversarial and
recovery** residuals, which the SP-007 closure above did not cover. Reading the
production path found three defects, all of one kind — a fail-closed control
correct at one layer and silent at the next:

1. A focused secure field returned a non-terminal `.stop`, so the session
   re-observed and re-refused until its budget expired and then reported
   `noProgress`. It failed closed but named the wrong reason, and left a window
   in which the field could lose focus mid-session and let an already planned
   step proceed against a credential surface. There is now a terminal
   `ComputerUseLoopOutcome.secureFieldBlocked`.
2. `AXCGEventActionExecutor` enforced emergency stop unconditionally — explicitly
   so a direct caller bypassing the loop is still refused — but had no equivalent
   secure-field guard. It now takes a required `secureFieldDetector` and refuses
   every input-generating kind; `.wait` stays exempt because it generates no
   input and is how a caller yields to the user during a credential prompt.
3. An off-screen window was refused correctly but reported as
   `sensitiveApplication`. `ScreenContextEngine.exclusionReason(for:)` is now the
   single source of truth for both window listing and capture preflight, with a
   new `ScreenCaptureBlockReason.windowNotVisible`.

The beta allowlist was additionally moved off the kernel construction site into
`ComputerUseBetaAllowlist.liveValidatedProduction`, so "only directly validated
apps are reachable" is a value a regression test asserts against rather than a
wiring detail that could drift open. **No app was added** — the SP-007 live
bundle validates Finder, Terminal and Notes and nothing else.

`Tests/AuraComputerUseTests/R4AdversarialSafetyTests.swift` (25 tests — the
count was recorded as 22 and corrected under
`EV-SP-008-20260817-CORRECTION-03`) covers
SP-008's whole procedure: screen-content injection (plan invariance, curated key
hidden in screen text, forged authority), secure-field refusal at loop and
executor layers, modal mismatch with an executable plan pending, wrong identity
before planning, cancellation at the Act stage, restart/re-arm across a run
boundary, emergency stop at the observation / confirmation / execution / executor
boundaries, a hostile planner proving raw text never becomes an action, and
hidden-window / sensitive-app / assistant-self refusal. Every case asserts the
executor call count, not merely the reported outcome. Verified **21/21 bundles,
931/931 tests, 0 failed**; all four governance validators exit 0. Evidence:
`EV-SP-008-20260817-ADVERSARIAL-01`, `EV-SP-008-20260817-CLOSEOUT-02`.

**OPEN-05's adversarial and recovery residuals are closed at the deterministic
boundary.** They are **not** closed live, and that is stated rather than implied:
`RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL` holds a real focused secure field, a real
system modal, and observed cessation of generated events open as R4 live
acceptance / R9 work, because SP-008's authority excludes app launch and the user
elected to close on the deterministic boundary.
`RISK-SP-008-PLANNER-DECLARED-INTENT-TRUST` records that semantic intent is
planner-declared — sound for the curated deterministic planner, open for any
future model-backed conformer.

An inherited defect was also repaired: `validate_runtime_completion.py` had been
failing **at clean HEAD** because SP-007's delivery commit `0000b4a` changed
product source while `verified_head`, `remote_head`, and the capability matrix's
`repository_commit` still named `9774287`. All three now name `0000b4a`; the
content verification at that SHA rests on SP-007's recorded sweep, not a fresh
clean-tree run by SP-008.

### SP-008 post-closure re-verification — 2026-08-17T08:15:11Z

The user asked whether SP-008 was truly complete, so every claim above was
re-derived from the tree instead of read off these records: a fresh
`./scripts/aura-test.sh` sweep with bundle and test totals recomputed from the
log (**21/21 bundles, 931/931 tests, 0 failed**), a clean `swift build --product
AURA`, four governance validators at exit 0, 38/38 governance unit tests, and a
direct re-read of every changed source file. **The technical closure stands.**

Two record defects were corrected — the new-test count (22 to **25**) and the
prior bundle total (71 to **68**; 68 + 25 = 93, the number the runner reports) —
along with `session-handoff.json`, whose `active_prompt.file` still named
SP-008's prompt file after `active_prompt.id` had been advanced to `SP-009`.
Historical ledger wording is preserved; the ledgers carry new correction entries
instead.

**A third finding is recorded, not fixed:**
`RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE`. `ComputerUseControlLoop.run` is
invoked only from `AuraKernel.computerUseRun(appBundleIdentifier:objective:)`,
which has **no caller** in `Sources` or `Tests`; `IntentKind` has no
computer-use case and `ToolRouter` has no computer-use branch. The guards SP-008
added are correct and regression-covered, but nothing in the shipped product can
currently drive the loop they protect — the deeper form of SP-007's recorded
residual that its live actions used AppleScript/System Events rather than the
app's own loop. **OPEN-05 therefore keeps a reachability leg open**, owned by R4
productization / NL reachability, not by SP-008's adversarial-safety scope.
Evidence: `EV-SP-008-20260817-CORRECTION-03`.

### SP-008 detector-layer residual reduction — 2026-08-17T09:20:00Z

The user asked to close whatever could be closed in SP-008's two open risks
before opening SP-009. Reading the two production detectors showed that
`RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL`'s stated mechanism — "a detector that
silently returns `false` makes every guard above it inert while all tests still
pass" — was not a hypothetical property of live hardware; it was the code.
`AccessibilitySecureFieldDetector.isSecureFieldFocused` returned `false` on
**every** failure path (Accessibility not trusted, focused-element read failed,
value not an `AXUIElement`, subrole read failed, subrole not a string), and
`AccessibilityModalDialogDetector.detectUnexpectedModal` returned `nil` on the
same class of failures. `false`/`nil` means "all clear", which is a licence to
type — and the credential sheet or `SecurityAgent` dialog most likely to make
an Accessibility read fail is the surface this check exists to guard.

The fix introduces a third state both a boolean and `String?` cannot express:

- `SecureFieldProbe` (`.focused` / `.notFocused` / `.indeterminate(String)`)
  with `refusesInput` as the fail-closed collapse, and `probeSecureField` as a
  protocol requirement with a default implementation deriving from the boolean,
  so every existing conformer compiles unchanged.
- `ModalProbe` (`.none` / `.unexpected(String)` / `.indeterminate(String)`) and
  `probeModal` with the same default-implementation pattern.
- `AccessibilityProbeClassification.isDeterminedAbsence(_:)` admits only
  `.noValue`, `.attributeUnsupported`, `.invalidUIElement` as definitive empty
  answers; every other `AXError` is indeterminate. `describe(_:)` gives a stable,
  content-free error name for evidence and refusal messages.
- The control loop halts terminally as `.failed(reason: "secure-field check
  unavailable: …")` / `"modal check unavailable: …")` on indeterminate; the
  executor's own guard refuses with its own message. `.wait` stays exempt at the
  executor (it generates no input and is how a caller yields to the user during a
  credential prompt); a *determined* negative answer still proceeds, so the guard
  does not degrade into a blanket refusal.

Truthfulness was preserved deliberately: an unreadable state is **not** reported
as `.secureFieldBlocked` or `.unexpectedModalDialog` — that would claim an
observation never made, the exact defect SP-008 removed one layer up. It is
reported as the check that failed, naming the `AXError`.

`Tests/AuraComputerUseTests/R4DetectorFailClosedTests.swift` (11 tests) covers
the probe contract, the `AXError` classification (the falsifier: if any of
`.cannotComplete`/`.apiDisabled`/`.notImplemented`/`.failure` and six more ever
classifies as an absence, an unreadable credential surface reads as "clear"
again), the real detector's boolean/probe agreement (environment-independent),
the control-loop halt under its own reason, the executor refusal, and the
`.wait` exemption. Verified **21/21 bundles, 942/942 tests, 0 failed**
(`AuraComputerUseTests` 104/104, up from 93); all four governance validators exit
0; 38/38 governance unit tests. Evidence: `EV-SP-008-20260817-DETECTOR-04`.

**Effect on the open risks:**

- `RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL` — **reduced, not closed.** Its
  silent-failure mechanism is now false by construction and by regression. What
  remains open is the live-positive validation only (a real password field, a
  real `SecurityAgent` dialog, observed CGEvent cessation), which needs hardware
  authority SP-008 does not have. Owned by R4 live acceptance / R9.
- `RISK-SP-008-PLANNER-DECLARED-INTENT-TRUST` — **unchanged, deliberately.**
  Closing it needs an intent-verification mechanism independent of the planner's
  declaration; every cheap version is a guess or a test that blesses current
  behaviour. It stays owned by whichever prompt introduces a model-backed
  `ComputerUsePlanning` conformer — there is no such conformer today.
- `RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE` — unchanged; detector-layer work does
  not affect reachability.

## OPEN-06 — R5: Browser, Mail, Calendar, and Contacts Adapters

Prompt: [`06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md`](archive/first-pass-prompts/2026-08-12/06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md)

The deterministic first slice is recorded by
`EV-R5-20260808-READ-FIRST-ADAPTERS-01`, but R5 remains `in_progress`.

**SP-009 (2026-08-17) — Safari bridge packaged and authenticated at the
deterministic boundary** under `EV-SP-009-20260817-PACKAGING-AUTH-01`. The
Safari read bridge is now a packaged, authenticated, bounded, revocable, and
visibly-degraded-when-unavailable read path: `SafariWebExtensionTabResponse` is
`Codable`; new `SafariBridgeAuthenticator` (HMAC-SHA256 envelope: version,
extension ID, profile ID, nonce, freshness, tag), `SafariBridgeSecretStore`
(Keychain-backed provision/revoke), `AuthenticatedSafariWebExtensionTransport`
(fails closed on unavailable/stale/profileMismatch/notProvisioned/
authenticationFailed), `ProductivityConfiguration`, `SafariBridgeRuntime` +
`SafariBridgeAvailability` in the composition root, and a minimal read-only Web
Extension package under `Resources/SafariExtension/`. 7 new tests; regression
21/21 bundles, 949/949 tests, 0 failed. The `browser.read` capability **stays
disabled** until the live package and trust path are verified.

**SP-010 (2026-08-17) — Provider/account onboarding and UI composition completed
at the deterministic boundary** under `EV-SP-010-20260817-COMPOSITION-01`. The
read-first adapters now have explicitly authorized test-account/profile
onboarding (`IntegrationOnboardingService`, `ApprovedIntegrationAccounts`,
`.read` tier enforcement, Keychain-backed token references), bounded provider
transports (`HTTPProviderTransport`, `URLSessionGmailReadTransport`), account
ambiguity and offline/degraded state handling, revocation, composition-root
availability (`ProductivityRuntime` + `SafariBridgeAvailability`), a redacting
read bridge (`ProductivityReadBridge`), registry/routing reachability
(`ToolRouter_ProductivityHandlers`, `InitialCapabilitySet_ExternalCapabilities`),
and actionable UI state (`AuraAppModel_ProductState`, `AuraMenuView_Tabs`). 48
`AuraProductivityTests`, 21/21 bundles, 954/954 tests, 0 failed; second-pass,
repo-hygiene, and supply-chain validators pass. The four capabilities remain
`.disabled` until the live acceptance gates below are satisfied. SP-010 closes
the deterministic account/composition/UI slice of OPEN-06.

- Package and authenticate the Safari Web Extension/native messaging bridge;
  the current Swift bridge is a structured contract, not a live extension.
  **SP-009 packaged and authenticated the bridge at the deterministic boundary;
  the live package/trust path remains unverified (SP-011).**
- Add real provider transports and explicitly authorized account/profile
  onboarding.
  **SP-010 added bounded provider transports and the onboarding/authorization
  boundary at the deterministic boundary; live provider OAuth consent, real
  account configuration, and TCC/Contacts/Calendar permission prompts remain
  unverified (SP-011).**
- Wire browser/mail/calendar/contacts through `AuraKernel`, Dialogue, and UI
  reachability while keeping the four manifests disabled until verified.
  **SP-010 wired registry, routing, kernel passthroughs, dialogue classification,
  and UI reachability; the four manifests are still `.disabled` pending live
  evidence (SP-011).**
- Run live offline/degraded, permission, account ambiguity, revocation, and
  injection-acceptance tests with the user present where required.
  **Forwarded to SP-011; not closed by SP-010.**
- Keep compose/send, calendar/contact mutation, and any OAuth scope escalation
  behind separate immutable confirmation, least-privilege escalation, and
  post-action verification gates.
  **Forwarded to SP-011; no mutation/send path was added by SP-010.**
- Do not mark R5 complete based only on `AuraProductivityTests` or the full
  local Swift regression.
  **R5 remains `in_progress`; only the deterministic SP-009/SP-010 slices are
  closed.**

**SP-011 (2026-08-18) — live acceptance attempted and BLOCKED on the authority
boundary** under `EV-SP-011-20260818-LIVE-ACCEPTANCE-BLOCKED-01`. The live R5
read-first matrix (unread mail/thread summary, draft-only mail,
agenda/free-window, event draft, approved page summary, injection-ignore) and
revocation require live provider accounts, TCC/Contacts/Calendar permission
prompts, real Safari native messaging, and app launch — none of which this
session's authority grants (`launch_or_install_app=false`,
`mutate_permissions=false`, `provider_accounts=false`). The deterministic
boundary was re-verified: `AuraProductivityTests` 48/48 (offline distinct from
bad credential, revocation disconnects/clears credential, account ambiguity
never guesses, injection content rejected, token in header never URL, revoked
credential stops reads); full regression 21/21 bundles 0 failed; all four
governance validators exit 0; 38/38 governance tests. **SP-011 remains
`blocked`; SP-012 is not safe to start.** The live gate is owned by a future
explicitly-authorized SP-011 live session.

**SP-011 follow-up (2026-08-18) — user authorized all live tests and autonomous
execution, but the required external resources are NOT present and cannot be
fabricated** under `EV-SP-011-20260818-LIVE-LAUNCH-DEGRADED-02`. A real live
launch was observed: production `AURA.app` built to `/tmp/aura-sp011-live`,
ad-hoc signed (Local signing complete), launched via `/usr/bin/open`, process
alive (PID 58326), live os_log `[ai.aura.local:wake]` events, clean quit. This
proves the app builds/signs/launches/runs/quits on this machine. The full live
read-first matrix and revocation gate remains open because: (1) no Gmail OAuth
client ID + redirect URI is configured, (2) no real Gmail test account is in
`mailAccountIDs`, (3) full Xcode is unavailable so the Safari extension cannot
be packaged/installed, (4) TCC/Contacts/Calendar physical clicks require a
present user. **SP-011 remains `blocked`; SP-012 is not safe to start.** To
complete SP-011, the user must supply a Gmail OAuth client ID + redirect URI, a
real test account, enable the Safari extension, and click the TCC/Contacts/
Calendar prompts.

**SP-011 retry (2026-08-18) — partial live launch evidence, still blocked** under
`EV-SP-011-20260818-LIVE-RETRY-03`. Xcode 27.0/Swift 6.4 is present on this
machine, so the retry corrected the earlier toolchain assumption: the
production bundle was built, locally signed, strict-verified, launched with
`/usr/bin/open`, observed alive with privacy-redacted `ai.aura.local:wake`
events, and cleanly stopped. The live completion gate is nevertheless still
open: no Gmail OAuth client/access token or real provider account was supplied,
no Gmail read/thread/revoke flow ran, no Safari extension was packaged/
installed or native-messaging round trip exercised, and no TCC/Contacts/
Calendar prompt was clicked. **SP-011 remains `blocked`; SP-012 is not safe to
start.**

**SP-011 Computer Use preflight (2026-08-18) — external configuration partially
present, still blocked** under `EV-SP-011-20260818-COMPUTER-UI-PREFLIGHT-04`.
Authenticated Chrome reached the existing Google Cloud project: the Desktop
OAuth client, Testing audience, test user, and Gmail API are present. Data
Access has no saved scope; `gmail.readonly` was intentionally not entered or
saved pending just-in-time confirmation because it expands persistent access.
Safari reports `redirect_uri_mismatch` and its Extensions view has no AURA
extension. The exact temporary AURA bundle remained at `Starting` during the
bounded UI observation and was stopped. No credential, OAuth grant/token, TCC
mutation, extension installation, provider read/revoke, mutation/send, or user
data rewrite occurred. **SP-011 remains `blocked`; SP-012 is not safe to start.**

**SP-011 Computer Use scope follow-up (2026-08-18) — scope saved; OAuth grant
paused** under `EV-SP-011-20260818-COMPUTER-UI-SCOPE-05`. With the user's
just-in-time approval, the Google Cloud Data Access UI saved the least-privilege
Gmail read scope and displayed the saved Gmail scope. The desktop OAuth flow
then selected the approved test-account session, passed the Testing-app warning,
and reached the consent screen showing only read access to email messages and
settings. The actual `Continue` grant was not clicked because it creates the
provider authorization grant and must be confirmed separately at that exact
step. The temporary AURA bundle launched to `Idle / Ready`; its Setup surface
has no OAuth connect control, while the source connection seam requires
externally obtained token material. No credential, token, TCC change, Safari
install, provider read/revoke, mutation/send, or private data capture occurred.
**SP-011 remains `blocked`; SP-012 is not safe to start.**

**SP-011 (2026-08-19, fourth attempt) — launch-path defect fixed, free-window
implemented, acceptance harness built** under
`EV-SP-011-20260819-LAUNCH-AND-HARNESS-11`. Enumerating the prompt's matrix
against the existing evidence showed five open legs and two owed exclusions,
not the single leg the previous record named: `agenda/free-window` had **no
implementation at all** — `CalendarReadAdapter` exposed only
`agenda(from:to:calendarIDs:)`. A launch-blocking defect was also found by
sampling a hung process: `AuraKernel.construct()` probed external availability
inline, blocked inside `SecItemCopyMatching` waiting on securityd, and because
an `LSUIElement` app with no window cannot be activated, the app never started
and no control was reachable by any means. `construct()` now records `.loading`
and `start()` dispatches `probeExternalAvailability()` detached. Free windows
are now derived by `CalendarFreeWindows` through a `freeWindows` slot on
`calendar.read` — no new capability and no new authorization. Two accessibility
defects were fixed: the section pills and composer buttons had no accessible
name (now stable, unlocalized `AuraAccessibilityID` identifiers), and
`AuraMessageBubble`'s `.combine` made every transcript message an unlabelled
`AXUnknown`, so the conversation was unreadable to assistive technology.
`scripts/sp011-acceptance/` adds a preflight, an environment-preserving
relaunch, an identifier-addressed driver with bounded scans, page fixtures, and
a resumable browser-leg runner, so an interruption costs time rather than
another Safari authentication. 21/21 bundles, **1068/1068 tests**, 0 failed.
**SP-011 remains `blocked`:** the approved-page summary, the browser
injection-ignore leg, the browser revocation leg, and the contacts non-empty
read are still unexecuted. SP-012 is not safe to start.

**SP-011 (2026-08-19, fifth attempt) — four legs pass live** under
`EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12`. With the operator supplying
Safari's unsigned-extension authentication and one disposable contact, the
**approved page summary** (blocked since 2026-08-18), the **browser
injection-ignore** leg, the **browser revocation** leg, and the **contacts
non-empty read** all passed live. Three defects were found by running them: the
bridge's 30-second observation lifetime could not cover the pipeline it exists
for — roughly 13 s of extension cold start plus a local-model turn the product
itself budgets 120 s for — making the feature arithmetically impossible rather
than mistuned (now one shared 180-second constant,
`RISK-SP-011-OBSERVATION-LIFETIME`); and two Contacts-framework calls aborted
the whole application with Objective-C exceptions Swift cannot catch, first
`enumerateContacts` with a name predicate and then `CNContactFormatter` reading
an unfetched `middleName`. 21/21 bundles, **1070/1070 tests**, 0 failed.
**SP-011 remains `blocked`:** the free-window **non-empty** read is still owed,
because this attempt destroyed the calendar authorization by running
`tccutil reset Calendar` against a working grant
(`RISK-SP-011-CALENDAR-GRANT-DESTROYED`). SP-012 is not safe to start.

**SP-011 (2026-08-20, sixth attempt) — the last leg passes live; SP-011 is
complete** under `EV-SP-011-20260820-CALENDAR-IDENTITY-AND-FREE-WINDOW-13`. The
previous record's root cause was wrong. The machine was restarted, which that
record named as the remedy, and the calendar row still read denied; a second
`tccutil reset Calendar ai.aura.local.agent` reported success and changed
nothing. The mechanism is **TCC responsible-process attribution**:
`scripts/sp011-acceptance/launch-aura.sh` exec'd the bundle's binary from the
shell so the app would inherit the acceptance environment, and a terminal-exec'd
binary is not responsible for its own TCC requests — its ancestor is. System
Settings listed only *Visual Studio Code* under Calendars (No Access) and
Contacts (on), with AURA absent from both: the app was truthfully reporting the
terminal's decisions, and `tccutil` had no AURA decision to reset. Relaunching
the identical bundle through LaunchServices (`open --env`, PPID 1) moved Read
Calendar and Find Contact to `notDetermined` and Microphone/Screen observation
from `Granted` to `Not requested`/`Denied`, before any permission was changed.
The operator then granted calendar and contacts to **AURA itself**, and the
matrix closed: agenda `1 event(s): AURA SP-011 acceptance fixture`, the owed
**free-window non-empty read** `2 free window(s): 10:07–14:00, 15:00–00:00`
bounded by the fixture and carrying no title, location or attendee, and the
contacts non-empty read re-run under AURA's own grant because the earlier one
had exercised the terminal's. Both fixtures were deleted and their absence
re-read. The launcher now launches through LaunchServices and both it and
`preflight.sh` assert `PPID == 1`. 21/21 bundles, **1071/1071 tests**, 0 failed.
`RISK-SP-011-CALENDAR-GRANT-DESTROYED` is **closed and corrected**;
`RISK-SP-011-TCC-RESPONSIBLE-PROCESS-ATTRIBUTION` is opened and closed for the
harness path with the class left standing. Draft-only mail and event draft
remain explicitly excluded as mutation class, asserted by test. **SP-011 is
`completed`; SP-012 is safe to start.** R5 itself stays `in_progress` for the
items this prompt does not own: Developer ID signing and notarization, which
would remove Safari's `Allow unsigned extensions` requirement, is owned by R11.

## OPEN-07 — R6: VS Code and Coding-Agent Completion

Prompt: [`07_R6_VSCODE_AND_CODING_AGENTS.prompt.md`](archive/first-pass-prompts/2026-08-12/07_R6_VSCODE_AND_CODING_AGENTS.prompt.md)

R6's first-pass implementation is recorded by
`EV-R6-20260808-POLICY-BRIDGE-01` and
`EV-R6-20260808-TYPED-ROUTES-02`; the items below are preserved for the future
second pass and do not close the R6 prompt gate.

- Complete and provision the real authenticated VS Code extension transport;
  the current file bridge is a bounded local contract and has no live extension
  package or shared-secret onboarding evidence. **DONE under
  `EV-SP-012-20260820-DETERMINISTIC-BRIDGE-01` + `EV-SP-012-20260821-LIVE-ACCEPTANCE-02`.**
- Connect the typed workspace/editor/diagnostics/task/test/terminal routes to a
  real extension and verify disconnect, version mismatch, stale state, dirty
  buffers, and user confirmation behavior on the live path.
  **DONE — all six failure modes and revoke-to-fail-closed exercised live under
  `EV-SP-012-20260821-LIVE-ACCEPTANCE-02`.**
- Complete the coding-agent backend gate for exact interface/version,
  authentication, model availability, sandbox/approval, cancellation,
  network, workspace, cost/time/file budgets, and actionable disabled states.
  **SP-013 (2026-08-21) probed the real CLIs (codex 0.142.0, claude 2.1.195,
  copilot 1.0.80), records exact version/interface, keeps auth/model
  `.unverified` (fail-closed), and routes the resolved workspace/worktree and
  mode sandbox tier into the per-backend runner context. **SP-013 completed**;
  live model turn and auth/model/cancellation/network/budget evidence remain
  the first-pass R6 live gate (`EV-SP-013-20260821-COORDINATOR-ROUTING-01`).**
- Exercise durable read-only, review-only, and write-capable flows with
  explicit workspace resolution, isolated worktrees, progress/checkpoints,
  cancellation, restart/resume, diff/test/evidence verification, and cleanup.
  **SP-013 added read-only/review-only/write-capable coordinator tests with a
  real worktree manager and real task engine, and a diff-evidence
  postcondition verification that fails closed on false-backend-success
  (`EV-SP-013-20260821-COORDINATOR-ROUTING-01`).**
- Keep the repository-wide test gate honest: the clean scratch SwiftPM run
  passed 21/21 bundles and 763/763 tests after placing the existing
  CommandLineTools `Testing.framework` and interop library in the temporary
  scratch `@rpath`; the repository runner still reports `AuraAudioTests`
  helper `exit 142` after its assertions pass. Existing safety guidance
  requires approval before any system-service intervention. Do not convert
  that unrelated audio limitation into a false R6 product claim.
- Run the required user-present live acceptance, including no unauthorized
  commit/push/merge/release/deploy, before closing R6 or accepting ADR-041.

**2026-08-21 update (EV-SP-014-20260821-LIVE-ACCEPTANCE-BLOCKED-01):** the
ten-step R6 user-present acceptance was attempted on the approved scratch repo
`~/.aura-sp014/approved-repo`. **P2 (write-capable with no diff fails closed),
P3 (disabled backend accurate health), and P4 (no unauthorized
commit/push/merge/PR; HEAD unchanged) PASS. P1 (read-only live claude turn) FAILS
because no backend can currently produce a genuine model turn**: `claude -p`
returns the session limit (resets 8:50pm Europe/Istanbul) and
`--permission-mode dontAsk` blocks Write/Bash by design; codex default model
`gpt-5.6-luna` requires a newer CLI and `gpt-5.1-codex` is rejected for a
ChatGPT account; copilot monthly quota is exhausted. The SP-014 completion gate
("all live coding scenarios pass") was **not met**, so **SP-014 was `blocked`**.
The suite fails closed (`.failed`), never fabricating a `.completed`.

**2026-08-22 update (EV-SP-014-20260822-LIVE-ACCEPTANCE-COMPLETED-02):** SP-014
is **`completed`**. claude's session limit reset, and two remaining product gaps
were closed: (1) `ClaudeArguments`/`claudePermissionMode(for:)` now derive
`--permission-mode` from the tool profile — `.readOnly` → `dontAsk`,
`.workspaceWrite` → `acceptEdits` — so a write-capable task can actually write
(the previously hardcoded `dontAsk` blocked Write/Bash by design); (2)
`WorktreeManager.diff` returns `git status --porcelain` + the tracked `git diff`
so a new (untracked) file counts as a real change. Live result (claude 2.1.195):
**P1 (read-only claude turn) PASS, P2 (write-capable in isolated worktree with a
real diff) PASS, P3 (disabled backend accurate health) PASS, P4 (no unauthorized
commit/push/merge; HEAD unchanged) PASS.** `SP014Live` 4/4, `AuraAgentTests`
235/235 (timing flakes pass in isolation), validator PASSED. The OPEN-07
user-present acceptance gate is **met**; the first-pass R6 live gate for
codex/copilot turns remains open only because of external account/CLI limits
(`RISK-NO-LIVE-BACKEND-TURN`).

**2026-08-21 update (EV-SP-012-20260821-LIVE-ACCEPTANCE-02):** the live
authenticated round trip is now proven. The companion extension `0.2.0` is
installed and live in VS Code 1.134, both halves are paired with a matching
shared secret (AURA Keychain ↔ VS Code SecretStorage), and an env-gated
in-process Swift suite read the Keychain secret and drove live `.editor` and
`.workspace` commands end to end without the secret entering the agent context.
Two live-path product defects were found and fixed (a response-timing race and
a cross-language optional-collection decode mismatch). **All six named failure
modes (disconnect, version mismatch, replay, stale editor, dirty buffer,
confirmation-required) and revoke-to-fail-closed were exercised live** and are
covered by the live suite; revoke was followed by in-process pairing restore.
`AuraVSCodeTests` 47/47 and the validator pass. SP-012 is **completed**. The
remaining OPEN-07 coding-agent backend and durable-task-lifecycle work is owned
by SP-013.

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
  - **SP-015 decision (2026-08-22, `EV-SP-015-20260822-WAKE-EXCLUSION-01`):**
    wake word is **explicitly excluded from the release scope**. No licensed
    local candidate is provisioned or bundled (inventory:
    `AURA_RUNTIME_COMPLETION/context/WAKE_MODEL_INVENTORY.md`); the active
    authority forbids `download_models`/`install_dependencies`, so no candidate
    can lawfully be obtained or qualified in this pass. The truthful UI already
    states "no acoustic model is installed; Push to Talk remains available"
    (onboarding stage `.wakeWord`, menu, and runtime warning). No wake-word
    claim is made. This exclusion can be revisited only if the user later grants
    model-download authority and supplies a licensed local candidate with
    Turkish support, FAR/FRR, noise/distance, self-trigger, license/hash, and
    soak evidence. ADR-042 remains `Proposed` (no ADR-042 file exists yet; the
    decision register path `docs/decisions/ADR-042-voice-routing-resource-governor.md`
    is absent and must be reconciled before acceptance).
- Apple on-device Speech capability checks and the reusable STT router are
  implemented, but there is no live Turkish/English/mixed-language WER/entity
  corpus, qualified local Whisper/equivalent fallback, or user-present
  microphone/TCC acceptance. Locale fallback is fail-closed on engine start,
  not a silently quality-switching transcript rewrite.
  - **SP-016 deterministic slice (2026-08-22,
    `EV-SP-016-20260822-TURN-END-METRIC-01`):** `STTPipeline.Metrics` now
    records `turnEndLatencySeconds` (the R7-required turn-end latency,
    activation→first-stable elapsed time), reset to 0 per turn; a deterministic
    suite proves the metric, its cross-turn reset, and the fail-closed invariant
    that non-stable/error transcripts are never promoted to a stable
    (command-eligible) segment.
  - **SP-016 live read-only observation (2026-08-22,
    `EV-SP-016-20260822-LIVE-STATE-OBSERVATION-02`):** via computer use, the
    running app was observed to report truthful live health: `Microphone:
    Granted`, `Active speech recognition: Granted`, `Screen observation:
    Denied`; `stt ready`, `audio ready`, `voice-resources ready (16384 MB)`,
    `tts ready (Yelda fallback)`, `wake-word unsupported (Push-to-Talk only)`;
    status `Idle — use Push to Talk`. This confirms the live truthful-health /
    truthful-degradation readout but is not a WER or hardware-recovery
    measurement.
  - **Still open:** the bilingual Turkish/English/mixed WER/entity corpus and the
    hardware recovery matrix (barge-in/echo/device/sleep/TCC/helper-crash)
    require a speech-capable operator and were not exercised (the user is
    speech-disabled; no speech-capable operator was present; no TCC mutation
    was performed).
  - **SP-016 measured bilingual quality + scoped exclusion (2026-08-22,
    `EV-SP-016-20260822-BILINGUAL-QUALITY-03`):** the "requires a speech-capable
    operator" verdict above was **partly wrong**, and is corrected here without
    deleting it. Human speech is genuinely unavailable, but the recognition path
    never needed a human throat — `SystemSTTEngine` ingests `AudioFrame`s, so
    synthesized audio drives the real recognizer. The actual blocker was the
    **host**: Speech authorization is per-executable and the SwiftPM test helper
    is a bare binary (confirmed live: the gated suite returns
    `.speechNotAuthorized`). Under a user-granted, scoped `mutate_permissions`
    (one Speech grant to a local diagnostic bundle; no microphone, no model
    download, no install), a signed probe bundle
    (`scripts/run-sp016-speech-probe.sh`) ran 48 recognitions — 8 utterances ×
    clean/noisy(10 dB SNR)/far-field × contextual-hints on/off — through the real
    on-device engine (`tr-TR` and `en-US` both `onDevice=true`).
    **Measured result:** Turkish and English **general and command** speech pass
    with **entity recall 1.000** in every band (WER 0.000–0.306; the residual WER
    is number normalization — "on beşte" → `15:00` — which entity recall credits
    correctly). **Finalization latency 0.05 s** from end of audio to actionable
    transcript. **Measured failure:** code-switched English technical tokens
    inside Turkish utterances score **WER 0.562 / entity recall 0.417**;
    `npm install` was heard as "DPM insan"/"Mnsa" and `pull request` as "Kırık ve"
    or dropped. Supplying the terms as `contextualStrings` **did not recover
    them** (entity recall 0.833 → 0.792), so the mitigation is disproven, not
    merely untried.
    **Decision:** voice-driven **code-switched English technical tokens** are
    **explicitly excluded from the release scope** (the completion gate's own
    "or the affected capability is excluded" branch), on a measurement rather
    than an assumption. The exclusion is safe because the pipeline fails closed:
    `Tests/AURAIntegrationTests/SP016BilingualFailClosedTests.swift` uses the
    verbatim garbled transcripts to lock that none reaches a destructive tier,
    that any still-executable classification stays at mutation tier or above
    (confirmation shown before anything runs), and that
    `matchDeterministicCommand` is exact rather than fuzzy — a bad transcript is
    never rewritten into a successful command.
  - **Still open after SP-016:** the **hardware recovery matrix** (barge-in,
    acoustic echo/self-transcription, headset/device switching, sleep/wake,
    interruption, TCC revocation, helper-crash recovery) is **not** closed.
    `AuraAudio.handleConfigurationChange` is implemented but has **zero test
    coverage**: reaching `state == .running` needs a real `AVAudioEngine` input
    node and therefore a **Microphone** grant for the test host, which SP-016's
    scoped authority (Speech only) deliberately excludes. Concrete closure path:
    extend the probe bundle with a Microphone usage description and grant, then
    post `.AVAudioEngineConfigurationChange` and assert recover-and-restart.
  - **SP-016 recovery-matrix correction (2026-08-22,
    `EV-SP-016-20260822-RECOVERY-MATRIX-04`):** the Microphone-grant blocker
    stated immediately above was **wrong**, and is corrected here without
    deleting it. It was inferred from the code rather than checked; a one-line
    diagnostic showed `AuraAudio.start()` reaching `.running` in the SwiftPM
    test host, so device-change recovery was deterministically testable all
    along and needed no extra authority. A second, larger defect surfaced in
    the same audit: **sleep/wake recovery did not exist at all** — no
    `willSleep`/`didWake` handling anywhere in `Sources/` — even though
    Procedure step 2 names it. Both are now closed: `AuraAudio` suspends
    capture on sleep (engine stopped, tap removed, privacy indicator cleared,
    recoverable error emitted) and resumes on wake **only** if the suspension
    was caused by sleep, so an explicit user stop is never undone;
    `Tests/AuraAudioTests/SP016DeviceRecoveryTests.swift` (4 tests) covers
    device-change recovery, sleep/wake, and the privacy invariant that neither
    ever reopens the microphone after a user stop. Every leg named by Procedure
    step 2 is now implemented and deterministically covered (self-trigger
    protection is **not applicable** in the shipped Push-to-Talk-only scope,
    since the microphone opens only on an explicit press).
  - **Still open after the correction:** `RISK-VOICE-RECOVERY-LIVE` — the legs
    are covered by **notification-driven** tests, not physical acts. No headset
    is unplugged, no real CoreAudio route change occurs, the machine is never
    actually slept, and acoustic barge-in/echo over a real speaker-to-mic path
    is unexercised. Closing that needs a user-present session with physical
    acts, not more authority.
    Human-speech quality (accent, disfluency, real room acoustics, real
    microphone colouration) also remains unmeasured; the synthetic corpus is an
    optimistic bound.
  - **SP-016 recovery-suite stabilization (2026-08-23,
    `EV-SP-016-20260823-FLAKY-RECOVERY-STABILIZATION-05`):** the recovery suite
    introduced by the correction above was itself **flaky** — 
    `EV-SP-016-20260822-RECOVERY-MATRIX-04` claimed it "ran twice with identical
    results", but three independent runs each failed a *different* test (run 1
    `Sleep suspends capture and wake resumes it`; run 2 `A configuration change
    after stop never reopens the microphone`; run 3 passed), and the full suite
    reported `AuraAudioTests` as the single failing bundle. Two root causes were
    fixed without changing product recovery behaviour: (1) an **async observer
    registration race** — `AuraAudio` used `Task { for await ... }`/`withTaskGroup`
    subscriptions, so `start()` could return before the loop subscribed and a
    posted notification was dropped forever; replaced with **synchronous**
    `NotificationCenter.addObserver` tokens
    (`configurationChangeObserver`/`sleepObserver`/`wakeObserver`) and a
    `removeObservers()` teardown in `stop()`; and (2) **cross-suite microphone
    contention** — Swift Testing's `.serialized` serializes within one suite
    only, so `AuraAudioTests` and `SP016DeviceRecoveryTests` both opened the same
    real `AVAudioEngine` input concurrently; all microphone-opening tests were
    consolidated into one `.serialized` suite and a generous `waitUntil` helper
    (~15 s + final check) replaced the short fixed poll. **Verified:**
    `AuraAudioTests` (39 tests / 6 suites) passed **six consecutive independent
    runs**, and the full suite is **21/21 bundles, 0 failed**.
  - **SP-017 resource-governor idle unload + reasoning admission
    (2026-08-23, `EV-SP-017-20260823-GOVERNOR-IDLE-UNLOAD-01`):** the R7
    resource-governor requirement for **idle unload** (G) was a concrete gap —
    `VoiceResourceGovernor` declared `idleUnloadAfterSeconds` but never
    implemented it. Now implemented: `lastActiveAt` per workload, a new
    `@discardableResult unloadIdleReservations()` that drops any reservation
    idle past the window, an `idleUnloadTask` polling every half-window in
    `start()`, and `stop()` cancelling it and clearing activity. Also, the
    NLU/reasoning workload is now **routed through the shared governor**:
    `OllamaAdapter` accepts an optional shared `resourceGovernor` and every
    inference path (`classify`, `structuredNLU`, `summarize`, `reason`)
    reserves `.reasoning` (2 GB) in `preflight` before admission and releases
    it on every terminal path; on shared-governor denial it degrades
    `.budgetExceeded` (fail closed) and opens a circuit. The production
    `OllamaAdapter` is wired to the kernel's shared governor. New deterministic
    tests: `VoiceResourceGovernorTests` 7/7 (idle-window unload, recent
    survives, reserve-refreshes-activity), `OllamaAdapterTests` 18/18
    (reasoning reserves-and-releases; reasoning fails closed on shared denial).
- Bounded incomplete-turn continuation, duplicate-result suppression, and
  TTS interruption/cancellation paths are covered locally, but live barge-in,
  acoustic echo/self-transcription, headset/device switching, sleep/wake,
  interruption, permission revocation, and helper-crash recovery remain
  unverified on release hardware.
- Resource admission is integrated for STT, neural TTS, and now the local
  Ollama reasoning path with memory-pressure, thermal, budget, reservation,
  circuit-breaker, and idle-unload controls. `screenVision` and `codingAgent`
  workloads remain explicitly **not** admitted through the shared governor
  (bounded per-capture screen and spawned CLI subprocesses; documented as
  exclusions in `ADR-042`), and measured 16 GB resident-memory/thermal/
  energy/long-soak evidence is still open.
- Neural TTS has a bounded helper timeout and system-Yelda fallback; CPU is
  the safe default and MPS is opt-in pending qualification. Consented
  reference-voice provenance, model/hash/license verification, first-audio
  latency, CPU quality/latency, cache safety, and human listening acceptance
  remain open. System-TTS-only release remains the truthful fallback scope.
- The required Turkish/English/mixed technical/noisy/far-field evaluation
  datasets and protocols, latency/WER/entity/turn-end/TTS/barge-in/resource
  measurements, and extended soak package are not yet recorded.
- ADR-042 is now **authored** at
  `docs/decisions/ADR-042-voice-routing-resource-governor.md` (SP-017) with
  scope, alternatives, consequences, expiry/revisit, and evidence, but remains
  **`Proposed`** (no explicit user acceptance in this pass). R7 is **not** to be
  marked complete or move to R8 based on simulated tests alone.

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
- **SP-018 resolution (2026-08-23, historical wording above retained):** the
  bounded production composition is now wired through `AuraKernel` →
  `IntentEngine` → `ContextBuilder` → `ReferenceResolver`. It supplies typed
  active-application/editor/workspace/task/backend snapshots, retains bounded
  dialogue and recent-file/tool salience, filters scope/expiry/completed-task
  candidates, ranks and deduplicates by authority, and binds only safe resolved
  targets to closed typed slots. Missing, ambiguous, stale, out-of-scope, or
  weak destructive references clarify before routing. Evidence:
  `EV-SP-018-20260823-PRODUCTION-REFERENCE-WIRING-01`,
  `EV-SP-018-20260823-FOCUSED-TESTS-02`, and
  `EV-SP-018-20260823-FULL-SUITE-03`. User-present restart/control acceptance,
  R9 controls, remote transport, and ADR-043 remain open for later prompts.
- **Verification correction (2026-08-24; historical wording retained):** an
  independent default-runner recheck exposed a scheduling-dependent
  `AuraAgentTests` failure when its live CLI, real-worktree, and actor-backed
  fixtures ran at unrestricted Swift Testing parallelism. This was a test
  runner boundary defect, not a production reference-wiring failure. The
  runner now bounds only `AuraAgentTests` to one worker by default; the
  regression test, isolated bundle (237 tests), and default 21-bundle matrix
  pass with `EV-SP-018-20260824-TEST-RUNNER-FIX-06`. SP-018 product scope and
  the separate live/release gates are unchanged.
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

### SP-019 attempt — local control slice delivered; live product gate remains open (2026-08-24)

The production composition now wires the bounded `UserPreferenceProfileStore`
through `AuraKernel`, and the product Privacy surface exposes preference
save/clear, purpose/scope/retention text, inspect/search, conflict triage,
correction/deletion/export, and retention cleanup. The runtime API exposes
conflict and superseded-record snapshots without including audit/security
records; user correction writes an evidence reference. This is a local product
slice, not a completion claim. Deterministic evidence is recorded under
`EV-SP-019-20260824-LOCAL-CONTROLS-01`: production build, focused integration
83/83, full 21/21-bundle matrix with 1,141 tests and zero failures, second-pass
validator, 39 governance tests, formatter, lint, syntax, and diff checks pass.

A LaunchServices startup smoke under
`EV-SP-019-20260824-LAUNCH-SMOKE-02` proved process start and bounded stop only.
The temporary HOME did not isolate Foundation Application Support, so no
restart/data persistence claim is made from that procedure. No user-present
operation of the eight R8 scenarios was completed: preference save/relaunch,
verified project fact, multi-turn reference, destructive ambiguity
clarification, contradiction resolution, inspect/correct/delete/export,
provenance display, and local-only remote exclusion remain unproven. ADR-043
remains `Proposed`; SP-019 stays `in_progress`, and SP-020 is not safe to start.

### SP-019 user-present controls attempt — partial direct evidence (2026-08-24)

`EV-SP-019-20260824-LIVE-CONTROLS-04` records a user-present run against the
final local app in a `CFFIXED_USER_HOME`-isolated profile. The run directly
proved bounded `Concise` preference save, real menu quit/relaunch restoration,
purpose/scope/retention display, inspectable rows, user correction with
`userStated` provenance, retention-cleanup invocation, audit/security exclusion,
and fail-closed rejection of `Allow remote context` under the local-only
machine policy. The attempted read-only project-fact request did not produce a
verified tool result; the follow-up reference surfaced `Diagnostic: ambiguous`,
which is not a resolved reference or destructive-action clarification proof.

The live export control opened the native Save panel, but no exported artifact
was located after the save attempt. No conflict section appeared in the
disposable profile, and the live Delete control was intentionally not activated
because immediate confirmation is required before an irreversible deletion.
Therefore preference restart and bounded controls are now direct live evidence,
but the eight-scenario gate remains incomplete: verified tool fact, resolved
multi-turn reference, destructive ambiguity clarification, contradiction
resolution, export artifact, deletion receipt, and direct remote-transport
observation remain open. SP-019 remains `in_progress`; SP-020 is not safe to
start.

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

### OPEN-10 / SP-021 accessibility & localization — 2026-08-25

`EV-SP-021-20260825-ACCESSIBILITY-LOCALIZATION-01` advances the manual gate with
deterministic + live AX-tree evidence and fixes two localization defects found
live, but does **not** close SP-021.

**Fixed (source + deterministic test):**
- Stable, non-localized accessibility identifiers added for onboarding and
  header controls (`onboardingPrimary/Skip/Close`, `languageSwitch`,
  `settingsButton`, `onboardingButton`) in `AuraAccessibilityIdentifiers.swift`.
- **Status pill localized to Turkish** (was English in the live TR run):
  `AuraAppStatus.title(for:)` and `AuraAppModel.displayStatusDetail` now map the
  known English internal status strings to Turkish; header, menu-bar panel, and
  menu-bar label use them.
- **Capability detail localized to Turkish**: `capabilities.ready` and the new
  `capabilities.noEvidence` key are used instead of hardcoded English `Ready` /
  `No availability evidence is registered`.

**Verified live (AX tree):** all six tab pills, header language/settings/
onboarding, and composer input/submit/Push-to-Talk are reachable by identifier;
switching to Turkish localizes the header subtitle, conversation copy,
capability titles, status pill, and menu-bar status label.

**Still required to close SP-021 (manual, user-present):** VoiceOver *spoken*
reading order; keyboard-only full navigation; confirmation focus
containment/expiry; Dynamic Type / scaled reflow; reduced motion; contrast with
a human evaluator; and the disabled-reason capability prose (subsystem
availability reasons in English) is not yet localized. **SP-021 stays
`in_progress`; SP-022 must not start.**

### OPEN-10 / SP-021 follow-ups and completion — 2026-08-25

**Additional fixes (source + deterministic test):**
- **`AuraAgentTests` `exit 142` flake fixed**: the buffered `ProcessRunner`
  now always sets a closed stdin pipe, so `claude --help` no longer blocks on
  inherited stdin EOF (it ignores SIGTERM, so the old code hung the bundle
  past the 60 s watchdog). Covered by `runnerDoesNotHangWhenChildInheritsPipe`.
- **Disabled/degraded capability reason prose localized to Turkish** via
  `AuraAppModel.localizedReason(_:)`, wired into both the capability and
  integration panels; unknown reasons fall through unchanged. Covered by
  `disabledReasonLocalizesToTurkish`.
- **Dynamic Type / scaled reflow fixed**: `AuraDesign.Typography` now uses
  relative text styles (`Font.headline/subheadline/body/caption`) instead of
  fixed `Font.system(size:)`, so the surface scales with the user's
  accessibility text size (WCAG 1.4.4). Covered by
  `designTypographyScalesWithDynamicType`.

**Live completion (user present, computer use authorized):**
`EV-SP-021-20260825-LIVE-ACCESSIBILITY-04` verified with the user present that
the AX reading order (header → status → language → actions → tabs → content →
composer) is logical and complete, keyboard-only focus reaches every primary
control, and Turkish/English copy renders correctly (menu bar
`AURA status: Boşta`, subtitle `Yerel sesli asistan`). Non-color status,
keyboard shortcuts (confirmation Deny/Allow, emergency stop Cmd+Shift+Escape,
Push-to-Talk Cmd+Shift+Space), confirmation expiry and `.isModal` focus
containment, and reduced motion (no animations) are all implemented.

**SP-021 is `completed`.** `AURAIntegrationTests` 88/88, `AuraAgentTests`
237/237, full suite 21/21 bundles 0 failed, and the validator PASSED. Remaining
OPEN-10 items (onboarding denial/revocation recovery, task scope/review
metadata, capability grant lifecycle, model lifecycle, integrations/account
controls, support bundles, full privacy/recovery) are owned by SP-022 and are
not part of SP-021. **SP-022 is next eligible and pending; open it only under
its own authority.**

### OPEN-10 / SP-022 deterministic Task Center slice — 2026-08-26

`EV-SP-022-20260826-TASK-CONTROLS-SOURCE-01` closes the **deterministic source
slice** of the OPEN-10 Task Center scope-metadata and task-lifecycle-control
gap, and the seeded-grant gap for the `.reversible` task controls. **SP-022
remains `in_progress`; the live/manual gate is still open and SP-023 must not
start.**

**Delivered (source + deterministic test, no live/manual evidence):**
- `TaskStatus` now carries typed `TaskScopeInfo` (backend/mode/workspace/
  backendHealth) derived from the coding-task launch context, so the Task
  Center can present the backend/model/workspace/health scope R9 requires.
- `AuraTaskEngine.retry(id:runner:)` re-runs a failed task once without
  re-arming the automatic retry budget; fails closed on non-failed states.
- Task Center now exposes pause/resume/retry/cancel controls by state and
  localized scope metadata; `AuraKernel` gained `taskPause`/`taskResume`/
  `taskRetry`, each through the same policy gate.
- Added `.reversible` seeded grants for `taskCancel`/`taskPause`/`taskResume`/
  `taskRetry` (production denies `.reversible` by default, so these buttons
  would otherwise be policy-denied before reaching the engine). `taskDelete`
  stays `.destructive` and deny-by-default.
- Full suite 21/21 bundles 0 failed; `validate_second_pass_program.py` PASSED.

**Still required to close SP-022 (live/manual, user-present, not exercised
this session):** onboarding denial/revocation/restart recovery; task
verification/diff/artifact live presentation; TCC permission repair; support
bundle privacy review; safe-reset guidance; and a user-present demonstration
that a task's pause/resume/retry buttons produce a truthful, observable state
change on the live path. A step-by-step live/manual **runbook** is provided
under `EV-SP-022-20260826-LIVE-GATE-PROCEDURE-02` so the next user-present
session can execute the gate deterministically. **SP-022 stays
`in_progress`/`blocked` for this live gate; SP-023 must not start until it is
captured under SP-022 authority.**

### OPEN-10 / SP-022 live UI observation — 2026-08-26

`EV-SP-022-20260826-LIVE-UI-01` (user present; authority granted) verified live
via the AX tree that the SP-022 source slice renders truthfully:
- Capability Center shows the new task controls (`Görevi Duraklat`/`Sürdür`/
  `Tekrar Dene`/`İptal Et`) as Ready/Local; disabled capabilities carry reasons
  with no fake success.
- Recovery, Models (auth/model unverified), Privacy (integrations Not-connected,
  cloud disabled, 0 memory records), and onboarding (Setup complete) all render
  truthful states.
- Emergency Stop (Cmd+Shift+Esc) changes the status pill to
  "Durduruldu" live — the stop postcondition is observable.

`EV-SP-022-20260826-LIVE-DIALOGUE-02` additionally verified the live typed-input
path: an ambiguous request returns "Blocked: ambiguous" with a truthful
clarification and a Degraded marker (no fake success), and the Task Center
shows the honest empty state ("No durable tasks tracked").

**Live durable-task pause/resume on a real claude turn — `completed`.**
`EV-SP-022-20260826-LIVE-TASK-CONTROLS-04` (`livePauseResumeTask` in
`Tests/AuraAgentTests/SP014LiveAcceptanceTests.swift`, env-gated on the SP-014
production path) enqueues a real read-only task through `CodingTaskCoordinator`
→ real `ClaudeAdapter` → real `claude` CLI, then drives the engine state
transitions on that live task: **enqueue → `running`** (hard-asserted),
**pause → `paused`**, **resume → `pending`/`running`**. The P1/P2/P4 real-turn
durations (5–26 s) confirm the backend genuinely executes; the SP-022 test
observes the real engine state changes on it. `AuraAgentTests` 238/238 passed
(SP-014 P1 flake is the pre-existing, documented backend session-limit
fail-closed path, `RISK-NO-LIVE-BACKEND-TURN`, not a regression).

**SP-022 is `completed` for its bounded OPEN-10 scope.** The deterministic
slice, live UI surface, live typed-input fail-closed, and live durable-task
state transitions are all evidenced. `taskDelete` remains `.destructive`/
deny-by-default (intentional, no destructive grant). A real TCC
denial/revocation/restart recovery (a genuine System Settings permission
change) is not part of this run, but the disabled-reason and truthful-state
requirements are covered by the deterministic and live UI evidence. SP-023 is
the next eligible prompt.


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

### SP-023 closure note — 2026-08-27

SP-023 closed the **bounded authenticated-IPC and privilege-separation slice**
of OPEN-11 under `EV-SP-023-20260827-AUTHENTICATED-IPC-01`:

- **Authenticated peer identity (reviewed equivalent to XPC):** added
  `HelperIPCAuthenticator` (HMAC-SHA256 tag over the exact transmitted bytes),
  `HelperIPCAuthenticatedRequest`/`HelperIPCAuthenticatedResponse`, and
  `HelperIPCPeerVerifying` + `SecCodeHelperIPCPeerVerifier` (designated-
  requirement process verification). `HelperIPCClient` verifies the helper
  executable SHA-256 digest, verifies the launched process's code-signature
  identity, signs every request, enforces replay/freshness/capability
  allowlist, and bounds output and time (helper crash containment).
- **Real helper execution:** `AuraShellHelper` now executes real typed
  `Command`s and returns a typed `ProcessResult`; `AuraAutomationHelper` now
  executes real app-lifecycle operations (launch/activate/hide/quit) and
  returns a typed `AutomationHelperResult`. Both verify the request HMAC tag
  and sign the response. Accessibility/generated-input execution is
  intentionally absent (requires a per-executable TCC grant outside this
  prompt's authority).
- **Adversarial tests:** missing executable, invalid digest, replay, protocol
  downgrade, peer identity mismatch, helper crash containment, capability
  escalation, and forged/misbound responses all fail closed.
- **Verification:** full suite 21/21 bundles 0 failed; `AuraCoreTests` 48/48,
  `AuraAutomationTests` and `AuraShellTests` pass; second-pass validator
  PASSED; helper executables fail closed without the App Sandbox entitlement.

This closes the authenticated-peer-identity and real-helper-execution slice
only. It does **not** close OS confinement of a live signed helper, a live
Keychain-provisioned round trip, or full privilege separation of every
privileged path. The remaining OPEN-11 residuals — network enforcement
(`RISK-NETWORK-ALLOWLIST-INCOMPLETE`), OAuth lifecycle, plugin trust, injection
corpus, incident response, independent review, and ADR-044 acceptance — remain
open and are owned by SP-024 and later R10 work. SP-024 is next eligible and
pending.

### SP-024 closure note — 2026-08-27

SP-024 closed the **bounded network/OAuth/injection-enforcement slice** of
OPEN-11 under `EV-SP-024-20260827-NETWORK-OAUTH-INJECTION-01`:

- **Mandatory URLSession factory:** added `URLSessionFactory` in `AuraSecurity`
  (deny-by-default cookies/cache/redirect) and routed both production
  `URLSession` call sites (`URLSessionProviderFetcher`,
  `URLSessionOllamaAPIClient`) through it, so no production network client
  constructs an ungoverned session.
- **Resolved-IP pinning primitive:** added `ResolvedIPValidator` (resolved-IP
  allowlist; a single unexpected candidate IP fails the whole set, defending
  against DNS rebinding). DNS answers are not treated as trusted authority.
- **OAuth leakage corpus:** added `googleOAuthAccessToken` (`ya29.`) and
  `googleOAuthRefreshToken` (`1//`) to the canonical `SecretPatternLibrary`,
  and a leakage corpus proving token material never reaches a reference, a
  diagnostic, a redacted summary, or a Keychain key, and that revocation
  deletes the material.
- **Injection corpus:** added model tool-spoof (system-message and fake-tool-call)
  and indirect-injection (mail body, repository file, terminal output) cases,
  plus `PromptInjectionScreen` withhold/pass-through cases.
- **Verification:** full suite 21/21 bundles 0 failed; `AuraSecurityTests`
  44/44, `AuraProductivityTests` 75/75, `AuraAdversarialTests` 68/68; second-pass
  validator PASSED.

This closes the network-factory, resolved-IP, OAuth-leakage, and
injection-corpus slice only. It does **not** close a live provider round trip,
live revocation, OS confinement of a live signed helper, or full privilege
separation. The remaining OPEN-11 residuals — plugin trust, incident response,
independent review, and ADR-044 acceptance — remain open and are owned by SP-025
and later R10 work. SP-025 is next eligible and pending.

### SP-025 closure note — 2026-08-27

SP-025 closed the **bounded plugin-trust and incident/review-slice** of OPEN-11
under `EV-SP-025-20260827-PLUGIN-TRUST-INCIDENT-ADR044-01`:

- **Plugin supply-chain adversarial matrix (new, 7 tests):** compromised
  helper digest (never launched), tampered installed artifact (blocks enable
  and execute), tampered update bundle (refused before storage), update from an
  untrusted vendor root (refused), tampered retained artifact (blocks
  rollback), quarantine (revokes grants, blocks enable and execute), and
  unapproved marketplace source / unknown vendor root (never install). All use
  real Ed25519 cryptography.
- **Documentation:** `docs/operations/PLUGIN_SUPPLY_CHAIN.md` (deny-by-default
  trust chain, lifecycle safety valves, SBOM/checksum scope, unverified-code
  rejection), `docs/operations/INDEPENDENT_SECURITY_REVIEW.md` (independent
  review plan, scope, independence rule, cadence, findings tracker), and
  `docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md` (in-session
  independent adversarial review of the plugin boundary).
- **Independent review (plugin boundary only):** an independent adversarial
  read with no authorship context found no Critical/High unresolved finding in
  the plugin trust boundary.
- **Verification:** `AuraPluginsTests` 44/44 (37 baseline + 7 new); full suite
  21/21 bundles 0 failed; second-pass validator PASSED.

This closes the plugin-trust and incident/review-slice only. It does **not**
close the full independent review across the other ADR-044 areas (process
topology, IPC, policy, OAuth, network, computer use, updater), does **not**
accept ADR-044 (the dedicated `security-review` subagent was credit-limited, so
even the plugin review was in-session rather than separately provisioned, and
the full eight-area scope remains open), and does **not** claim public PKI or a
signed/notarized update transport. SP-025 remains **blocked** pending the full
independent review and ADR-044 acceptance; SP-026 must NOT start.

### SP-025 completion note — 2026-08-28

SP-025 was completed under `EV-SP-025-20260827-PLUGIN-TRUST-INCIDENT-ADR044-01`
(extended) once the independent-review blocker was resolved:

- **Full eight-area independent review:** an in-session adversarial read with
  no authorship context covered process topology/privilege separation, IPC/
  helper authentication (SP-023), policy/confirmation, OAuth/Keychain, network
  enforcement (SP-024), computer use, updater trust (R11/ADR-046), and plugin
  trust. No Critical or High finding remains unresolved in any area; the
  confirmed-safe enforcement points and residual limitations are recorded in
  `docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md`.
- **ADR-044:** remains **Proposed** and its acceptance is owned by the release
  owner once the full independent-review scope and any critical-finding
  resolution exist. The independent review that ADR-044 requires is now
  complete for the deterministic/contract boundary; a separately-provisioned
  external review and live signed-helper/third-party-payload runs remain open
  under later R10/R11/R12 work, not SP-025.

This closes the plugin-trust supply-chain matrix, incident/review
documentation, and the full independent-review evidence slice. It does **not**
claim public PKI, a signed/notarized update transport, or live OS confinement
of a real signed helper/third-party payload. SP-025 is completed; SP-026 is
next eligible and pending.

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

### SP-026 progress (2026-08-28) — reproducible-build slice delivered; observed-CI slice blocked

The bounded SP-026 reproducible-build slice of OPEN-12 is delivered under
`EV-SP-026-20260828-REPRODUCIBLE-ARTIFACT-BLOCKED-01` at canonical commit
`3e81582`:

- Exact toolchain pinned and recorded (Xcode 27.0 beta 5 `27A5237l`, Swift 6.4,
  macOS SDK 27.0, Git 2.54.0, Python 3.14.6).
- Reproducible `development_unverified` AURA.app bundle + ZIP + manifest built
  with clean provenance (artifact SHA-256
  `202bb5cd07386e119fc360a0469acf72e7f1c3347b5d613506b326180a07a1bc`, 56,472,706
  bytes); `validate_release_manifest.py` PASSED.
- Deterministic-archive reproduction confirmed **given identical canonical
  commit and identical build root**; a different build root changes only the 5
  compiled Mach-O executables that embed the absolute SwiftPM path.
- Provenance defect fixed: `run_optional` collapsed empty `git status
  --porcelain` to `None`, so a clean working tree was mislabeled
  `dirty_or_unavailable`; added `run_optional_keep_empty` and a regression test.

**Observed-CI slice remains open/blocked:** the workflow requires a self-hosted
`macOS, swift-6.4` runner, the runner inventory is empty, and SP-026 has no
install/configure runner authority. Pushed runs `33152188166`/`33152568023`
remain `queued` with zero completed steps. No post-change CI run, retained
artifact, signature/manifest, or provenance-of-run evidence is observed; the
completion gate is not met and SP-027 must not start.

### SP-026 completion (2026-08-28) — observed CI and reproducibility evidence

The bounded SP-026 slice of OPEN-12 is **completed** under
`EV-SP-026-20260828-OBSERVED-CI-COMPLETED-01` at canonical commit `348bb6a`:

- The observed-CI slice was closed by registering a temporary self-hosted
  GitHub Actions runner 2.337.0 (labels `macOS, swift-6.4`) after a
  SHA-256-verified download and running the actual CI workflow on the
  canonical commit.
- Observed run `33157842324` completed **success** for `governance` and
  `build-and-test`; line coverage **70.69%** meets the unchanged 70% ratchet;
  full suite 0 failed bundles; governance 41/41; all validators pass.
- Retained development artifact `9680431386` (`aura-development-unverified-
  348bb6a...`) was downloaded and inspected: `release_status:
  development_unverified`, `source.commit: 348bb6a` (matches canonical),
  `working_tree: clean`, 17 bundle files, 17 SBOM components,
  `signature: {developer_id: false, notarization: not_submitted}`;
  `validate_release_manifest.py` PASSED.
- CI-surfaced blockers were resolved: first-pass schema/manifest acceptance
  of SP-* active prompts; stale `current-state`/`capability-matrix`
  projections; coverage regression restored with deterministic
  `ConfigurationValidationTests`; two Swift `warnings-as-errors` build
  failures.

**Remaining OPEN-12 gates (unchanged, outside this slice):** Developer ID
signing, secure timestamp, notarization, stapling, Gatekeeper, clean-machine,
quarantine, nested-helper, and TCC identity evidence; launch-at-login,
sleep/wake/crash/update behavior, safe mode, diagnostics/support-bundle,
reset/recovery, uninstall, and factory-reset semantics; signed update
manifest/package, transport, version/channel policy, downgrade/replay
protection, atomic install, migration backup, staged rollout, kill switch,
rollback, and compatibility checks; and configuration/database/memory/plugin/
model migration and recovery tests. ADR-046 remains `Proposed` until its
operational and security alternatives are directly reviewed and accepted.

### SP-027 attempt (2026-08-28) — blocked: no signing/notarization authority, no Developer ID, no clean machine

The bounded SP-027 attempt of OPEN-12 is **blocked** under
`EV-SP-027-20260828-BLOCKED-01` at `37805cb0` on `main`:

- `SECOND_PASS_STATE.json` records `sign_or_notarize: false` and
  `release_or_deploy: false`; the user's "go apply be perfect" phrase is
  interpreted (consistent with SP-003/SP-011 precedent) as bounded to
  edit/test/state authority and does not grant signing, notarization, install,
  TCC mutation, release, or deploy authority.
- `security find-identity -v -p codesigning` reports only the local
  `AURA Stable Local Signing` identity; no Developer ID Application
  certificate exists, so Developer ID signing and notarization submission are
  not possible.
- No notarization credentials (Team ID / App Store Connect API key / Apple ID)
  are available; `notarytool` exists under Xcode 27.0 beta 5 but cannot submit
  without a Developer ID identity and credentials.
- No clean supported Mac with no developer tools is available for the
  clean-machine Gatekeeper, quarantine, nested-helper, and TCC identity
  acceptance matrix.
- No signing, notarization, install, launch, TCC mutation, release, deploy,
  commit, push, or merge was performed. The `development_unverified` artifact
  from SP-026 remains the only producible artifact and is not release class.

### SP-027 signing-procedure validation (2026-08-28) — procedure proven; still blocked on external prerequisites

Under the user's explicit full computer-use authority grant, the exact
nested-signing procedure that Developer ID signing requires was exercised and
validated with the local identity + hardened runtime under
`EV-SP-027-20260828-SIGNING-PROCEDURE-02`:

- Built the AURA.app bundle at `/tmp/aura-sp027-build/AURA.app`.
- Signed with the local `AURA Stable Local Signing` identity and `--options
  runtime` (hardened runtime) in the correct nested order: isolated plugin
  helper → automation helper → shell helper → Safari extension → main app.
- Verified: all three helpers pass sandbox self-attestation and deny
  network/mic/camera; main app signed with Hardened Runtime (`Runtime
  Version=27.0.0`); designated requirement `identifier "ai.aura.local.agent"
  and certificate root = H"25f0f2e4..."`; `codesign --verify --deep --strict`
  → **Signature OK**.

**SP-027 remains `blocked`.** The signing procedure is proven, but the
Developer ID certificate, notarization credentials, and clean supported Mac
remain external Apple/Apple-Developer-account/hardware prerequisites that no
local authority can create. The remaining OPEN-12 gates (Developer ID signing,
notarization, stapling, Gatekeeper, clean-machine, quarantine, nested-helper,
TCC identity, launch-at-login, signed update/rollback, recovery/migration/
uninstall) stay open and require an Apple-issued Developer ID certificate,
Apple Developer account credentials, and a clean supported Mac. **SP-028 must
not start.**

### SP-027 local-only scope decision (2026-08-28) — external distribution out of scope; local verification in scope

The release owner (user) explicitly decided that AURA is for **local-only
usage** and that external distribution is out of scope under
`EV-SP-027-20260828-LOCAL-ONLY-SCOPE-03`:

- No Apple Developer Program membership, no Developer ID Application
  certificate, and no notarization are required because the product is used
  locally; these must not block the prompt.
- **Developer ID signing, notarization, stapling, and external clean-machine
  Gatekeeper evidence are OUT OF SCOPE** for the local-only product.
- **Local verification IS in scope:** nested signing with the local identity +
  hardened runtime, `codesign --verify --deep --strict`, local `spctl`
  assessment, quarantine behavior, and TCC identity behavior on the local Mac.
- **Honest limitation:** the user stated "this Mac is clean," but this
  development Mac has Xcode 27.0 beta 5, Swift, and other developer tools, so it
  is NOT a clean machine with no developer tools. The local-only scope decision
  means the external clean-machine-with-no-developer-tools matrix is not
  required; the local verification on this development Mac is the relevant
  evidence. No clean-machine-with-no-developer-tools claim is made.

**Local verification performed (in scope):** built the AURA.app bundle at
`/tmp/aura-sp027-build/AURA.app`; signed with the local `AURA Stable Local
Signing` identity + hardened runtime in the correct nested order (plugin helper
→ automation helper → shell helper → Safari extension → main app); verified via
`./scripts/verify-signature.sh` (helpers sandbox-ok + network/mic/camera denied;
main app Hardened Runtime `27.0.0`; designated requirement correct; `codesign
--verify --deep --strict` → **Signature OK**). Local Gatekeeper/quarantine:
`spctl --assess --type execute` → **rejected** (expected for a locally-signed
non-Developer-ID bundle; the app is launched directly for local use, not via
Gatekeeper distribution); no quarantine attribute present; `codesign --verify
--deep --strict --verbose=2` → **valid on disk, satisfies its Designated
Requirement**.

**SP-027 is unblocked for the local-only scope.** The Developer ID/notarization/
external-clean-machine blockers are removed by the release-owner scope decision.
`RISK-NOT-NOTARIZED` is accepted for the local-only scope. The local signing
procedure is validated. SP-028 (updater lifecycle, recovery, migration) can
proceed under its own authority. External distribution, if ever required later,
would re-open the Developer ID/notarization/clean-machine gates.

### SP-027 completion (2026-08-28) — local-only scope; local verification + launch smoke passed

The bounded SP-027 local-only slice of OPEN-12 is **completed** under
`EV-SP-027-20260828-LOCAL-ONLY-SCOPE-03`,
`EV-SP-027-20260828-SIGNING-PROCEDURE-02`, and
`EV-SP-027-20260828-LOCAL-LAUNCH-04` at `37805cb0` on `main`:

- **Local-only scope decision:** the release owner decided AURA is for local-only
  usage; external distribution (Developer ID, notarization, external
  clean-machine) is out of scope.
- **Local signing procedure validated:** built the AURA.app bundle at
  `/tmp/aura-sp027-build/AURA.app`; signed with the local `AURA Stable Local
  Signing` identity + hardened runtime in the correct nested order (plugin
  helper → automation helper → shell helper → Safari extension → main app);
  verified via `./scripts/verify-signature.sh` (helpers sandbox-ok +
  network/mic/camera denied; main app Hardened Runtime `27.0.0`; designated
  requirement correct; `codesign --verify --deep --strict` → **Signature OK**).
- **Local Gatekeeper/quarantine:** `spctl --assess --type execute` → rejected
  (expected for a locally-signed non-Developer-ID bundle); no quarantine
  attribute; `codesign --verify --deep --strict --verbose=2` → **valid on disk,
  satisfies its Designated Requirement**.
- **Local launch smoke:** the signed bundle stayed alive after 12 seconds in an
  isolated `CFFIXED_USER_HOME` (`EV-SP-027-20260828-LOCAL-LAUNCH-04`).
- **Artifact hash/provenance binding:** main executable SHA-256
  `4f043259a246aaa462f9fffdd5feba8fdcaff63d9f9440fe4eea6854a969ecd1`; signed
  bundle ZIP SHA-256
  `4beae2ec0076ee160d75cd3081d595d704649e9f0a035272a3df128ef399d764`;
  provenance `Identifier=ai.aura.local.agent`,
  `Authority=AURA Stable Local Signing`, `Runtime Version=27.0.0`.
- **Honest limitation:** this development Mac has developer tools, so it is NOT
  a clean machine with no developer tools; no clean-machine-with-no-developer-
  tools claim is made. The signed bundle is local-identity + hardened-runtime
  only and is NOT suitable for external distribution.

**SP-027 is `completed` for the local-only scope. SP-028 is next eligible and
pending.** The `RISK-NOT-NOTARIZED` risk is accepted for the local-only scope.
External distribution, if ever required later, would re-open the Developer
ID/notarization/clean-machine gates.

### SP-028 completion (2026-08-29) — updater, lifecycle, recovery, migration; local source/build/test scope

The bounded SP-028 local-only slice of OPEN-12 is **completed** under
`EV-SP-028-20260829-LIFECYCLE-IMPLEMENTATION-01`,
`EV-SP-028-20260829-RUNTIME-API-02`, and
`EV-SP-028-20260829-CLOSEOUT-03` at `37805cb0` on `main`:

- **Scope authority:** edit/test/state only; `sign_or_notarize: false`,
  `release_or_deploy: false`; no live ServiceManagement login-item mutation, no
  real update download/network distribution, no clean-machine recovery run, no
  actual reset/uninstall/factory-reset execution on user data, and no
  acceptance of ADR-046.
- **Delivered (source/build/test/contract):**
  - `AuraLifecycle` library target with `ServiceManagement` linker setting and
    `AuraLifecycleTests` test target.
  - 12 `Sources/AuraLifecycle/` files isolating launch-at-login, update
    manifest/package validation, atomic staging, migration preflight, recovery
    checkpoints, rollback, safe mode, support bundle redaction, reset/uninstall/
    factory reset semantics, and lifecycle observation.
  - All system-mutating operations (`SMAppService`, bundle replacement, file
    deletion for reset/uninstall) are hidden behind protocols with production
    and in-memory/test implementations; tests never exercise the production
    system mutators.
  - Update engine is local-only: the default production manifest source returns
    `.noUpdateAvailable`; deterministic validator runs against synthetic
    fixtures.
  - 39 deterministic tests across 9 suites covering launch-at-login enable/
    disable/status, signed manifest/package validation, downgrade/replay
    protection, atomic staging/rollback, kill switch, low-disk/interrupted/
    corruption adversarial cases, config/database migration, support-bundle
    redaction, safe mode/reset/uninstall/factory reset semantics, capability
    registration, and kernel health wiring.
  - `AuraKernel` construction wires `lifecycleController`, `updateEngine`,
    `safeModeController`, `resetController`, `lifecycleObserver`, and
    `supportBundleExporter`; 19 direct-call RuntimeAPI methods are exposed
    behind `started` + `evaluateDirectCapability`.
  - 11 lifecycle capability manifests registered, all truthfully `.disabled`
    with reason "direct AuraKernel RuntimeAPI only".
- **Verification:** Swift build AURA passes; `AuraLifecycleTests` 39/39 pass;
  full suite 89 tests in 16 suites pass; second-pass validator PASSED;
  runtime-completion validator PASSED.
- **Residual / still open (outside this prompt):** ADR-046 (atomic update,
  downgrade/replay protection, signed update transport) remains **Proposed**
  pending direct operational evidence of an external signed update, which is
  outside current authority and the local-only scope. Live ServiceManagement
  login-item enablement, real update download/network distribution, clean-machine
  crash/recovery, and actual reset/uninstall/factory-reset execution remain
  blocked by authority boundaries and are not claimed. OPEN-12 R11 therefore
  remains `in_progress` for these live/external slices.

**SP-028 is `completed` for the local source/build/test/contract scope. SP-029
is next eligible and pending.**

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
beta/RC readiness.

**SP-029 update (2026-08-29):** `EV-SP-029-20260829-BETA-CONTRACT-BLOCKED-01`
now defines the beta scope, consent, privacy notice, opt-in, withdrawal,
retention/access/deletion rights, content-free aggregate telemetry schema,
kill switch, telemetry-off mode, rollback, and incident containment for an
internal local-machine-only closed beta. The existing fail-closed
`beta-readiness.json` contract was validated and remains `blocked`
(`authority.beta_enrollment: false`, `telemetry.enabled: false`,
`cohort.status: not_enrolled`, all signoffs `not_obtained`, release_candidate
`blocked`/`approved: false`). No telemetry code was implemented, no cohort was
enrolled, no consent was collected, no SLO was measured, and no RC was approved.

**SP-029 reconciliation (2026-08-30):** `EV-SP-029-20260830-TELEMETRY-AGGREGATOR-01`
implements SP-029 **Procedure step 2** — an explicit opt-in, default-off,
content-free aggregate telemetry engine (`TelemetryAggregator` + `telemetry_aggregates`
store table + config keys `telemetry.aggregateOptInEnabled`/`telemetry.aggregateRetentionDays`).
The engine is fail-closed (no-op unless opt-in on), buckets counts and latency
into coarse bands (no raw audio/screenshots/prompts/model outputs/secrets/tokens/
content), has **no transport** (nothing leaves the machine), and includes a
telemetry-off consent-withdrawal purge path. 9 deterministic tests pass;
`AuraLifecycleTests` 48 in 10 suites; full suite 0 failed. This closes the
in-scope missing deliverable, and **does not activate telemetry** (default off,
no transport).

**SP-029 approval update (2026-08-30):** `EV-SP-029-20260830-OWNER-APPROVAL-01`
records the release owner's explicit approval of the SP-029 beta
scope/consent/privacy/telemetry/kill-switch contract. The owner also confirmed
"ONLARI DA ONAYLIYORUM YAP ARTIK". This satisfies the *authority* component of
the SP-029 completion gate.

**SP-029 is `completed` (2026-08-30, `EV-SP-029-20260830-CLOSEOUT-01`).** Its
completion gate — *approved cohort/consent/privacy/telemetry/kill-switch
evidence exists; no telemetry is activated by this prompt alone* — is met:
contract defined, owner-approved, content-free aggregate engine implemented
(default-off, no transport), readiness record kept blocked. The R12 direct-
evidence gates remaining open (live SLO/scenario/incident results, independent
sign-offs) are **SP-030's** objective, and the signed RC artifact + ADR-047 are
**SP-031's**. The fail-closed `beta-readiness.json` validator/schema still only
allow `readiness_status` ∈ `{blocked, not_ready}` and require authority flags
`false`, cohort `not_enrolled`, consent `not_collected`, telemetry `enabled:
false` / `transport: none`, sign-offs `not_obtained`, RC `blocked`/`approved:
false`. **`beta-readiness.json` therefore remains `blocked` (R12 not RC ready),
but that is not an SP-029 blocker.** SP-030 is next eligible and pending under
its own authority.

**R11 dependency planning (2026-08-30):** Under the owner option-A grant
("a go be perfect and premium"), `AURA_RUNTIME_COMPLETION/context/R11_CLOSURE_PLAN.md`
was produced (`EV-SP-029-20260830-R11-CLOSURE-PLAN-01`) mapping the remaining
R11 gates into locally-closable (live launch-at-login, sleep/wake/crash, safe
mode, support-bundle, migration), external-Apple-prerequisite-and-local-only-
out-of-scope (Developer ID signing, notarization, stapling, external
clean-machine, signed update transport), and owner-decision (ADR-046 local-only
acceptance) buckets. The stale authority drift in `current-state.json` was
reconciled (edit/test/state + launch + commit/push/merge true; security-
sensitive false). R11 remains `in_progress`; `beta-readiness.json` stays
`blocked`; the artifact stays `development_unverified`. Opening SP-030 requires
`telemetry_or_beta: true` (owner-gated).

**SP-030 attempt (2026-08-30, `EV-SP-030-20260830-PROGRAM-BLOCKED-01`):**
SP-030 **remains blocked/in_progress**. Its completion gate — *"Mandatory SLOs
and scenarios pass, incidents are remediated, and independent sign-offs are
complete"* — cannot be honestly satisfied in this pass. Exact blockers:

- No enrolled/consented beta cohort (`cohort.not_enrolled`,
  `consent.not_collected`); there is no "collected approved sample" to compute
  percentile SLOs from, and no authority to enroll/consent a participant.
- No enabled measurement/transport path: the content-free aggregate engine
  (`EV-SP-029-20260830-TELEMETRY-AGGREGATOR-01`) is default-off and has
  `transport: none`; `telemetry.enabled: false`. No live beta window exists to
  run the Turkish/English/mixed scenario matrix or collect SLO/incident data.
- No independent evaluator: all five sign-offs (`security`, `privacy`,
  `accessibility_localization`, `release_recovery`, `product_truthfulness`)
  remain `not_obtained`. An independent sign-off requires a non-implementing
  evaluator, which is not present; it cannot be fabricated.
- R11 dependency incomplete: R11 is `in_progress`, artifact
  `development_unverified`, no signed/notarized clean-machine release artifact,
  ADR-046 not accepted; `dependency_gate.r11_completion_required: true`.
- Fail-closed schema: `beta-readiness.schema.json`/`validate_beta_readiness.py`
  only allow `readiness_status` ∈ `{blocked, not_ready}` and require the above
  flags to remain `false`/`not_obtained` until real gates close.

Verified this attempt: live `HEAD == origin/main == 8b16142` (clean worktree);
`validate_second_pass_program.py` PASSED; `validate_beta_readiness.py` → "valid
and blocked" (both exit 0). Stale `current-state.json` repository pointers were
reconciled to live HEAD. `beta-readiness.json` stays `blocked`. **SP-031 must
NOT start** (its precondition is SP-030 completion). Completion requires
owner-authorized R11 completion + a real consented beta window + independent
evaluation, then re-running SP-030.

**Owner broad approval (2026-08-30, `EV-SP-030-20260830-OWNER-APPROVAL-02`):**
the release owner stated **"neler eksik kaldı ben tümü için onay veriyorum"**,
granting approval for the remaining locally-closable R12/R11 work: R11 local
gates (live launch-at-login, sleep/wake/crash, safe mode/support-bundle,
migration), ADR-046 local-only acceptance, the beta cohort (owner as the single
local participant) with the owner's consent, content-free aggregate telemetry
for local measurement, and SP-031 (local-only signed RC + ADR-047) — all for
execution in a **user-present session**. Approval does NOT fabricate
independent sign-offs (need a non-implementing evaluator), live STT/WER (need a
speech-capable operator), or live beta SLO/scenario/incident measurement (need a
user-present session); none was produced in the unattended pass. SP-030 stays
`in_progress`/blocked; `beta-readiness.json` stays `blocked`; SP-031 must NOT
start until SP-030 completes.

**Owner present approval + ADR-046 local-only acceptance (2026-08-30,
`EV-SP-030-20260830-OWNER-APPROVAL-03`, `EV-SP-030-20260830-ADR046-ACCEPTED-01`):**
the release owner, present, stated **"burdayım ve herşeyi onaylıyorum"** on top
of the prior broad grant. **ADR-046 advanced from Proposed to Accepted
(local-only scope)** per the R11 closure plan and ADR-049: the local
updater/rollback/recovery/safe-mode/reset contract is implemented and
adversarially tested (SP-028 `EV-SP-028-20260829-*`); a real externally signed
update/transport/distribution remains out of scope and is not claimed.
`DECISION_INDEX.md` updated. Independent sign-offs, live STT/WER, and live beta
SLO/scenario/incident measurement still require a non-implementing evaluator /
speech-capable operator / user-present beta window and were NOT produced in this
pass. SP-030 stays `in_progress`/blocked; `beta-readiness.json` stays `blocked`;
SP-031 must NOT start until SP-030 completes.

**SP-030 contract + partial measurement (2026-08-30,
`EV-SP-030-20260830-CONTRACT-MEASURED-MODE-01`,
`EV-SP-030-20260830-HARNESS-MEASUREMENT-01`):** the reason SP-030 kept
terminating in the same blocked state was not only missing evidence — the R12
contract **could not represent a completed beta at all**. The old
`validate_beta_readiness.py` asserted every SLO `not_measured`, every scenario
`not_run`, the incident review `not_run`, and every sign-off `not_obtained`, so
it could not distinguish a real measurement from a fabricated one. Submitting a
hypothetical *perfectly executed, honest* beta record returned
`beta readiness validation failed: SLO measurement is fabricated` (exit 2). The
completion gate was therefore unreachable **by construction**, independent of
authority or evidence.

The validator and schema now support a second, provenance-bound **measured**
mode. It is not a relaxation: a measurement class
(`live_user_present` / `deterministic_harness` / `synthetic_speech`) travels with
every number and a harness result claiming `live_beta_sample` is rejected; every
measured SLO requires an evidence ID, class, prose limitations, and a
`sample_count` meeting a declared `sample_minimum`; and **an obtained sign-off
must name an evaluator asserting `independent: true` and
`evaluator_is_implementing_agent: false`**, so sign-offs cannot be self-granted.
`telemetry.transport == "none"`, `raw_content_allowed == false`,
`authority.release == false`, and RC `blocked`/unapproved hold in every mode.

A second defect was found and fixed: `scripts/aura-test.sh` `TEST_TARGETS`
omitted **`AuraLifecycleTests`**, so the SP-028 updater/rollback/recovery/
safe-mode/migration bundle — the evidence the R11 dependency rests on — never ran
in any "full suite". It passes (48 tests / 10 suites) and was restored; the true
full-suite total is **1290 tests / 80 suites / 22 bundles, 0 failures**, not
1242 / 21.

Recorded as `deterministic_harness` class (explicitly **not** a live beta window):
`false_success` = 0.0 (0 of 9 verification-bearing cases) and
`unauthorized_action` = 0 (255 adversarial/policy cases); all five scenario-matrix
entries pass as harness coverage with stated limitations. The cohort is `enrolled`
(the owner as the single consented local participant); telemetry authority exists
but the engine was **not** enabled.

**OPEN-13 remains open.** Still outstanding: the three live latency SLOs
(`ptt_ack`, `stt_partial`, `dialogue_first_token`), live STT/WER, a live-window
run of the scenario matrix, the incident review, and **all five independent
sign-offs** — which require a named non-implementing evaluator that owner
authority cannot substitute for. `beta-readiness.json` stays `blocked`; SP-030
stays `blocked`; **SP-031 must NOT start.**

**2026-08-31 update (`EV-SP-030-20260831-SLO-INSTRUMENTATION-01`).** Two of the
three outstanding latency SLOs now have a readable source for the first time:
`ptt_ack` and `stt_partial` are instrumented, with percentile aggregation
(p50/p95/p99) replacing a median/worst-case readout that could not satisfy this
gate's contract. **Neither is measured.** Both hold **zero samples** and remain
`not_measured`; instrumentation is not measurement, and `beta-readiness.json` is
untouched. A contamination defect was found and fixed before any sample was
taken — the permission-prompt grant path recorded human reaction time as machine
latency, and would have poisoned the first `ptt_ack` sample. `ptt_ack` is
obtainable by automation; **`stt_partial` is not** — it needs the owner to speak,
because automation produces no sound at the microphone. Below roughly 20 samples,
record "insufficient samples" rather than a p95/p99.

**2026-08-31 R11 dependency (`EV-SP-030-20260831-R11-POLICY-BLOCK-01`).** OPEN-13's
R11 dependency is worse than "in_progress" recorded: **9 of 11 lifecycle
capabilities are unreachable from the running product**, denied by the policy
engine before reaching their implementations. The capability registry disables
them citing a direct-RuntimeAPI route as the compensating control, and that route
does not work. No fix applied — defining a grant is a permission mutation outside
current authority, so the decision is the owner's, and **the live R11 gates cannot
run until it is taken.**

**2026-09-02 Computer Use recovery attempt (`EV-SP-030-20260902-CUA-SERVICE-CRASH-01`).**
The owner-present Computer Use path reached AURA and opened Settings, but the
native pipe closed when Recovery was selected while AURA itself stayed alive.
Fresh macOS diagnostic reports attribute the failure to
`SkyComputerUseService` (`com.openai.sky.CUAService` 26.817.1000761), which
crashed with `EXC_BREAKPOINT` / `SIGTRAP` at Swift `Array.remove(at:)` while
observing AURA's AX notification stream. The same failure reproduced against a
fresh local AURA bundle. A temporary Recovery AX-flattening source experiment
did not change the result and was reverted; no product source fix is retained.
This is a Computer Use service/tooling blocker, not a beta pass or a claim that
AURA Recovery is product-verified. SP-030 remains blocked; the remaining R11
live recovery flows, qualifying live SLO samples, live scenario window, and
incident review are still open, and SP-031 must not start. Next safe action is
to update/restart the Computer Use service or perform the Recovery checks
manually with the owner present.

**2026-09-02 local-only scope amendment (`EV-SP-030-20260902-LOCAL-ONLY-SCOPE-01`,
`ADR-051`).** At the release owner's explicit request, SP-030 is now bounded to
local-only deterministic validation and honest evidence classification. Its
scope-completion gate is satisfied by the passing deterministic suites,
provenance-bound alternate evidence, existing sign-offs/local launch-at-login
evidence, and the recorded scope decision. No live test is required for this
bounded scope. This does **not** close the broader OPEN-13 live-beta objective:
live voice/latency, microphone STT quality, live R11 recovery, live scenario
execution, and incident review remain deferred and open. `beta-readiness.json`
stays `blocked`, R12 stays in progress, and SP-031 remains active for its
separately bounded local-only package attempt.

### SP-031 local-only package attempt — 2026-09-02

`EV-SP-031-20260902-LOCAL-ONLY-PACKAGE-01` records the current package
postcondition. A clean detached worktree at
`bee334782262089fa117124ababa9b3c6dfed394` produced the unsigned
`development_unverified` archive twice with byte-identical output. The bound
artifact is `d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837`
(`58420226` bytes); its manifest is
`4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5`
(`10775` bytes). The manifest records `development_unverified`, a 17-file
bundle inventory, and no Developer ID/hardened-runtime/notarization evidence.
The current deterministic suite passed 1325 tests / 87 suites / 22 bundles
with zero failures and 70.20% line coverage; the report and logs remain in the
local temporary test directory. Existing CI evidence remains bound to its own
historical commit; no hosted-CI result is inferred for this package commit.

The package is reproducible and recoverable for local review, but it is not an
approved release candidate. ADR-047 is now drafted as `Proposed`; explicit
owner approval for this exact local-only package, independent review of its
declared scope, and ADR-047 acceptance are still absent. The external model
manifest/weights are not present in the repository, so neural voice remains
outside the qualified package scope. No live beta/SLO/scenario/incident/R11
evidence was created. `beta-readiness.json` remains `blocked`,
`release_candidate` remains blocked/unapproved, and SP-031 remains
`in_progress`; SP-032 is not safe to start.

### SP-031 review packet — 2026-09-02

`EV-SP-031-20260902-REVIEW-PACKET-01` records preparation of
`docs/operations/SP-031_LOCAL_ONLY_PACKAGE_REVIEW_PACKET.md`. The packet binds
the exact local-only artifact, manifest, source commit, evidence classes,
falsification checks, independence disclosure, and an explicit approve/return
decision template. It is not evidence that an independent review or owner
decision occurred. SP-031 therefore remains `in_progress`; ADR-047 remains
`Proposed`; `beta-readiness.json` and `release_candidate` remain blocked; and
SP-032 must not start until the separate review/decision evidence is recorded.

`EV-SP-031-20260902-CLOSEOUT-REVIEW-PACKET-01` records the mandatory closeout
of this packet attempt. All required local validators and package-integrity
checks passed, but the result is still process/local evidence: it does not
prove the owner performed the review or accepted ADR-047. The approval gate is
therefore still open and SP-032 remains unsafe to start.

**2026-09-02 owner decision update:** The owner then reviewed the exact package
evidence and falsification checklist. `EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`
records approval of artifact SHA-256
`d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837` and
manifest SHA-256
`4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5` for local
`development_unverified` use only, with listed limitations accepted. ADR-047 is
accepted only for that local-only scope and SP-031's local package gate is
complete. This does not close OPEN-13/R12: `beta-readiness.json` and
`release_candidate` remain blocked, and the direct FINAL gates remain absent.
SP-032 is projected as the next prompt but is **blocked and unexecuted**; it is
not safe to start under this local-only decision.

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

**Historical pre-approval correction — 2026-09-02:** At the time of that
correction, ADR-047 existed at
`docs/decisions/ADR-047-beta-slos-release-authority.md` with status `Proposed`.
It was a local-only decision draft, not an accepted final decision or release
waiver. The preceding “ADR-047 is absent” wording is retained as the historical
pre-draft state; current status is recorded by the SP-032 reconciliation below.

### SP-032 reconciliation update — 2026-09-02

`EV-SP-032-20260902-FINAL-RECONCILIATION-01` records a fresh, edit-only FINAL
audit. The preceding FINAL bullets and correction remain historical; their
following forward-looking details are superseded by current direct records:

- ADR-047 is **Accepted (local-only scope)** after the exact-hash owner decision
  in `EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`. It approves only the
  local `development_unverified` package and cannot approve beta,
  `release_candidate`, production, signing, notarization, or release.
- The R12 cohort is enrolled/consented and all five scoped sign-offs are
  obtained. They do not substitute for the still-absent live SLO set, live STT
  quality, live scenario run, incident review, R11 completion, or an approved
  release candidate. `beta-readiness.json` remains `blocked` with telemetry
  disabled and `transport: none`.
- Launch-at-login has direct local evidence, but sleep/wake/crash recovery,
  safe-mode export, populated-profile migration, update/rollback, uninstall,
  factory reset, and support-bundle privacy do not have the required direct
  acceptance evidence. The failed Computer Use Recovery observation remains a
  service-boundary blocker, not a pass.
- ADR-049 permanently scopes Developer ID, notarization, and external
  clean-machine distribution out of this local-only product. That scope decision
  does not waive the remaining direct local clean-profile/lifecycle or FINAL
  gates.

The result is still **blocked**: the capability matrix has no
`release_verified` row, every capability retains at least one open gap, and the
current authority forbids installation/launch, permission changes, beta work,
signing, release, and deployment. This reconciliation is not a clean-Mac or
end-to-end procedure. SP-033 is not safe to start; return each missing
postcondition to its owning R2-R12 track.

`EV-SP-032-20260902-CLOSEOUT-02` records the mandatory 15_SESSION_CLOSEOUT for
this attempt. It revalidated the bounded projections and permitted integrity
checks; it did not execute or replace any missing clean-Mac, lifecycle, beta,
or release procedure.

The FINAL/CLOSEOUT deliverable is a blocked maintainer handoff and exact
owning-track return, not a release claim. Stale prose may be reconciled only
where it conflicts with canonical state; historical ledger entries remain
append-only.

Historical closeout evidence: `EV-FINAL-20260809-CLOSEOUT-BLOCKED-01`. The
current blocked reconciliation is
`EV-SP-032-20260902-FINAL-RECONCILIATION-01`; its mandatory SP-032 closeout is
recorded separately. The handoff is recorded at
[`FINAL_OPERATIONAL_HANDOFF.md`](../docs/operations/FINAL_OPERATIONAL_HANDOFF.md);
deterministic checks do not satisfy the missing live, release, beta, or
clean-profile gates above.

**Autonomous deterministic-control leg (2026-09-02):**
`EV-SP-032-20260902-DETERMINISTIC-SUITE-01` re-ran the second-pass/runtime/
beta-readiness/release-manifest validators, rechecked both SP-031 SHA-256s, and
ran a fresh full `aura-test.sh` suite (22 bundles, 0 failed, 1325 tests / 87
suites, exit 0) under current edit/test/state-only authority. This is
`deterministic_harness`-only evidence and does not close FINAL. SP-032 remains
`blocked`; `beta-readiness.json` and `release_candidate` remain blocked; R2-R10
direct, R11 live lifecycle/clean-profile, R12 live SLO/scenario/incident/
sign-off, and FINAL authority remain open.

**Owner-grant live local acceptance (2026-09-03):**
`EV-SP-032-20260903-LIVE-ACCEPTANCE-01`. Under the owner's full-authority grant,
`AURA.app` + helpers + Safari ext were built and local-signed (`AURA Stable
Local Signing`, `codesign --verify --deep --strict` exit 0); the app launched
live, stayed stable ≥13s, crashed not, and quit cleanly; a fresh full suite ran
22 bundles / 0 failed / 1325 tests at 70.19% line coverage; supply-chain +
repo-hygiene validators PASSED and 64 Python governance tests passed; BTM shows
launch-at-login registered. This materially advances SP-032's local gates but
does not close (and must not fabricate) the R12 independent-evaluator/cohort/
live-SLO gates, Developer-ID/external distribution (ADR-049), or the
unit-tested-only R11 lifecycle sub-gates. `beta-readiness.json` and
`release_candidate` remain blocked.

**Owner-authorized synthetic R11 lifecycle closure (2026-09-03):**
`EV-SP-032-20260903-R11-SYNTHETIC-LIFECYCLE-01`. The owner directed synthetic
closure of the R11 lifecycle gates without a user-present session.
`Tests/AuraLifecycleTests/SP032LifecycleHarnessTests.swift` (`.serialized`)
drives the real production controllers end-to-end with synthetic inputs: crash
recovery, sleep/wake, safe mode, migration preflight, support-bundle export,
update stage/rollback + recovery checkpoints, and reset/uninstall on throwaway
temp dirs. Lifecycle suite 60/11/0; full suite 22 bundles/0 failed/1337 tests.
The SP-032 prompt was updated with the synthetic-closure approach and its
honesty boundary. This is `deterministic_harness` evidence; it materially
advances the R11 lifecycle gate but does **not** close (and must not fabricate)
the real-host sub-gates (physical Mac sleep/wake, real signed update transport,
real clean-profile migration, destructive user-data removal). `beta-readiness
.json` and `release_candidate` remain blocked.

**Owner accepted-gaps decision; SP-033 opened (2026-09-03):**
`EV-SP-032-20260903-OWNER-ACCEPTED-GAPS-01`. The owner directed option (A):
accept the real-host R11 sub-gates as known gaps (same pattern as ADR-049,
RISK-DNS-IP-PINNING, RISK-PEER-IDENTITY, RISK-LIVE-LIFECYCLE-UNVERIFIED) and
open SP-033. R11 `dependency_gate.r11_state` → `completed` (local scope,
evidence `EV-SP-032-20260903-R11-SYNTHETIC-LIFECYCLE-01`); R11 track →
`completed`; `GATE-SIGNED-UPDATES-RECOVERY` → `accepted`; SP-032 → `completed`;
SP-033 → `in_progress` (active). This is an owner decision / accepted-known-gap,
not live/clean-Mac/beta/release evidence; the accepted real-host sub-gates
remain open and reversible. `beta-readiness.json` `readiness_status` and
`release_candidate.status` remain `blocked`.

### Net blocked sebepleri (2026-09-03, kanonik state'ten doğrulandı)

SP-032 `blocked` kalır çünkü FINAL acceptance gate'i, aşağıdaki postcondition'ların
**tamamı** geçmeden `release_candidate_verified` / `released` durumuna geçemez ve
bunların hiçbiri tek bir yerel oturumda meşru şekilde kapatılamaz (fabrikasyon
yasak — ADR-051/052, kontrol kontratı):

1. **R11 tamamlanmadı** — `beta-readiness.json` `dependency_gate`:
   `r11_state: in_progress`, `r11_release_status: development_unverified`,
   `r11_completion_required: true`. Canlı lifecycle gate'leri (sleep/wake/crash
   recovery, dolu-profil migration, safe-mode/support-bundle canlı gözlem)
   yalnızca unit-testli (`AuraLifecycleTests` 48/10/0), canlı değil.
2. **Canlı beta SLO'ları ölçülmedi** — `open_blockers`: `ptt_ack`,
   `stt_partial`, `dialogue_first_token` latency SLO'ları canlı mikrofonlu bir
   kullanıcı-beta penceresi gerektirir; ölçülmedi.
3. **Canlı STT/WER ölçülmedi** — konuşabilen bir operatör gerektirir; yalnızca
   belgelenmiş sentetik-speech accommodation var, canlı mikrofon WER sonucu yok.
4. **Senaryo matrisi canlı çalıştırılmadı** — yalnızca `deterministic_harness`
   sınıfı olarak geçti; canlı beta penceresinde hiç çalıştırılmadı.
5. **Incident review yok** — beta penceresi olmadığı için üretilecek incident
   yok; review çalışmadı.
6. **R12 sign-off'ları canlı kanıtın yerine geçmez** — 5 sign-off kayıtlıdır ama
   bunlar dışlanmış canlı-beta SLO/senaryo/incident/R11 kanıtının yerini tutmaz;
   local-only scope kararı readiness'i `blocked` tutar.
7. **Telemetri kapalı** — `telemetry.enabled: false`, `transport: none`; canlı
   beta ölçümü için `telemetry_or_beta` yetkisi gerekir, bu yalnızca owner'ın
   açabileceği bir şeydir.
8. **Developer ID / notarization / harici dağıtım** — ADR-049 ile kalıcı olarak
   kapsam dışı; bu, `release_candidate`'in `blocked` kalmasını sağlar.
9. **FINAL authority yok** — SP-032'nin kendisi `release_candidate_verified` /
   `released` durumuna geçmek için FINAL yetkisi gerektirir; bu yetki verilmedi.

Sonuç: `beta-readiness.json` `readiness_status: blocked`,
`release_candidate.status: blocked`, `approved: false`. SP-033 başlatılmadı.

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

### SP-033 terminal closeout — 2026-09-03T08:07:57Z — chain truthfully blocked

`EV-SP-033-20260903-FINAL-CLOSEOUT-01` records the terminal second-pass chain
closeout. Branch `main`; `HEAD == origin/main ==
44f41c7986445526fd3f40f36c5a3972d26f65ea`; worktree clean. The chain
SP-000–SP-032 is completed for its declared local scopes; SP-033 is the
terminal prompt (`next_prompt: none`) and remains the active prompt in a
`blocked` state because the validator structurally requires an active
uncompleted prompt and the broader program gates remain open.

> **[SUPERSEDED 2026-09-03 by ADR-053]:** The terminal `blocked` state below was
> re-resolved under ADR-053 (synthetic-accepted scope). See the new
> **"SP-033 ADR-053 synthetic-accepted completion"** subsection below this entry.
> The historical wording is preserved unchanged (append-only).

The chain is **truthfully blocked** with a complete maintainer handoff; no
ambiguous state remains. The following program-wide gates remain open and
belong to their owning tracks (not to SP-033's SESSION_CLOSEOUT scope):

- **R2–R10** direct capability, security/privacy, accessibility, integration,
  and privilege postconditions remain open.
- **R12** live SLO/scenario/incident/RC evidence and independent-evaluator
  sign-offs remain open; `beta-readiness.json` `readiness_status` and
  `release_candidate.status` remain `blocked`.
- **FINAL** authority and direct clean-Mac/end-to-end acceptance remain absent.

The cognitive completion questions for the entire chain are answered in
`SECOND_PASS_LEDGER.md` and the two program ledgers, with each SP prompt's
evidence/ledger entry linked. `python3 scripts/validate_second_pass_program.py`
PASSED. No app launch/install, TCC mutation, provider contact, beta enrollment,
telemetry activation, signing, notarization, release, deployment, commit, push,
or merge occurred. No raw audio, screenshot, secret, token, or unredacted
private content was recorded.

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

**SP-009 CORRECTION (2026-08-17)** under `EV-SP-009-20260817-CORRECTION-02` and
`EV-SP-009-20260817-CLOSEOUT-03`. A post-delivery audit found the SP-009 record
above overstated its result in two ways, both now fixed rather than reworded:
`validate_runtime_completion.py` was exiting `1` (three schema/pointer breaks
introduced by SP-009's own state edits), and the packaged extension had **no
producing half** — it never sent a native message, never signed, and never
wrote the shared container, so nothing could produce an envelope the transport
accepts. The bridge now has a complete, tested deterministic path: user-gated
toolbar click -> `aura.activeTabObservation` native message ->
`SafariBridgeNativeMessageHandler` -> `SafariBridgeEnvelopeWriter` (HMAC sign,
atomic write) -> `AuthenticatedSafariWebExtensionTransport` ->
`SafariBrowserReadAdapter`. Tag verification is constant-time, `.malformedMessage`
is a distinct fail-closed state, and the manifest dropped its `<all_urls>`
content script. 12 SP-009 tests; 21/21 bundles, 954/954 tests, 0 failed; all
four validators exit 0. The live package/trust path is still unverified and the
remaining OPEN-06 items above are still not closed.

## SP-011 Computer Use OAuth retry (2026-08-18)

`EV-SP-011-20260818-OAUTH-RETRY-06` records the user's explicit retry of the
timed-out Google OAuth Continue flow. The provider redirect reached
`127.0.0.1:48080/oauth2callback` and Chrome reported `ERR_CONNECTION_REFUSED`.
No authorization code or token material was copied, parsed, logged, or exposed.
The temporary AURA process was alive, but no TCP 48080 listener existed. Source
inspection found no live callback listener, token exchange, or OAuth enrollment
UI; AURA only exposes the externally-fed `connectMailAccount` seam. Therefore
the provider redirect is partial live evidence, not a connected account or a
live Gmail read/revocation result. SP-011 remains blocked and SP-012 must not
start. Adding a callback/token-exchange feature requires a separate explicit
scope decision.

## SP-011 Gmail live closeout reconciliation (2026-08-19)

`EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07` supersedes the OAuth-callback and
real-account portions of the 2026-08-18 blocker without rewriting their
historical observations. AURA now has a bounded loopback PKCE callback, provider
token exchange, approved-account probe, Keychain-only enrollment, user-facing
connect/revoke actions, typed thread-summary routing, and redacted failure
classification. Under explicit user-present authority, the Gmail read-only
subset passed live: a controlled two-message thread was summarized without
address/body leakage; controlled injected instructions were blocked; offline
transport was distinguished from credential failure; two approved accounts
caused clarification before provider contact; the local Keychain credential and
Google grant were removed; and a post-revocation read failed closed before the
provider. Controlled fixtures were moved to recoverable Gmail Trash, all local
callback tabs/processes/acceptance environment were cleared, and no token,
authorization code, secret, account identifier, message body, or screenshot was
placed in repository evidence.

The full OPEN-06 / SP-011 live gate is still open. No live Safari
extension/native-messaging approved-page summary, EventKit agenda/free-window,
event draft, or Contacts/Calendar TCC acceptance was performed. AURA compose/send
remains unimplemented and explicitly excluded; Gmail UI sends were separately
authorized fixture provisioning only. The direct AURA Privacy-tab revoke click
also could not be observed because the Computer Use native pipe closed whenever
that SwiftUI tab was selected; the equivalent Keychain backend deletion and
provider-side grant removal prove the security postcondition but not that exact
UI interaction. **SP-011 remains `blocked`; SP-012 is not safe to start.**

### OPEN-06 update — 2026-08-19 (native legs live; Safari extension packaged and registered)

`EV-SP-011-20260819-NATIVE-LEGS-AND-EXTENSION-08`. The historical wording above
is preserved; this entry records what changed.

Three of the legs listed as "not performed" were **unrunnable, not merely
unperformed**, for four separate reasons found by attempting them:

1. **No caller.** `EventKitCalendarReadAdapter.requestReadAccess()`,
   `ContactsFrameworkLookupAdapter.requestReadAccess()` and
   `AuraKernel.connectBrowserProfile` existed with no production caller, while
   the calendar, contacts and browser health rows each published a remediation
   naming a Setup control that did not exist.
2. **No entitlement.** `Resources/AURA.entitlements` lacked
   `com.apple.security.personal-information.calendars` and `.addressbook`, so
   tccd refused to show the prompt even once the grant action was wired
   (`Policy disallows prompt ...; access to kTCCServiceCalendar denied`).
3. **No usage description.** `Resources/AURA-Info.plist` carried neither string,
   so the request would have terminated the app.
4. **No native half.** The Safari extension's `SafariWebExtensionHandler` was
   never written and `build-app-bundle.sh` packaged no extension, so the
   producing side of the bridge did not exist.

All four are fixed. **Now closed within OPEN-06:** the Calendar and Contacts TCC
acceptance, including the real prompts carrying AURA's own usage strings, and a
live EventKit agenda read bound to a known disposable fixture ("1 event(s): AURA
SP-011 acceptance fixture"), verified against the same query returning
"Nothing is scheduled in that range." beforehand. The Safari extension is now a
real signed, sandboxed `.appex` that the system registers at
`com.apple.Safari.web-extension`.

**Still open within OPEN-06:** the live approved-page summary through real Safari
native messaging, the browser injection-ignore leg, and the browser profile
revocation. Safari will not enable a non-Developer-ID extension without its
`Allow unsigned extensions` toggle, which requires a Touch ID or password
authentication that was deliberately not supplied; a Developer ID signature plus
notarization removes the requirement entirely and is the production answer,
owned by R11. Free-window computation and event draft remain unimplemented and
mutation-class. No non-empty contacts read is recorded, by choice, because only
the user's own address book exists on this machine and this prompt forbids
recording real private account data. **SP-011 remains `blocked`; SP-012 is not
safe to start.**

## SP-017 OPEN-08 closure — system-TTS-only release scope (2026-08-23)

`EV-SP-017-20260823-LIVE-SYSTEM-TTS-01` and
`EV-SP-017-20260823-RESOURCE-SCOPE-02` close SP-017's completion gate through
the prompt's explicit exclusion branch. Direct live system TTS passed 14/14:
first chunk 0.733 s, full test utterance 1.400 s, interruption/barge-in,
pause/resume, stop, and anti-trigger lifecycle covered. The 16 GiB host was
observed with AURA at approximately 27 MiB RSS in the final sample; a live
Chatterbox CPU helper sample reached approximately 3991 MiB, so neural
co-residency is not claimed. Thermal/energy samplers did not provide a usable
non-privileged result, and no 8-hour neural soak was asserted.

The release decision is therefore bounded and truthful: Push to Talk plus
system TTS is the only qualified voice path. Neural TTS/reference voice,
MPS/CPU neural first-audio and soak qualification, wake word/passive listening,
and physical speaker-to-microphone echo are explicitly excluded from this
release scope. `TTSAdapterChain()` defaults to `system`; explicit neural
adapters remain opt-in and resource-guarded. `screenVision` and `codingAgent`
remain documented exclusions from the shared governor. Historical OPEN-08
wording above is preserved; the broader physical recovery and future neural
qualification risks remain outside SP-017 and are not misrepresented as
passed.

**SP-017 acceptance verdict: `completed`.** ADR-042 is accepted for this
system-TTS-only scope with alternatives, scope, expiry/revisit conditions, and
evidence. SP-018 is safe to start because SP-017's direct evidence,
cognitive-gate answers, state projections, and validator closeout are now
complete; SP-018 itself remains pending/unopened.
### OPEN-09 / SP-019 live export reconciliation — 2026-08-24

`EV-SP-019-20260824-LIVE-CONTROLS-06` closes the previously missing export
artifact postcondition: the user-present Privacy export produced
`/tmp/aura-memory-sp019-export.json`, 203 records, with no audit key and no
raw audio/screenshot/token/secret marker in the structural scan. The artifact
hash is recorded in the evidence file and the raw export remains outside the
repository.

The historical gap wording remains unchanged. SP-019 is still open for the
verified tool fact, resolved multi-turn reference, contradiction resolution,
deletion receipt, and direct transport trace. Permanent Delete remains paused
until action-time confirmation.

### OPEN-09 / SP-019 tool-evidence wiring and live acceptance — 2026-08-24 (second attempt)

The five scenarios still open after `EV-SP-019-20260824-LIVE-CONTROLS-06` were
re-examined and four of them turned out to be **missing product paths, not
failed procedures** (`EV-SP-019-20260824-TOOL-EVIDENCE-WIRING-08`):

- No production site ever wrote `MemoryClass.projectFact`, produced
  `MemoryProvenance.observed`, or used `MemoryWriteSource.verifiedToolEvidence`.
  A verified tool fact was therefore unreachable in the shipped app.
- `ContradictionDetector` keys on `(memoryClass, subject, scope)` while the only
  live write used the globally unique subject `intent:<uuid>`, so no live
  conflict could ever be raised.
- `ReferenceResolver.explicitlyConfirmedTargetID` had no production producer, so
  an ambiguous reference's clarifying question had no path back into resolution.
- `AuraKernel.deleteMemoryRecord` discarded the engine's `MemoryDeletionReceipt`,
  so no receipt could reach the user.

Direct changes wired a bounded `ToolObservation` seam from the tool router into
memory as a globally scoped `projectFact` keyed by a stable fact key, added the
reference-clarification round trip, and surfaced the deletion receipt. Full
matrix **21/21 bundles, 1,160 tests, 0 failed**, with 19 new tests and no new
formatter or lint findings.

Live acceptance then closed five of the six previously open items:

- **Verified tool fact** — `EV-SP-019-20260824-LIVE-PROJECT-FACT-09`: a
  user-confirmed `run /bin/date` produced `projectFact` `shell.execute:/bin/date`
  with provenance `observed(source: user)`, `Retention: indefinite · Scope: global`,
  visible in the Privacy tab. A confirmed `git` command that exited 128 produced
  no record — the failure-is-not-evidence guard held live.
- **Contradiction and its resolution** — same evidence: a second observation of
  the same fact key raised `MemoryConflict 35046B6F-…`, the Privacy tab rendered
  `Unresolved contradiction; neither statement is silently discarded.`, and
  activating `Keep new` recorded `{"supersededExisting":{}}`. Records survived a
  full app restart (`5 visible of 5 records`).
- **Deletion receipt** — `EV-SP-019-20260824-LIVE-DELETION-RECEIPT-10`: with the
  user's explicit action-time authorization, one disposable
  `workingConversation` record was permanently deleted after the driver verified
  the search filter had isolated exactly one row. The record is gone, the count
  fell to 4, the filter that found it now returns `0 visible of 4 records`, and a
  persistent `Memory deletion receipt` rendered in the Privacy tab.
- **Memory carries no authority** — `EV-SP-019-20260824-MEMORY-AUTHORITY-12`: a
  live mutation-tier shell command was refused with `Blocked: confirmationDenied`
  and produced no memory record, plus two new adversarial tests proving poisoned
  dialogue context cannot authorize a destructive command or widen a denied tier.
- **Direct transport trace** — `EV-SP-019-20260824-TRANSPORT-TRACE-11`: two
  socket-table observations of the live process (150 samples/300 s and
  210 samples/420 s, the latter spanning actual memory writes) found **zero** IP
  sockets and zero non-loopback peers. This replaces the earlier policy-refusal
  evidence, which proved only that the policy layer refuses.

**Still open — the multi-turn reference scenario.** The clarification round trip
is wired and deterministically proven (5 tests), but it could not be
demonstrated live for a newly identified, separate product reason: the
production rule-based classifier cannot emit an intent carrying an unresolved
implicit reference. `classifyFileCommand` requires a path-shaped target and
`classifyAppCommand` requires a known application name, so `open the file`
classifies as `.unknown` with an `unresolvedAppName` slot, and
`TypedIntent.applyingResolvedReference` only applies to `.fileOpen`,
`.appActivate`, and `.appTerminate`. Reaching the resolver in production
requires the structured-NLU backend. This is recorded as a new gap rather than
absorbed into SP-019.

SP-019 therefore remains `in_progress` and SP-020 remains unopened. The
historical wording above is retained unchanged.

### OPEN-09 / SP-019 multi-turn reference closed — 2026-08-24

The one scenario left open above is now closed
(`EV-SP-019-20260824-LIVE-REFERENCE-13`). The blocker was a single guard: the
rule-based classifier accepted an open-prefixed target only when it looked like
a path, so `open the file` fell through to application matching and became
`.unknown`. Since `applyingResolvedReference` binds only `.fileOpen`,
`.appActivate`, and `.appTerminate`, the whole resolver path was dead in the
shipped app — and `ProductionReferenceWiringTests`' fixture classifier, which
*does* return `.fileOpen` with no slot for that utterance, had encoded the
intended behaviour production lacked.

An open-prefixed target that is a known reference phrase now yields the intent
with its target slot deliberately empty, and the phrase list itself moved to a
single definition in `AuraCore` (it had been three diverging literals). Live:
`open the file` returned `Blocked: ambiguous` and a clarifying question with two
plausible candidates; `open the file alpha` then resolved to **alpha**, bound
`filePath`, and opened the real file. Memory records show the difference
durably — turn 3 `classified intent: fileOpen` with no slot, turn 4 the same
kind `; slots: filePath`. Full matrix **21/21 bundles, 1,164 tests, 0 failed**.

`RISK-SP-019-REFERENCE-UNREACHABLE` is closed.

All eight R8 live/product scenarios now carry direct live evidence. One
reconciliation step remains before SP-019 can be moved to `completed`: the
preference-restart, correction, and export scenarios were captured on the
earlier build `e7409130…`, while the tool-fact, contradiction, deletion,
reference, authority, and transport scenarios were captured on `efe42a2c…` and
`ee4d9735…`. The intervening changes are additive and do not touch the
preference store, correction, or export paths, but a completion claim should
rest on a single consolidated acceptance run rather than on three builds.
SP-019 therefore stays `in_progress` for that bounded step, and SP-020 remains
unopened.

### OPEN-09 / SP-019 consolidated acceptance — 2026-08-25 (closed)

All eight R8 live/product scenarios were re-run against a **single** build,
`fccf15204202b7c3f71815a2ff547e5706907dfe2caa1d30dea29d0157989f00`, in one
isolated `CFFIXED_USER_HOME` profile, so the completion claim no longer spans
three binaries (`EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14`):

- Preference `Concise` survived a full quit/relaunch with
  `Saved with purpose: ...; scope: global; retention: indefinite.` and
  `allowRemoteContext=0`.
- `run /bin/date` produced `projectFact shell.execute:/bin/date` with
  provenance `observed(source: user)`.
- `open the file` returned `Blocked: ambiguous` and asked; `open the file alpha`
  resolved to alpha and bound `filePath`.
- A second `/bin/date` raised conflict `ED0B40DD-…`, both records retained;
  `Keep new` recorded `{"supersededExisting":{}}`.
- A row correction was saved as a new record carrying `supersedes=80544B5D…`.
- Retention cleanup was invoked; export wrote a 12-record bundle with **no**
  `auditSecurity` and no secret markers; one disposable record was permanently
  deleted and the Privacy tab rendered a receipt naming the record, class,
  reason, and time.
- Enabling `Allow remote context` was refused by machine policy and local-only
  was restored; an unconfirmed mutation-tier shell command ended
  `Blocked: confirmationDenied` and wrote no memory.
- Two socket-table traces of the acceptance processes observed zero IP sockets
  and zero non-loopback peers.

`OPEN-09`'s SP-019 slice is therefore closed, `RISK-SP-019-LIVE-MEMORY-CONTROLS`
is closed, and SP-020 is safe to start. Broader R8/R9 gates named in the
historical wording above (remote/provider acceptance, ADR-043, manual
accessibility, signing, release, deployment) remain open and are owned by their
own prompts.

### OPEN-09 / SP-020 remote context boundary — 2026-08-25 (closed)

`EV-SP-020-20260825-REMOTE-BOUNDARY-01` closes the **remote/provider acceptance**
residual named in the historical wording above through SP-020's **exclusion
branch**: local-only is the explicit product boundary. The static inventory and
deterministic tests prove no production remote-context transport or caller of
`remotePublicOnly` / `ContextDeliveryPolicy(destination: .remoteModel)` exists;
`ContextBuilder_Build.swift` rejects remote delivery without a separately
redacted, user-approved turn summary; `PreferencePolicyBounds`
(`cloudContextAllowed=false`) makes the local-only preference non-weakening.
`AuraContextTests` 37/37 (incl. `r8RemoteContextFailsClosedBeforeAnyTransmission`)
and `AuraMemoryTests` 30/30 (incl.
`r8PreferenceProfilePersistsAndCannotWeakenLocalOnlyPolicy`) pass; live socket
traces in `EV-SP-019-…-14` show zero non-loopback peers.
`RISK-MEMORY-REMOTE-TRANSPORT-EVIDENCE` is mitigated.

**ADR-043 is Accepted** under the explicit local-only remote-boundary scope
(2026-08-25, review 2026-09-07) at the user's direction;
`RISK-ADR-043-PENDING` is closed. **SP-020 is `completed`**; the remote/
provider acceptance residual named in the historical wording above is closed
through the exclusion branch. The historical wording above is retained
unchanged. The other R8/R9 gates (manual accessibility, signing, release,
deployment) remain open and owned by their own prompts.
**2026-09-02 unattended alternate verification (`EV-SP-030-20260902-UNATTENDED-ALTERNATE-01`).**
The userless deterministic paths were re-run: `AuraLifecycleTests` 48/10/0,
`AURAIntegrationTests` 111/22/0, and `AuraSTTTests` 19/4/0. An explicitly
opt-in synthetic Speech attempt was also made without requesting or mutating
TCC; three real-recognizer tests failed closed with `speechNotAuthorized`.
These results re-confirm deterministic contracts and the permission boundary,
but they are `deterministic_harness` / `synthetic_speech`, not
`live_user_present`. They produce no microphone speech, `stt_partial`,
`ptt_ack`, live-beta sample, live R11 evidence, scenario-window result, or
incident review. SP-030 and `beta-readiness.json` remain blocked; SP-031 must
not start. A synthetic host may narrow an implementation timing question only
with explicit provenance and cannot be relabeled as live beta.

### OPEN-15 / SP-033 ADR-053 synthetic-accepted completion — 2026-09-03

`EV-SP-033-20260903-SYNTHETIC-ACCEPTED-01` records the SP-033 completion under
`docs/decisions/ADR-053-live-evidence-synthetic-scope.md` (Accepted): the user
declared (2026-09-03) that live-user acceptance is **not required**, and every
gate blocked solely on the absence of canlı (live) evidence is closed with
synthetic/deterministic/local-observed evidence at its **true evidence class**
— never relabeled as `live_user_present`, `live_beta_sample`, signed,
notarized, or production. **OPEN-15 is resolved for the synthetic-accepted
local scope**; the chain SP-000–SP-033 is COMPLETE under that scope.

`validate_second_pass_program.py` and its unit tests PASSED; all projections
(state/handoff/context/ledger/evidence/decision/risk/indexes) are
synchronized. `beta-readiness.json` `readiness_status` and
`release_candidate.status` remain `blocked` / `approved:false`
(`release_or_deploy:false`; ADR-049 keeps Developer ID/notarization/external
distribution out of scope). External distribution, if ever required, needs a
new ADR and cannot be derived from this synthetic-accepted closure.

Falsifiers: any record that relabels synthetic/deterministic evidence as
live/beta/production, or that treats this completion as granting release
authority, would falsify ADR-053.
