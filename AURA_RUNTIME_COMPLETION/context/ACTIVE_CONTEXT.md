# AURA Runtime Completion — Active Context

> **Program:** AURA Runtime Completion Program v1.0.0  
> **Current prompt:** `SP-021` (pending; unopened)
> **Current program state:** In progress; SP-020 completed, SP-021 pending, while R1/R2/R3/R4/R5/R6/R7/R8/R9/R10/R11/R12 and the broader program remain open.
> **Live repository lineage:** SP-019 product content was merged to `main` at `e6706157178d3d3c41b8d6cab8572ca5102b8f76` (PR #6); the state projection commit `ed7900e3db8403df2ee7a1a5e6d65754b58e8091` realigns governance pointers. Current `main` and `origin/main` are synchronized at `ed7900e` with a clean worktree. No repository-defined signed/notarized/public deployment target exists.
> **Audited content baseline:** `47775180c224f87fa5a58703f793515ffcb2c35c` under ADR-045 (projection-only descendants are not new product audits)

## Canonical status

## Second-pass synchronized overlay — 2026-08-25 (`SP-021` / `pending`)

SP-020 is **completed**: the exclusion branch closed the remote/provider
residual — local-only is the explicit product boundary
(`EV-SP-020-20260825-REMOTE-BOUNDARY-01`). ADR-043 is **Accepted** under the
explicit local-only remote-boundary scope (2026-08-25, review 2026-09-07);
`RISK-ADR-043-PENDING` is closed. SP-021 (accessibility and localization
acceptance, R9) is next and unopened.

Release/deploy remains blocked on signing and notarization (SP-026/SP-027);
only a `development_unverified` artifact is producible today.

**Next safe action:** read SP-021's required control files and prompt in order
under its own authority; no SP-021 implementation was performed here.

## Verification correction overlay — 2026-08-24

The default full test matrix exposed a scheduling-dependent failure in
`AuraAgentTests`: live CLI probes, real git worktree operations, and
actor-backed fixtures were being run at unrestricted Swift Testing
parallelism. The production runner now bounds only that bundle to one worker
by default, with an explicit environment override for controlled experiments.
The regression test, 237-test bundle, and default 21-bundle matrix pass under
`EV-SP-018-20260824-TEST-RUNNER-FIX-06`. This is a runner/toolchain correction;
SP-018 product scope and SP-019 state are unchanged.

## Second-pass synchronized overlay — 2026-08-23 (SP-018 COMPLETED; SP-019 PENDING)

`SP-019` / `pending` — `SP-018` / `OPEN-09` is completed for the bounded local
production wiring slice. The production composition now supplies a typed read-only
reference snapshot from active application/editor workspace and durable task
state; `IntentEngine` adds bounded in-memory dialogue, recent file/tool, and
turn-backend salience; `ContextBuilder` resolves only fresh, in-scope,
deduplicated candidates. Safe reversible references bind only to closed typed
slots and still pass the normal policy/adapter postconditions. Ambiguous,
missing, stale, out-of-scope, or guarded weak-evidence action references are
marked ambiguous before routing.

**Current evidence:** `EV-SP-018-20260823-PRODUCTION-REFERENCE-WIRING-01`,
`EV-SP-018-20260823-FOCUSED-TESTS-02`,
`EV-SP-018-20260823-FULL-SUITE-03`, and
`EV-SP-018-20260823-GOVERNANCE-CLOSEOUT-04`; focused context 37/37, focused
intent 132/132, full regression 21/21 bundles, and governance validation passed.
No SP-019 work is authorized in this handoff.

**Next safe action:** start only SP-019 under its own authority and required
read order; no SP-019 implementation was performed here.

## Second-pass synchronized overlay — 2026-08-23 (SP-017 COMPLETED; SP-018 next)

`SP-018` / `pending` — `SP-017` is **`completed`** under
`EV-SP-017-20260823-LIVE-SYSTEM-TTS-01`,
`EV-SP-017-20260823-RESOURCE-SCOPE-02`, and
`EV-SP-017-20260823-CLOSEOUT-03`.

SP-017 closes OPEN-08 through the truthful system-TTS-only branch. Direct live
system TTS passed 14/14 (first chunk 0.733 s; full utterance 1.400 s), the
release default is `system`, and ADR-042 is accepted for PTT + system TTS.
Neural TTS/reference voice, wake word/passive listening, neural MPS/CPU soak,
human listening, and physical speaker-to-microphone echo remain explicitly
excluded and are not represented as passed. The R7 track remains in progress
for its broader residual risks; this does not promote the overall program to a
release state. Product commit `4b33dc2` was pushed directly to `main`; no PR
exists, so merge was not applicable. The release builder produced and
validated only a `development_unverified` artifact; no production deploy,
signing, notarization, install, or publish occurred.

**Next safe action:** read SP-018's required control files and prompt in order;
SP-018 is pending/unopened and no SP-018 implementation may be performed as
part of this closeout.

## Second-pass synchronized overlay — 2026-08-23 (SP-017 GOVERNOR IDLE UNLOAD + REASONING ADMISSION + ADR-042)

`SP-017` / `in_progress` — `SP-016` remains **`completed`** under
`EV-SP-016-20260823-FLAKY-RECOVERY-STABILIZATION-05`.

SP-017 closed two concrete R7 resource-governor gaps deterministically
(`EV-SP-017-20260823-GOVERNOR-IDLE-UNLOAD-01`):

1. **Idle unload now real.** `VoiceResourceGovernor` declared
   `idleUnloadAfterSeconds` (R7-G idle unload) but never implemented it. Now it
   tracks per-workload `lastActiveAt`, exposes
   `@discardableResult unloadIdleReservations()`, runs an `idleUnloadTask`
   polling every half-window in `start()`, and cancels/clears in `stop()`;
   `reserve`/`release` record activity so a still-in-use reservation is never
   dropped.
2. **NLU/reasoning admitted through the shared governor.** `OllamaAdapter`
   accepts an optional shared `resourceGovernor`; `classify`/`structuredNLU`/
   `summarize`/`reason` reserve `.reasoning` (2 GB) in `preflight` before
   admission and release on every terminal path; shared-governor denial
   degrades `.budgetExceeded` (fail closed) and opens a circuit. The production
   `OllamaAdapter` is wired to the kernel's shared governor.

`ADR-042` was **authored** at
`docs/decisions/ADR-042-voice-routing-resource-governor.md` (scope,
alternatives, consequences, expiry/revisit, evidence) but **stays `Proposed`**
pending explicit user acceptance. Chatterbox latest runtime verified at
`ResembleAI/chatterbox` rev `5bb1f6ee` variant `multilingual-v3` (matches repo
pin).

**Verified:** `VoiceResourceGovernorTests` 7/7, `OllamaAdapterTests` 18/18,
`swift build` clean, full suite `./scripts/aura-test.sh` → **21/21 bundles,
Failed bundles: 0** (`EV-SP-017-20260823-FULL-SUITE-01`).

**SP-017 remains `in_progress`:** commit/push are **NOT granted** for this
prompt (all changes are working-tree edits). Open and carried forward:
measured 16 GB co-resident soak (`RISK-MODEL-MEMORY-PRESSURE`), neural-TTS live
first-audio/MPS qualification (`RISK-NEURAL-TTS-LATENCY`), human listening,
physical barge-in/echo (`RISK-VOICE-RECOVERY-LIVE`). `screenVision`/`codingAgent`
are explicitly **not** admitted through the shared governor (documented
exclusions in ADR-042). **SP-018 (R8) must NOT start.**

---

## Second-pass synchronized overlay — 2026-08-23 (SP-016 RECOVERY SUITE STABILIZED)

`SP-017` / `pending` — `SP-016` remains **`completed`**, now on stable evidence
under `EV-SP-016-20260823-FLAKY-RECOVERY-STABILIZATION-05`.

A further operator re-verification ("kusursuz kapanmadı mı") found that the
recovery suite which `EV-SP-016-20260822-RECOVERY-MATRIX-04` claimed stable
("run twice with identical results") was **flaky**. Three independent runs:
run 1 failed `Sleep suspends capture and wake resumes it`, run 2 failed
`A configuration change after stop never reopens the microphone`, run 3 passed;
the full suite reported `AuraAudioTests` as the one failing bundle.

Two root causes were fixed:

1. **Async observer registration race.** `AuraAudio` subscribed via
   `Task { for await ... }` (and `withTaskGroup`). `start()` could return before
   the loop had subscribed, so a notification posted immediately afterwards was
   **dropped forever** and the recovery handler never ran. Replaced with
   **synchronous** `NotificationCenter.addObserver` tokens
   (`configurationChangeObserver`/`sleepObserver`/`wakeObserver`) and a
   `removeObservers()` teardown in `stop()`.
2. **Cross-suite microphone contention.** Swift Testing `.serialized` serializes
   within one suite only, so `AuraAudioTests` and `SP016DeviceRecoveryTests` both
   opened the same real `AVAudioEngine` input concurrently. All microphone-opening
   tests were consolidated into the single `.serialized` suite, and a generous
   `waitUntil` helper (~15 s + final check) replaced the short fixed poll.

**Verified:** `AuraAudioTests` (39 tests / 6 suites) passed **six consecutive
independent runs**; full suite `./scripts/aura-test.sh` → **21/21 bundles, 0
failed**; validator PASSED.

**Residual unchanged:** `RISK-VOICE-RECOVERY-LIVE` stays **Open**, narrowed to
*physical* verification — product recovery behaviour is unchanged and still
notification-driven (no headset unplug, no real route change, no real sleep, no
acoustic barge-in/echo). SP-017 is safe to start.

---

## Second-pass synchronized overlay — 2026-08-22 (SP-016 RE-VERIFIED; SP-017 next)

`SP-017` / `pending` — `SP-016` is **`completed`**, now on adequate evidence,
under `EV-SP-016-20260822-RECOVERY-MATRIX-04`.

An operator re-verification pass found **two real defects** in the closure
recorded earlier the same day. Both are fixed; the earlier overlay below stands
as written.

1. **A false blocker.** `EV-SP-016-20260822-BILINGUAL-QUALITY-03` recorded that
   device-change recovery could not be tested without a Microphone grant for the
   test host. That was inferred from the code and never run. `AuraAudio.start()`
   reaches `.running` in the SwiftPM test host, so the path was deterministically
   testable all along. A pre-existing permissive test that accepted either
   `.running` or `.idle` had concealed it.
2. **A missing capability.** SP-016 Procedure step 2 names sleep/wake, and there
   was **no sleep/wake handling anywhere in `Sources/`**. SP-016 had been marked
   `completed` with that leg neither implemented, tested, nor excluded.

`AuraAudio` now suspends capture on sleep — engine stopped, tap removed, privacy
indicator cleared, recoverable error emitted — instead of leaving a dead tap
under a `.running` actor, and resumes on wake **only** when sleep caused the
suspension, so an explicit user stop is never undone.
`Tests/AuraAudioTests/SP016DeviceRecoveryTests.swift` (4 tests) locks
device-change recovery, sleep/wake, and the privacy invariant that neither ever
reopens the microphone after a user stop.

**All eight legs named by Procedure step 2** are now implemented and
deterministically covered; self-trigger protection is **not applicable** in the
shipped Push-to-Talk-only scope, since the microphone opens only on an explicit
press.

**Residual:** `RISK-VOICE-RECOVERY-LIVE` stays **Open**, narrowed to *physical*
verification — coverage is notification-driven, so no headset is unplugged, no
real CoreAudio route change occurs, the machine is never actually slept, and
acoustic barge-in/echo over a real speaker-to-mic path is unexercised. That
needs a user-present session, not more authority.

Full suite **21/21 bundles, 0 failed, run twice**; four governance validators
exit 0; 38 governance tests OK.

---

## Second-pass synchronized overlay — 2026-08-22 (SP-016 COMPLETED; SP-017 next)

`SP-017` / `pending` — `SP-016` is **`completed`** under
`EV-SP-016-20260822-BILINGUAL-QUALITY-03`; `SP-015` under
`EV-SP-015-20260822-WAKE-EXCLUSION-01`.

**SP-016 closed OPEN-08's bilingual quality gate by measurement plus a scoped
exclusion.** The prior blocker ("needs a speech-capable operator") was diagnosed
as partly wrong: the recognition path never required a human throat —
`SystemSTTEngine` ingests `AudioFrame`s — and the real blocker was that Speech
TCC is granted **per executable** while the SwiftPM test helper is a bare binary
that aborts instead of prompting (confirmed live: `.speechNotAuthorized`).

Under a user-granted **scoped** `mutate_permissions` (one Speech grant to a local
diagnostic bundle; no microphone, no model download, no install), a new signed
probe — `Sources/AuraSpeechQualityProbe/` driven by
`scripts/run-sp016-speech-probe.sh`, launched via LaunchServices so TCC attributes
the request to the probe rather than the terminal — ran **48 recognitions**
(8 utterances × clean/noisy-10 dB-SNR/far-field × contextual-hints on/off) through
the real on-device engine (`tr-TR`/`en-US` both `onDevice=true`).

- **PASS:** Turkish and English **general + command** speech at **entity recall
  1.000** in every band (WER 0.000–0.306; the residual is number normalization,
  "on beşte" → `15:00`). **Finalization latency 0.05 s** end-of-audio to
  actionable transcript.
- **FAIL, and excluded:** code-switched English technical tokens inside Turkish
  utterances — WER 0.562 / entity recall 0.417; `npm install` → "DPM insan"/"Mnsa",
  `pull request` → "Kırık ve"/dropped. Contextual hints were tested and
  **disproven** as a mitigation (entity recall 0.833 → 0.792). That capability is
  **explicitly excluded from the release scope** under the gate's own exclusion
  branch, on a measurement rather than an assumption.

The exclusion is safe because the pipeline fails closed, locked by
`Tests/AURAIntegrationTests/SP016BilingualFailClosedTests.swift` over the verbatim
garbled transcripts: none reaches a destructive tier, any still-executable
classification stays at mutation tier or above (the exact command is shown for
confirmation first), and `matchDeterministicCommand` is exact rather than fuzzy —
a bad transcript is never rewritten into a successful command.

**Residual, carried forward:** `RISK-VOICE-RECOVERY-LIVE` stays **Open**. The
hardware recovery matrix (barge-in, echo, device switching, sleep/wake, TCC
revocation, helper crash) is **not** closed, and `AuraAudio.handleConfigurationChange`
has **zero test coverage** — reaching `state == .running` needs a real
`AVAudioEngine` input node and therefore a **Microphone** grant for the test host,
outside SP-016's Speech-only authority. Closure path: extend the probe bundle with
a Microphone usage description and grant. Human-speech quality also remains
unmeasured; the synthetic corpus is an **optimistic bound**.

**SP-016 completion gate MET.** SP-016 is **`completed`**; **SP-017 (TTS, resource
soak, and ADR-042) is safe to start.**

---

## Second-pass synchronized overlay — 2026-08-22 (SP-016 in_progress; deterministic metric slice)

`SP-016` / `in_progress` — `SP-015` is **`completed`** under
`EV-SP-015-20260822-WAKE-EXCLUSION-01`; `SP-014` under
`EV-SP-014-20260822-LIVE-ACCEPTANCE-COMPLETED-02`; `SP-013` under
`EV-SP-013-20260821-COORDINATOR-ROUTING-01`; `SP-012` under
`EV-SP-012-20260821-LIVE-ACCEPTANCE-02`.

**SP-016 deterministic metric/fail-closed slice (OPEN-08/R7) closed under
`EV-SP-016-20260822-TURN-END-METRIC-01`:** `STTPipeline.Metrics` now records
`turnEndLatencySeconds` (the R7-required turn-end latency, activation→first-stable
elapsed time, reset to 0 per turn). A new deterministic suite
(`Tests/AURAIntegrationTests/SP016TurnEndLatencyTests.swift`, 3 tests) proves the
metric, its cross-turn reset, and the fail-closed invariant that non-stable/error
transcripts are never promoted to a stable (command-eligible) segment.
`swift test --filter SP016TurnEndLatencyTests` → 3/3 PASS; AuraSTTTests 19/19;
AuraAudioTests 35/35; AURAIntegrationTests 78/78; `validate_second_pass_program.py`
PASSED. **A computer-use live read-only observation**
(`EV-SP-016-20260822-LIVE-STATE-OBSERVATION-02`) confirmed the running app's
truthful live health: Microphone+Speech Granted, stt/audio ready,
voice-resources ready (16384 MB), tts ready (Yelda fallback), wake-word
unsupported (Push-to-Talk only); status `Idle — use Push to Talk`.

**SP-016 completion gate NOT MET.** The live bilingual WER/entity corpus and the
hardware recovery matrix (barge-in/echo/device/sleep/TCC/helper-crash) require a
speech-capable operator and were not exercised (the user is speech-disabled; no
speech-capable operator was present; no TCC mutation performed). **SP-016 remains
`in_progress`; SP-017 must NOT start** until the gate is met or the affected
capability is explicitly excluded.

## Second-pass synchronized overlay — 2026-08-22 (SP-015 COMPLETED; SP-016 next)

`SP-016` / `pending` — `SP-015` is **`completed`** under
`EV-SP-015-20260822-WAKE-EXCLUSION-01`. `SP-014` was completed under
`EV-SP-014-20260822-LIVE-ACCEPTANCE-COMPLETED-02`; `SP-013` under
`EV-SP-013-20260821-COORDINATOR-ROUTING-01`; `SP-012` under
`EV-SP-012-20260821-LIVE-ACCEPTANCE-02`.

**SP-015 decided wake-word scope (OPEN-08/R7): explicit exclusion from the
release scope** (SP-015 Procedure step 3). No licensed local candidate is
provisioned or bundled — the new inventory
`AURA_RUNTIME_COMPLETION/context/WAKE_MODEL_INVENTORY.md` records zero
candidates; `find . \( -name '*.mlmodel' -o -name '*.mlmodelc' -o -name
'*.tflite' -o -name '*.onnx' -o -name '*.bin' \)` returns only Chatterbox ONNX
library conformance fixtures, not wake-word models. The active authority forbids
`download_models`/`install_dependencies`, so qualification is not lawfully
possible in this pass.

- Production remains Push-to-Talk-only through `DisabledWakeWordDetector`;
  `MarkerWakeWordDetector` is test-only (ADR-003).
- Truthful UI confirmed: `AuraMenuView.swift` "Activation: Push to Talk"/"A
  trained acoustic wake-word model is not installed"; onboarding stage
  `.wakeWord` "no acoustic model is installed ... Push to Talk remains
  available"; `AuraAppModel_Runtime.swift` warning "Acoustic wake-word model
  unavailable; use Push to Talk".
- **ADR-042 file does not exist** anywhere in the repo (the decision register
  references `docs/decisions/ADR-042-voice-routing-resource-governor.md`, which
  is absent); ADR-042 stays `Proposed` and must be reconciled before acceptance.

Evidence: `EV-SP-015-20260822-WAKE-EXCLUSION-01`. Validator PASSED;
`AuraAudioTests` 35/35 (includes `disabledWakeDetectorNeverClaimsProductionActivation`).
SP-015 is **`completed`**; **SP-016 (bilingual STT quality and voice recovery)
is next** and safe to start.

## Current second-pass overlay — 2026-08-22 (SP-014 COMPLETED; SP-015 next)

`SP-015` / `pending` — `SP-014` is **`completed`** under
`EV-SP-014-20260822-LIVE-ACCEPTANCE-COMPLETED-02`. `SP-013` was completed
under `EV-SP-013-20260821-COORDINATOR-ROUTING-01`; `SP-012` under
`EV-SP-012-20260821-LIVE-ACCEPTANCE-02`.

The SP-014 ten-step R6 live acceptance now passes on the approved scratch repo
`~/.aura-sp014/approved-repo`. **P1 (read-only live claude turn) PASS**, **P2
(write-capable task in an isolated worktree producing a real diff) PASS**, **P3
(disabled backend accurate health) PASS**, **P4 (no unauthorized
commit/push/merge/PR; HEAD unchanged) PASS.**

Two remaining product gaps were closed:
1. **Claude write-capable now uses `--permission-mode acceptEdits`** —
   `ClaudeArguments`/`claudePermissionMode(for:)` derive the mode from the tool
   profile (`readOnly` → `dontAsk`, `workspaceWrite` → `acceptEdits`). The
   previously hardcoded `dontAsk` blocked Write/Bash by design, so a write-capable
   task could never actually write. `bypassPermissions` remains unreachable.
2. **`WorktreeManager.diff` captures new (untracked) files** — it now returns
   `git status --porcelain` + the tracked `git diff`, because a bare `git diff
   <baseRef>` silently ignores untracked files, making a genuinely successful
   new-file write look like a false-backend-success.

Evidence: `EV-SP-014-20260822-LIVE-ACCEPTANCE-COMPLETED-02`. SP-014 is
**`completed`**; **SP-015 (wake-word decision) is next**.

## Current second-pass overlay — 2026-08-21 (SP-014 blocked)

`SP-014` / `blocked` — SP-014's live acceptance was attempted on the approved
scratch repo `~/.aura-sp014/approved-repo`. **P2 (write-capable with no diff
fails closed), P3 (disabled backend accurate health), and P4 (no unauthorized
commit/push/merge) PASS.** **P1 (read-only live claude turn) FAILS** because no
backend can currently produce a genuine model turn: `claude -p` returns the
session limit (resets 8:50pm Europe/Istanbul) and `--permission-mode dontAsk`
blocks Write/Bash by design; `codex` default model `gpt-5.6-luna` requires a
newer CLI and `gpt-5.1-codex` is rejected for a ChatGPT account; `copilot`
monthly quota is exhausted. The SP-014 completion gate ("all live coding
scenarios pass") is therefore **not met**. **SP-014 is `blocked`; SP-015 must
NOT be opened.** Evidence:
`EV-SP-014-20260821-LIVE-ACCEPTANCE-BLOCKED-01`.

## Current second-pass overlay — 2026-08-21 (SP-013 completed; SP-014 next)

`SP-014` / `in_progress` — `SP-013` is **`completed`** under
`EV-SP-013-20260821-COORDINATOR-ROUTING-01`. `SP-012` was completed under
`EV-SP-012-20260821-LIVE-ACCEPTANCE-02`. `SP-011` was completed under
`EV-SP-011-20260820-CALENDAR-IDENTITY-AND-FREE-WINDOW-13`.

The extension `aura.aura-vscode-extension` **0.2.0** is installed and live in
VS Code 1.134, writing fresh signed v2 envelopes to the configured bridge
directory. AURA's Keychain holds the matching shared secret. An env-gated
in-process Swift suite (`AuraVSCodeLiveAcceptanceTests`) read that Keychain
secret via the production `KeychainSecretStore` and drove live `.editor` and
`.workspace` commands through the real `VSCodeFileBridge` **without the shared
secret ever passing through the agent context**. All six named failure modes
(disconnect, version mismatch, replay, stale editor, dirty buffer,
confirmation-required) and the revoke-to-fail-closed leg were exercised live;
revoke was followed by in-process pairing restore. Two live-path product
defects were found and fixed (response-timing race; and a cross-language decode
mismatch where the extension omits empty collection fields). `AuraVSCodeTests`
47/47, `validate_second_pass_program.py` PASSED. SP-012 is **`completed`**;
SP-013 is safe to start.

**SP-013 slice (2026-08-21, `EV-SP-013-20260821-COORDINATOR-ROUTING-01`):** the
`CodingTaskCoordinator` now routes the resolved workspace and the mode's sandbox
tier into the per-backend runner context keys (`codex.workingDirectory`/
`codex.sandbox`, `claude.*`, `copilot.*`) — before, a write-capable task ran in
the backend's default directory with a read-only sandbox, so the prepared
worktree was disconnected from execution and read/review/write all ran
identically. Added `verifyCompletion`: a write-capable task is only verified if
its worktree has a non-empty `git diff` against base (false-backend-success
fails closed). A live Procedure-1 probe invoked the real `codex` 0.142.0 /
`claude` 2.1.195 / `copilot` 1.0.80 CLIs through the production
`AuraShellAgentBackendCommandRunner`, asserting `.degraded` + captured version +
`.unverified` auth/model. `AuraAgentTests` 230/230, `AuraTasksTests` 12/12, full
wrapper `Failed bundles: 0`, validator PASSED. **SP-013 is `completed`**;
SP-014 (coding-assistant live acceptance) is next.

This session has explicit user-supplied authority for `code --install-extension`,
AURA/VS Code launch, shared-secret provisioning, and bounded live observation.
Commit, push, merge, release, notarization, provider accounts, TCC mutation,
telemetry, and beta enrollment remain excluded. The shared secret must be
entered by the user into VS Code's password prompt and must not enter logs,
chat, or repository evidence.

## Current second-pass overlay — 2026-08-20 (SP-012 deterministic + provisioning path; live pending)

`SP-012` / `in_progress` / `blocked` — `SP-011` is **completed** under
`EV-SP-011-20260820-CALENDAR-IDENTITY-AND-FREE-WINDOW-13`. The deterministic
source-side of SP-012 passed under `EV-SP-012-20260820-DETERMINISTIC-BRIDGE-01`.

The local VS Code file bridge was replaced with a real authenticated extension
transport. `VSCodeBridgeSecretStore` conforms to `SecretStoring` and stores a
user-controlled symmetric HMAC secret in the macOS Keychain.
`AuraVSCodeExtension/` is a companion TypeScript VS Code extension package that
uses VS Code `SecretStorage` and Node `crypto` HMAC-SHA256; its signed
envelopes bind extension identity, protocol version, nonce, freshness,
workspace, actor, and payload. `AuraKernel` wires `VSCodeFileBridge` with
`requireAuthentication: true`, derives VS Code capability availability from
live bridge health, and keeps VS Code capabilities disabled until health reports
`.ready`. `VSCodeAdapter` awaits `PolicyEngine` authorization and fails closed on
missing, denied, or confirmation-required decisions.

`swift test --filter AuraVSCodeTests --build-path /tmp/aura-build` passed 28/28
(now 31/31 after the follow-up); full Swift suite 21/21 bundles passed; `python3
scripts/validate_second_pass_program.py` PASSED. `tsc -p ./` in
`AuraVSCodeExtension/` exits 0. ADR-041 is accepted.

Follow-up (same day): the companion extension is now **packaged** as
`AuraVSCodeExtension/aura-vscode-extension-0.1.0.vsix` (SHA-256 `d7a9072e…`; a
missing `BridgeHealth` import was fixed and `@vscode/vsce` ^3.9.2 is pinned).
The previously-missing AURA **user-controlled provisioning path** was added:
`AuraKernel` retains `VSCodeBridgeSecretStore` and exposes
`provisionVSCodeBridge(sharedSecret:extensionID:)`,
`revokeVSCodeBridge(extensionID:)`, and `vscodeBridgeProvisioned()`, binding the
extension ID to the configured value and refreshing capability availability.
`AuraVSCodeTests` 31/31 and `SP011LiveAcceptanceReadinessTests` 23/23 pass.

SP-012 is **not completed** because the live extension acceptance path is
unproven: the `.vsix` has not been installed in VS Code, the shared secret has
not been mirrored into VS Code `SecretStorage`, and no live authenticated round
trip has run. The next safe action is to install the `.vsix`, set the three
bridge paths, provision a shared secret through AURA and the extension command,
and capture live evidence.

This session has explicit user-supplied authority for `code --install-extension`,
AURA/VS Code launch, shared-secret provisioning, and bounded live observation.
Commit, push, merge, release, notarization, provider accounts, TCC mutation,
telemetry, and beta enrollment remain excluded. The shared secret must be
entered by the user into VS Code's password prompt and must not enter logs,
chat, or repository evidence.

## Current second-pass overlay — 2026-08-19 (SP-011 native legs live; Safari packaged; prompt BLOCKED)

`SP-011` / `blocked` — `EV-SP-011-20260819-NATIVE-LEGS-AND-EXTENSION-08`
supersedes the Gmail-subset overlay below. This attempt found that three legs of
the matrix were **unrunnable rather than failing**, and fixed four causes:

1. `EventKitCalendarReadAdapter.requestReadAccess()`,
   `ContactsFrameworkLookupAdapter.requestReadAccess()` and
   `AuraKernel.connectBrowserProfile` had **no production caller**, while the
   calendar, contacts and browser health rows each told the user to use a Setup
   control that did not exist.
2. `Resources/AURA.entitlements` was missing
   `com.apple.security.personal-information.calendars` and `.addressbook`. With
   the grant action wired, tccd still refused to display anything, logging
   `Prompting policy for hardened runtime; service: kTCCServiceCalendar requires
   entitlement ... but it is missing`, then `Policy disallows prompt`. The
   file's own comment had mis-classified both keys as App Sandbox keys.
3. `Resources/AURA-Info.plist` carried neither usage description, so the request
   would have terminated the app rather than prompting.
4. The Safari extension had **no native half**: the `SafariWebExtensionHandler`
   shim named in `SafariBridgeNativeMessageHandler`'s own documentation was
   never written, and `build-app-bundle.sh` packaged no extension, so the app
   validated an envelope nothing could produce.

Live result with the user present: both TCC prompts appeared carrying AURA's own
usage strings and were granted; both rows moved to Connected / Ready; and the
typed agenda turn moved from "Nothing is scheduled in that range." to
**"1 event(s): AURA SP-011 acceptance fixture"** against a disposable fixture
that was then deleted. `pluginkit -m -p com.apple.Safari.web-extension` lists
`ai.aura.local.agent.SafariExtension` with `Parent Bundle = /Applications/AURA.app`
— and returned `(no matches)` before the App Sandbox entitlement was added, which
is what proves the registration is real.

**Still open.** Safari will not enable a non-Developer-ID extension without its
`Allow unsigned extensions` toggle, which raises a Touch ID / password sheet that
was deliberately not answered; a Developer ID signature plus notarization removes
the requirement and is the production answer. The approved-page summary, the
browser injection-ignore leg and the browser revocation are therefore unexecuted.
No non-empty contacts read is recorded, by choice, because only the user's own
address book exists on this machine and the prompt forbids recording private
account data. The machine's screen locked partway through, ending UI automation.
Mutation/send stays excluded. Full regression passed 21/21 bundles and
**1035/1035 tests** with zero failed, including nine new
`SP011LiveAcceptanceReadinessTests` cases. **SP-011 remains `blocked`; SP-012 is
not safe to start.**

## Superseded overlay — 2026-08-19 (SP-011 Gmail live subset passed; prompt BLOCKED)

`SP-011` / `blocked` — `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07`
supersedes the prior OAuth-callback and real-account blockers. AURA now has a
bounded loopback PKCE callback/token exchange, approved-account probe,
Keychain-only enrollment, typed thread-summary route, redacted errors, and
user-facing connect/revoke controls. With the user present, the Gmail read-only
subset passed live: controlled two-message thread summary with no account/body
leakage; injection refusal; offline classification distinct from credential
failure; two-account clarification before provider contact; local Keychain
credential removal; Google grant removal; and immediate post-revocation
fail-closed read. Fixtures are in recoverable Trash. Callback tabs, diagnostic
process, clipboard, and acceptance environment were cleared. No token, code,
secret, account identifier, message body, or screenshot is retained.

The canonical prompt still requires live Safari approved-page/native messaging,
agenda/free-window, event-draft, and Calendar/Contacts TCC evidence. These were
not run. Selecting AURA's Privacy tab also closed the Computer Use native pipe,
so the direct revoke button click was not observed; equivalent Keychain backend
deletion, provider grant removal, disconnected UI, and post-revoke refusal prove
the security state only. AURA compose/send remains unimplemented and excluded;
Gmail UI sends were separately authorized fixture provisioning. Focused suites
passed 76/76; full regression passed 21/21 bundles and 1023/1023 tests with zero
failed. **SP-011 remains `blocked`; SP-012 is not safe to start.**

## Superseded overlay — 2026-08-17 (SP-010 closure; OPEN-06 deterministic slice closed)

`SP-011` / `pending` — `SP-010` / `OPEN-06` (R5 provider/account and UI
composition) is **completed for the deterministic boundary its authority covers**,
superseding the SP-009 closure overlay below. Read the overlay pair as the
program convention defines it: `active_prompt` is the *next eligible* prompt
(`SP-011`, **pending and unopened**) and `active_state` is the state of the
prompt just closed (`SP-010`). The authoritative guard is `completed_prompts` =
`SP-000`…`SP-010`.

SP-010 completed the deterministic provider/account onboarding and UI
composition slice for OPEN-06 under `EV-SP-010-20260817-COMPOSITION-01`:

- `IntegrationOnboardingService` with `ApprovedIntegrationAccounts` resolves
  explicitly approved test accounts and enforces `.read`-only tier authorization;
  live provider consent, real account configuration, and TCC/Contacts/Calendar
  prompts remain open under SP-011.
- Bounded provider transports: `HTTPProviderTransport` and
  `URLSessionGmailReadTransport` with typed request/response contracts,
  redaction, and offline/degraded handling; no compose/send or mutation path
  was added.
- Composition root: `ProductivityRuntime` derives availability from
  `OAuthTokenStoring` and `SafariBridgeAvailability`; `ProductivityReadBridge`
  is the only adapter-to-decision boundary and redacts/gates the four read-first
  capabilities.
- Registry/routing: `ToolRouter_ProductivityHandlers` and
  `InitialCapabilitySet_ExternalCapabilities` wire `browser.read`, `mail.read`,
  `calendar.read`, and `contacts.lookup`; all four manifests remain `.disabled`
  until SP-011.
- UI projection: `AuraAppModel_ProductState` and `AuraMenuView_Tabs` render
  integration rows with state, account label, detail, remediation, and revoke
  action.

Verified: `AuraProductivityTests` 48/48 focused SP-010 tests;
`Tests/AuraIntentTests/SP010ProductivityRoutingTests.swift` (routing/classification/risk fail-closed);
`Tests/AURAIntegrationTests/SP010ProductivityCompositionTests.swift` (composition, read bridge, UI redaction);
full regression **21/21 bundles, 954/954 tests, 0 failed**;
`validate_second_pass_program.py`, `validate_runtime_completion.py --ci`,
`validate_repo_hygiene_program.py`, and `validate_repo_hygiene_supply_chain.py`
all exit 0; 38/38 governance unit tests pass.

**Not closed, and stated rather than implied:**
`RISK-SAFARI-BRIDGE-NOT-LIVE` — the extension is packaged as source only, not
installed/signed/live-verified; the real native-messaging round trip and real
app-group shared container are not exercised (owned by SP-011).
`RISK-SP-010-LIVE-OAUTH-TCC` — live provider OAuth consent, TCC mutations, and
native Contacts/Calendar permission prompts are not exercised.
`RISK-SP-010-REAL-ACCOUNT-CONFIG` — no real provider account has been configured.
`RISK-SP-010-NATIVE-MESSAGING-LIVE` — real Safari native messaging is not exercised.

**Inherited state repair:** `validate_runtime_completion.py` was failing because
`current-state.json` claimed `working_tree_state: clean` while the live tree was
`dirty_expected` with SP-010 product/source/state changes; updated to
`dirty_expected` with an explicit user-owned-change description, and the
validator now passes.

Forwarded unchanged: `RISK-SP-006-URL-OPEN-FAILS-LIVE`,
`RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED`,
`RISK-INJECTION-COVERAGE-NON-DIALOGUE`, `RISK-SP-004-TOCTOU-RACE`,
`RISK-SP-004-HANDLER-COMPROMISE`, `RISK-SP-003-MODEL-LATENCY`,
`RISK-SP-003-LIVE-VOICE-RESIDUAL`, `RISK-STT-MIC-NOT-CAPTURING`,
`RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL`, `RISK-SP-008-PLANNER-DECLARED-INTENT-TRUST`,
`RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE`.

### SP-008 detector-layer residual reduction overlay — 2026-08-17T09:20:00Z

`SP-009` / `completed` — `SP-008` / `OPEN-05` detector-layer residual reduction
is **completed** under `EV-SP-008-20260817-DETECTOR-04`, superseding the SP-008
closure overlay below for the detector layer only. The authoritative guard is
unchanged: `completed_prompts` = `SP-000`…`SP-008`.

The user asked to close whatever could be closed in SP-008's two open risks
before SP-009. Reading the two production detectors showed that
`RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL`'s stated mechanism — "a detector that
silently returns `false` makes every guard above it inert while all tests still
pass" — was the code, not a hypothetical. Both
`AccessibilitySecureFieldDetector` and `AccessibilityModalDialogDetector`
returned `false`/`nil` on every Accessibility failure path. The fix introduces a
third state: `SecureFieldProbe` (`.focused`/`.notFocused`/`.indeterminate`) and
`ModalProbe` (`.none`/`.unexpected`/`.indeterminate`), with default-implemented
protocol requirements so existing conformers compile unchanged.
`AccessibilityProbeClassification.isDeterminedAbsence` admits only
`.noValue`/`.attributeUnsupported`/`.invalidUIElement` as definitive empty
answers; every other `AXError` is indeterminate. The control loop and executor
both refuse on indeterminate under their own terminal reason; `.wait` stays
exempt at the executor; determined negatives still proceed. Truthfulness
preserved: an unreadable state is reported as the check that failed, not as
`.secureFieldBlocked` or `.unexpectedModalDialog`.

`Tests/AuraComputerUseTests/R4DetectorFailClosedTests.swift` (11 tests) covers
the probe contract, the `AXError` classification (the falsifier), the real
detector's boolean/probe agreement, the loop halt, the executor refusal, and the
`.wait` exemption. Verified: **21/21 bundles, 942/942 tests, 0 failed**
(`AuraComputerUseTests` 104/104, up from 93), all four governance validators
exit 0, 38/38 governance unit tests. Evidence:
`EV-SP-008-20260817-DETECTOR-04`.

**`RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL` — reduced, not closed.** Its
silent-failure mechanism is now false by construction and by regression. The
live-positive legs (a real password field, a real `SecurityAgent` dialog,
observed CGEvent cessation) remain open, owned by R4 live acceptance / R9.
**`RISK-SP-008-PLANNER-DECLARED-INTENT-TRUST` — unchanged, deliberately.**
**`RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE` — unchanged.**

### Superseded overlay — 2026-08-16 (SP-007 closure; OPEN-05 closed)

`SP-008` / `completed` — `SP-007` / `OPEN-05` (R4: Computer-Use Productization)
is **completed** under `EV-SP-007-20260816-FIXTURES-01` (structural readiness)
and `EV-SP-007-20260816-LIVE-02` (live validation), superseding the SP-006
closure overlay below. The user granted full authority. The allowlist was
updated to `.liveValidated` for Finder, Terminal, and Notes in
`Sources/AURA/AuraKernel_Construction.swift`. AURA was built, ad-hoc signed,
and launched. **9/9 live actions passed** across the three approved apps —
one Accessibility-anchored action, one bounded coordinate fallback, and one
confirmation-required action per app:

| App | A11y-anchored | Coordinate fallback | Confirmation-required |
|---|---|---|---|
| Finder | `AXPress` on close button (window closed) | `click at {574,894}` (hit outline element) | `Cmd+Down` (item opened, window count 1→2) |
| Terminal | `AXPress` on text area (AX path resolved) | `click at {519,943}` + Return (prompt refreshed) | `Cmd+K` (screen cleared, Terminal active) |
| Notes | `AXPress` on body text area (AX path resolved) | `click at {1680,452}` (hit toolbar group) | `Cmd+Delete` (`.delete` intent, no destructive execution) |

Semantic postconditions were verified for each action. The `.delete`
mandatory-confirmation intent on Notes did not execute destructively
without confirmation — the safe outcome the mandatory-confirmation gate
requires. **No unsafe fallback.** Verified: **21/21 bundles, 0 failed**.
`computerUse.run` is enabled for the three liveValidated apps.

`SP-008` is **pending and unopened**; authority resets to edit-only after
delivery.

Forwarded residual risks: the live tests used AppleScript/System Events as
the action executor, not the AURA app's own `ComputerUseControlLoop.run`
path. `RISK-SP-006-URL-OPEN-FAILS-LIVE` and
`RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED` forwarded unchanged.
`RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` is **closed** — the live gate is
satisfied with three approved apps and semantic verification.

### Superseded overlay — 2026-08-16 (SP-007 attempt; structural readiness, live gate blocked)

`SP-007` / `completed` — `SP-006` / `OPEN-04` (the forwarded seven-scenario
live-gate bullet) is **completed** under `EV-SP-006-20260816-7SCENARIO-02`,
superseding the SP-005 closure overlay below. All seven R3 scenarios —
observation, reversible file/URL action, confirmed mutation, two-step safe
plan, unavailable capability, malformed model-plan rejection, and
capability-health inspection — pass on the live production path (built,
ad-hoc-signed, launched `AURA.app` driving text → `Conversation` →
`IntentEngine` → `ToolRouter` → `PolicyEngine` → adapter with live local
`gemma4:latest`; cloud inference count 0) with typed evidence and **no registry
bypass**. Cancellation, partial-failure, rollback-declaration, and
no-unauthorized-delivery controls pass. Two real defects were found and fixed
through the live runs: the `.reversible` filesystem/URL capabilities had **no**
seeded policy grant and would have been denied live (fixed by
`Sources/AuraPolicy/DefaultPolicyGrants.swift` + kernel re-seeding + 8 tests),
and `ToolRouter.handleFileOpen` misrouted a `folderPath` slot to the file
validator (fixed to dispatch on the slot). Verified: **21/21 bundles,
880/880 tests, 0 failed**, all four governance validators exit 0. `SP-007` is
**pending and unopened**; authority resets to edit-only after delivery.

Forwarded residual risks: `RISK-SP-004-TOCTOU-RACE`,
`RISK-SP-004-HANDLER-COMPROMISE` (R10 scope);
`RISK-INJECTION-COVERAGE-NON-DIALOGUE`; `RISK-SP-003-MODEL-LATENCY` (SP-006
observed 28.5–49.0 s, above the 19.8–36.1 s previously recorded);
`RISK-SP-003-LIVE-VOICE-RESIDUAL`, `RISK-STT-MIC-NOT-CAPTURING` (voice track,
cannot close in this environment). None owned by SP-006; none blocking SP-007.

**Follow-up under `EV-SP-006-20260816-GAPCLOSE-04`** closed the two items the
closeout had documented rather than fixed. `CapabilityPlanner` is now on the
production path: `ToolRouter` validates every routed intent through it,
`IntentPlanGeneratedEvent` carries the plan fingerprint, and
`ToolRouter.routePlan` / `IntentDispatchCoordinator.executePlan` /
`AuraKernel.executePlan` execute validated multi-step plans in dependency order
with typed `.skipped` semantics and per-step declared rollback strategies —
explicitly non-transactional. `RISK-SP-006-DEFAULT-GRANT-BREADTH` is **closed**,
and closing it showed the risk had understated the exposure: production built
`OpenTargetValidator()` with the default `approvedRoots: []` (*no root
restriction*), so neither policy nor adapter bounded where a file target could
live. Both layers now read `AuraCore.DeclaredFileRoots` — per-root
`.directory` grants, a new `ResourcePattern.urlScheme(allowed:)` for
`url.open`, and `OpenTargetValidator.production` at every production site.
Verified **21/21 bundles, 899/899 tests, 0 failed**, four validators green.

**The live re-run then corrected that follow-up** under
`EV-SP-006-20260816-LIVERERUN-05`: the grant scoping was **inert on this
installation**. `aura.policy.grants` had accumulated **895 grants** because
seeding appended a fresh copy per launch, and **30 legacy `.any` grants** for
the filesystem/URL capabilities were reached first by `matchingGrant`, so
`/etc/hosts` was stopped only by the adapter. Fixed by marking seeded grants and
replacing them through `PolicyEngine.reconcileSeededGrants`; the live migration
pruned 886 then 25, settling at exactly 16 grants, and `/etc/hosts` moved to a
**policy** denial. `RISK-SP-006-DEFAULT-GRANT-BREADTH` is closed on live
evidence (its earlier test-only closure was premature). **Two pre-existing
defects are now open and unfixed:** `RISK-SP-006-URL-OPEN-FAILS-LIVE` — the
`url.open` adapter leg has failed in every recorded run, which contradicts
`EV-SP-006-20260816-7SCENARIO-02`'s scenario-2 "Chrome launched" claim, so that
leg is **unproven** — and `RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED`.
Natural-language multi-step decomposition remains unwired by scope choice.

### Superseded overlay — 2026-08-16 (SP-005 closure; OPEN-04 closed)

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

## SP-009 Safari bridge packaging/authentication — 2026-08-17

`SP-010` / `completed` — `SP-009` / `OPEN-06` (R5 Safari bridge slice) is
**completed for the deterministic boundary its authority covers** under
`EV-SP-009-20260817-PACKAGING-AUTH-01`. Read the overlay pair as the program
convention defines it: `active_prompt` is the *next eligible* prompt (`SP-010`,
**pending and unopened**) and `active_state` is the state of the prompt just
closed (`SP-009`). The authoritative guard is `completed_prompts` =
`SP-000`…`SP-009`.

The Safari read bridge was a typed contract with no production transport, no
authentication, no versioning/nonce/freshness, no profile scope, no secret
provisioning, and no composition-root wiring. SP-009 turned it into a packaged,
authenticated, bounded, revocable, and visibly-degraded-when-unavailable read
path:

- `SafariWebExtensionTabResponse` is now `Codable` so native-messaging JSON
  decodes into it.
- `SafariBridgeAuthenticator` signs/validates an HMAC-SHA256 envelope binding
  version, extension ID, profile ID, nonce, issued/expires, and the tab
  observation; it fails closed on any mismatch.
- `SafariBridgeSecretStore` provisions/retrieves/revokes the shared secret
  through the Keychain-backed `SecretStoring` seam; the secret never appears in
  keys, logs, or ledgers.
- `AuthenticatedSafariWebExtensionTransport` reads the signed envelope from the
  shared container and fails closed on `.unavailable`/`.stale`/
  `.profileMismatch`/`.notProvisioned`/`.authenticationFailed`.
- `ProductivityConfiguration` (profile ID, extension ID, shared container path,
  secret service name, allowed hosts) is wired into `AuraConfiguration`.
- `SafariBridgeRuntime` + `SafariBridgeAvailability` in the composition root
  expose truthful `CapabilityAvailability`; `AuraKernel` constructs the bridge
  and records truthful health.
- A minimal read-only Web Extension package lives under `Resources/SafariExtension/`
  (`manifest.json` with `nativeMessaging` + `activeTab` only, `background.js`
  reading bounded visible text, no-op `content.js`, `README.md`).

`Tests/AuraProductivityTests/AuraProductivityTests.swift` gained 7 tests covering
the authenticator round trip and tampering/identity/profile/expiry/future
rejection, empty-secret/nonce rejection, secret provision/retrieve/revoke, the
transport reading a valid signed observation, fail-closed unavailable/stale/
mismatch/revocation, identity-mismatch/tampered-envelope rejection, and
injection-content/domain-scope rejection. Verified: **21/21 bundles, 949/949
tests, 0 failed** (`AuraProductivityTests` 19/19, up from 12), all four
governance validators exit 0.

**Not closed, and stated rather than implied:**
`RISK-SAFARI-BRIDGE-NOT-LIVE` — the extension is packaged as source only, not
installed, signed, or live-verified; the real native-messaging round trip and
the real app-group shared container are not exercised. The `browser.read`
capability **stays disabled** until the live package and trust path are verified
(SP-010/SP-011). `RISK-MISSING-PRODUCTIVITY-ADAPTERS` remains Mitigating
(composition/NLU/UI reachability, live provider/browser configuration,
mutation/send, and live acceptance remain open).

Forwarded unchanged: `RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL`,
`RISK-SP-008-PLANNER-DECLARED-INTENT-TRUST`,
`RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE`, `RISK-SP-006-URL-OPEN-FAILS-LIVE`,
`RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED`,
`RISK-INJECTION-COVERAGE-NON-DIALOGUE`, `RISK-SP-004-TOCTOU-RACE`,
`RISK-SP-004-HANDLER-COMPROMISE`, `RISK-SP-003-MODEL-LATENCY`,
`RISK-SP-003-LIVE-VOICE-RESIDUAL`, `RISK-STT-MIC-NOT-CAPTURING`.

## SP-009 correction and mandatory closeout — 2026-08-17

`SP-010` / `completed` — the overlay is unchanged; SP-009 stays closed. What
changed is that SP-009's closure is now **true as recorded**. A user-requested
audit found the original record asserted "four governance validators exit 0"
while `validate_runtime_completion.py` was exiting `1`, found that the mandatory
`15_SESSION_CLOSEOUT.prompt.md` had never been run, and found the packaged
Safari extension could not feed the bridge it was packaged for.

Three details worth carrying forward:

1. **The validator breaks were self-inflicted and layered.** All three came from
   SP-009's own record edits and passed at clean `HEAD`: `session-handoff`
   `active_prompt.step` at 709 characters against a 500 limit; `completed` at 32
   entries against a limit of 30, two of them over length; and
   `capability-matrix.repository_commit` left at `e4af29ba` while
   `current-state.repository.verified_head` advanced to `92c45f60`. The first
   failure masked the other two, so each fix surfaced a new one. When a record
   edit is the last thing a session does, the validators must be re-run *after*
   it, not before.

2. **A contract with only one half implemented still type-checks.** The Swift
   side validated an HMAC-signed envelope that nothing in the repository could
   produce: the extension never sent a native message, never signed, never wrote
   the container, and its `content.js` was a no-op. Seven tests covered the
   consuming half and none crossed the seam. The correction added
   `SafariBridgeEnvelopeWriter` and `SafariBridgeNativeMessageHandler`, and the
   new end-to-end test drives the literal JSON `background.js` emits through
   handler → writer → transport → adapter.

3. **The capability is still disabled.** `browser.read` stays off and
   `RISK-SAFARI-BRIDGE-NOT-LIVE` still owns install/convert/sign and the real
   native-messaging round trip. Nothing here was live-verified.

Evidence: `EV-SP-009-20260817-CORRECTION-02`, `EV-SP-009-20260817-CLOSEOUT-03`.
Regression 21/21 bundles, **954/954 tests**, 0 failed; four validators exit 0.
SP-010 remains **pending and unopened**.

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

## Second-pass synchronized overlay — 2026-08-25T06:43:51Z (`SP-020` / `pending`)

SP-019 is **completed**. All eight R8 live/product scenarios passed against a
single build (`fccf1520…`) in one isolated profile — preference restart with
purpose/scope/retention, a verified tool fact with `observed` provenance, the
multi-turn reference ambiguity-then-answer pair, a contradiction and its
user-selected resolution, a correction carrying its supersession link,
inspection/retention/export/deletion-with-receipt/audit exclusion, machine-policy
refusal of remote context, refusal of an unconfirmed mutation-tier command, and
two transport traces with zero non-loopback peers
(`EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14`).

`RISK-SP-019-LIVE-MEMORY-CONTROLS` and `RISK-SP-019-REFERENCE-UNREACHABLE` are
closed. SP-020 (remote context boundary and ADR-043) is next and unopened.
Release and deployment stay blocked on signing and notarization, owned by
SP-026 and SP-027.
