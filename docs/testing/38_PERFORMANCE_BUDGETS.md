> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Performance and Resource Budgets

This document records the performance and resource budgets AURA commits to, how each budget is measured, and the current evidence status. Budgets are benchmark-derived on the target Mac profile and enforced by deterministic mock-engine tests in CI. Real-device rows are marked **TBD** until measured on Apple Silicon hardware with acoustic STT/TTS/wake-word models.

## Latency budgets

| Budget | Kind | Target | Measurement | Current evidence |
|---|---|---|---|---|
| Wake-to-acknowledgement | Latency | ≤ 0.50 s | Time from `WakeActivationEvent` to `ResponsePlanEvent` receipt in `Conversation` | **Mock engine:** `ConversationTests.wakeToAckLatencyMeasured` verifies 0.200 s on deterministic clock; real device **TBD** |
| Simple-command completion | Latency | ≤ 1.50 s | Time from `WakeActivationEvent` to `LatencyMeasuredEvent(.simpleCommandCompletion)` emitted from `Conversation` | **Mock engine:** `ConversationTests.simpleCommandCompletionLatencyMeasured` verifies spoken completion under deterministic clock; `AURAIntegrationTests.endToEndPipelineCompletesSimpleCommandUnderBudget` verifies "activate safari" path stays under 1.5 s on mock engines; real device **TBD** |
| First stable transcript | Latency | TBD | Time from end-of-utterance to first `STTStableSegmentEvent` | **Not yet measured.** Pending real STT integration. |
| TTS first audio | Latency | TBD | Time from `ResponsePlanEvent(hasSpokenResponse:true)` to first audio frame delivered | **Not yet measured.** `MockTTSEngine` drains synchronously in tests; real audio output path TBD. |
| Memory lookup | Latency | TBD | Time from memory query event to `MemoryQueryCompletedEvent` | **Not yet measured.** Memory subsystem exists but no budget tests. |
| Application activation | Latency | TBD | Time from `.appActivate` intent execution to `ApplicationActivatedEvent` | **Not yet measured.** Tool router path exists; budget test deferred. |

## Resource budgets

| Budget | Mode | Target | Measurement | Current evidence |
|---|---|---|---|---|
| CPU in passive mode | Idle listening | TBD | Average % CPU while wake-word detector is active, no user interaction | **Not yet measured.** `MarkerWakeWordDetector` is deterministic and lightweight; real on-device model TBD. |
| Memory in passive mode | Idle listening | TBD | Resident set size while agent is idle | **Not yet measured.** |
| Memory in active mode | During command | TBD | Peak resident set size during a simple command | **Not yet measured.** |
| Energy impact | Passive + active | TBD | `NSProcessInfo.thermalState` / `powermetrics`-derived energy estimate | **Not yet measured.** |
| Thermal throttling behavior | Passive + active | TBD | No thermal throttling under sustained 5-minute simple-command load | **Not yet measured.** |

## Measurement methodology

1. All latency budgets are derived from `LatencyMeasuredEvent` payloads emitted by `Conversation` and aggregated by `PerformanceSampler` in `AuraCore`.
2. Mock-engine tests use an injected `monotonicClock` closure so measurements are deterministic and independent of machine load.
3. `LatencyMeasuredEvent.isMockEngine` is set to `true` whenever a deterministic or mock engine is on the data path, so CI can separate mock-engine evidence from real-device evidence.
4. Real-device measurements will be captured by the same event pipeline but with `isMockEngine == false`, and will be added to this document as rows move from **TBD** to benchmark-backed values.
5. CI blocks material degradation: any merge that increases a mock-engine median by ≥ 10 % or crosses a budget line fails the release gate.

## Release gate

The Phase 20 release gate requires:
- Median wake-to-acknowledgement latency below 0.50 s.
- Median simple-command completion below 1.50 s when no remote model is required.
- Energy budget met (TBD on real device).
- No release performed without explicit authorization.

The mock-engine budget rows above satisfy the first two gate conditions in CI. The remaining rows remain honestly documented as **TBD** pending real-device benchmarking.
