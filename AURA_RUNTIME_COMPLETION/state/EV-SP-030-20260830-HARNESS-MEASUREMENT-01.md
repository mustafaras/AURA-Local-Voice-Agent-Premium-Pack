# EV-SP-030-20260830-HARNESS-MEASUREMENT-01

**Evidence ID:** EV-SP-030-20260830-HARNESS-MEASUREMENT-01
**Track:** SP-030 / R12 / OPEN-13
**Type:** Measurement (class: `deterministic_harness`) — partial SLO and scenario-matrix results
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty with SP-030 changes)
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6
**Command:** `./scripts/aura-test.sh /tmp/aurabuild`
**Session:** AURA-SP-030-BETA-EVIDENCE-20260830
**Authority:** Release owner, present, directed measuring the measurable portion.

> **Scope limitation, stated first.** Everything here is `deterministic_harness`
> class. **No live user-present beta window was run. No live microphone was used.
> No telemetry was enabled or transmitted.** These results do not close SP-030's
> completion gate and are not presented as a live beta sample; the contract
> mechanically rejects any attempt to relabel them as one.

## Run result

`./scripts/aura-test.sh /tmp/aurabuild` (with `AuraLifecycleTests` restored to the
runner — see `EV-SP-030-20260830-CONTRACT-MEASURED-MODE-01`):

**1290 tests across 80 suites in 22 bundles — 0 failures. `Done. Failed bundles: 0`.**

Per-bundle: AuraCoreTests 72, AuraStoreTests 10, AURAIntegrationTests 89,
AuraAudioTests 39, AuraAutomationTests 41, AuraAgentTests 238, AuraSTTTests 19,
AuraPolicyTests 39, AuraShellTests 24, AuraComputerUseTests 104, AuraSecurityTests 44,
AuraPluginsTests 44, AuraIntentTests 153, AuraConfigTests 17, AuraVSCodeTests 47,
AuraTasksTests 16, AuraMemoryTests 30, AuraContextTests 37, AuraScreenTests 36,
AuraAdversarialTests 68, AuraProductivityTests 75, AuraLifecycleTests 48.

## SLOs measured (2 of 5)

| SLO | Result | Sample | Basis |
|---|---|---|---|
| `false_success` | **0.0** (0 of 9) | 9 cases, declared minimum 5 | `SP014LiveAcceptanceTests` (5) + `SP016BilingualFailClosedTests` (4) — cases that assert a claimed success matches observed reality |
| `unauthorized_action` | **0** | 255 cases, declared minimum 50 | `AuraAdversarialTests` (68) + `AuraPolicyTests` (39) + `AuraComputerUseTests` (104) + `AuraSecurityTests` (44) |

`false_success` is recorded as a single aggregate proportion. Its declared
percentiles were removed because p50/p95/p99 of a rate are undefined for one
harness run; per-session percentiles require a live multi-session beta window and
are **not** claimed.

## SLOs NOT measured (3 of 5) — genuinely require a live window

`ptt_ack` (push-to-talk acknowledgement), `stt_partial` (first STT partial), and
`dialogue_first_token` (local dialogue first token) all remain `not_measured`.
They need a user-present session with a live microphone and a running local model.
No accommodation substitutes for them, and none was invented.

## Scenario matrix — passed as harness coverage only

All five scenarios pass in the deterministic harness. **None has been exercised in
a live beta window**, which is recorded in each entry's `limitations`.

| Scenario | Covering tests |
|---|---|
| `turkish_english_mixed` | `SP003LiveBilingualDialogueScenarios`, `SP016BilingualFailClosedTests`, `TurnCompletionHeuristicsTests` |
| `permission_denial_revocation` | `SP006LiveCapabilityScenarios`, `AuraPolicyTests` revocation cases |
| `offline_backend_unavailable` | `AgentBackendHealthTests`, `RuntimeHealthTests`, `SP014LiveAcceptanceTests` P3 |
| `task_helper_crash_recovery` | `HelperIPCAdversarialTests`, `SP016DeviceRecoveryTests`, `AuraLifecycleTests` SafeMode/LifecycleObserver |
| `injection_emergency_stop_accessibility` | `PromptInjectionAdversarialTests` (19), `EmergencyStopControllerTests` (4), `AuraAccessibilityIdentifierTests` |

## Cohort, consent, telemetry

- **Cohort:** `enrolled`, `internal_local_single_participant`, 1 participant — the
  release owner, whose consent is recorded at `EV-SP-030-20260830-OWNER-APPROVAL-03`.
  No beta session has yet been collected from that cohort.
- **Telemetry:** authority to activate exists and is recorded, but the engine was
  **not switched on**. `telemetry.enabled` stays `false` because these numbers came
  from the test harness, not from telemetry. `transport` remains `none`.

## What remains open (unchanged by this record)

1. Live latency SLOs — need a user-present window with a live microphone.
2. Live STT/WER — needs a speech-capable operator.
3. A live-window run of the scenario matrix.
4. The incident review — no beta window has produced incidents to review.
5. **All five independent sign-offs.** An independent sign-off requires a named
   non-implementing evaluator. Owner authority cannot substitute for independence,
   and the contract now enforces that mechanically.
6. R11 completion and ADR-047 (SP-031).

## Falsifiers

Any claim that a live beta window ran, that a live microphone or live STT/WER
result was obtained, that telemetry was enabled or transmitted, that the incident
review completed, that any sign-off was obtained, that `beta-readiness.json` left
`blocked`, or that SP-030's completion gate is met, would falsify this record.

## Acceptance verdict

**SP-030 remains `in_progress`.** Two of five SLOs and the scenario matrix now carry
real, provenance-bound harness results where previously nothing was recordable at
all. The completion gate is **not** met. **SP-031 must NOT start.**
