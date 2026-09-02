# EV-SP-030-20260902-UNATTENDED-ALTERNATE-01

**Evidence ID:** `EV-SP-030-20260902-UNATTENDED-ALTERNATE-01`
**Track:** SP-030 / OPEN-13 — unattended alternative verification attempt
**Session:** `AURA-SP-030-UNATTENDED-ALTERNATE-20260902`
**Timestamp:** 2026-09-02, 09:02 UTC / 12:02 Europe/Istanbul
**Branch / source:** `main`, `HEAD e2e2c6ef924a9150e59c86eb78757a160a129e01`; product source unchanged from verified source `0bafc4f249968d6b620b181ff4ffd3da1d13b71e`
**Evidence class:** `deterministic_harness` plus a failed opt-in `synthetic_speech` attempt; not live-beta evidence

## Objective and authority

Try to close as much of SP-030 as possible without the user present, using
existing production-oriented tests and the repository's approved synthetic
speech path. No TCC/permission mutation, microphone access, telemetry
activation, provider account, signing, release, deployment, or source change
was authorized or performed.

## Procedures and results

| Command | Result | Boundary |
|---|---|---|
| `./scripts/aura-test.sh /tmp/aura-sp030-alt-lifecycle-20260902 AuraLifecycleTests` | **48 tests / 10 suites, 0 failures** | Lifecycle/recovery/migration/safe-mode/export contracts under deterministic test fixtures; not a live app lifecycle run. |
| `./scripts/aura-test.sh /tmp/aura-sp030-alt-integration-20260902 AURAIntegrationTests` | **111 tests / 22 suites, 0 failures** | Product composition, confirmation, emergency-stop and PTT measurement seam; no real microphone or owner-present UI acceptance. |
| `./scripts/aura-test.sh /tmp/aura-sp030-alt-stt-20260902 AuraSTTTests` | **19 tests / 4 suites, 0 failures** | STT router/mock and fail-closed behavior; live synthetic speech tests remain opt-in. |
| `AURA_ENABLE_LIVE_SPEECH_TESTS=1 AURA_TEST_TIMEOUT_SECONDS=90 ./scripts/aura-test.sh /tmp/aura-sp030-alt-synthetic-20260902 AuraSTTTests` | **Failed closed: 3 synthetic speech tests raised `speechNotAuthorized`; no permission prompt was requested** | The tests synthesize audio with `say` and feed a real recognizer, but the test host had no Speech Recognition authorization. No TCC mutation was attempted. |

The failed opt-in tests were `Turkish synthesized speech is recognized by the
real recognizer`, `English synthesized speech is recognized by the real
recognizer`, and `Engine locale selects the recognition language`. The existing
synthetic suite measures final recognition/locale behavior, not AURA's
`stt_partial` first-partial latency metric and not real microphone behavior.

## Cognitive gate

- **Symptom:** deterministic lifecycle, integration, and STT contract paths pass; the userless real-recognizer path cannot start because the bundled test host lacks Speech Recognition authorization.
- **Mechanism / root cause:** the current userless route is either a deterministic fixture or an opt-in synthetic recognizer host. The latter is protected by TCC and cannot request/approve permission under the present no-mutation boundary.
- **Direct change / procedure:** no product source change. Three deterministic suites passed; the opt-in synthetic run failed closed without mutating permission state.
- **Evidence class:** deterministic harness for the passing suites; attempted `synthetic_speech` path for the authorization failure. This record cannot claim a live-beta sample.
- **Falsifier:** a pre-authorized bundled synthetic host produces a complete, timestamped first-partial sample set, or a user-present live microphone run supplies qualifying samples. Even then, synthetic evidence remains distinct from live-user evidence.
- **Residual risk:** `ptt_ack` and `stt_partial` have no qualifying live-beta samples; the full in-app dialogue first-token metric remains unmeasured; R11 live recovery, live scenario execution, and incident review remain open. Existing deterministic results do not close those gates.
- **Acceptance verdict:** SP-030 remains **blocked**. `beta-readiness.json` remains blocked and SP-031 must not start.

**Next safe action:** either obtain a user-present window for the remaining live
R11/SLO/scenario gates, or separately authorize a pre-approved bundled
synthetic speech host and define a provenance-bound first-partial measurement;
do not relabel either path as `live_user_present`.
