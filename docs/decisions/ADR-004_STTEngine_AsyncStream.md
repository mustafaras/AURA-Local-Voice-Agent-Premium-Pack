# ADR-004: STTEngine protocol uses AsyncStream with Sendable, non-actor engines

- Status: accepted
- Date: 2025-07-23
- Owners: AURA core team
- Supersedes: —
- Superseded by: —

## Context

The streaming speech-to-text (STT) subsystem must expose:

- partial transcripts that downstream consumers can display or ignore,
- stable segments that the policy engine may authorize for intent execution,
- alternatives and confidence for ranking/n-best handling,
- cancellation so a wake/interruption can stop recognition without leaking audio or results,
- health/status queries for orchestrator routing.

The first concrete engine is a deterministic mock used only for protocol validation. A real Speech.framework adapter will follow, and possibly ONNX/Core ML adapters later. The protocol must not assume a specific runtime or threading model.

## Decision

1. `STTEngine` is a `Sendable` protocol, not an actor.
2. Results are exposed as `var results: AsyncStream<STTTranscriptResult>`.
3. Engine control methods (`start`, `ingest`, `finalizeSession`, `cancel`, `health`) are synchronous except `start`, which is `async throws(AuraError)`.
4. Adapters are responsible for their own internal isolation. The mock uses a recursive lock around mutable state and an `AsyncStream` continuation box so yields can happen from any thread/queue without crossing actor boundaries.
5. `STTTranscriptResult` lives in the `AuraSTT` target (not AuraCore) for this slice because it is consumed by the STT pipeline and intent engine, both of which depend on AuraSTT.

## Alternatives considered

- **Actor-isolated engine**: Simpler state protection, but forces all ingest/yield traffic through the engine's actor serial queue. Real audio callbacks and Speech.framework delegate callbacks arrive on arbitrary queues; marshalling every frame onto an actor would add latency and complicate backpressure. Rejected for the hot path.
- **Callback / delegate API**: Common for Apple frameworks, but mixes control flow with result delivery and makes cancellation harder to compose. Rejected in favor of a single typed stream boundary.
- **Combine publisher**: Would require a dependency on Combine and is less natural for structured concurrency consumers. Rejected.

## Security and privacy impact

- Audio samples never leave the engine boundary as raw data. The protocol only emits `STTTranscriptResult` structs.
- `cancel()` must finish the `AsyncStream` continuation and drop pending audio. The mock uses `onTermination` to transition to `.cancelled`, ensuring no further results can be yielded.
- `STTTranscriptResult` contains no personal memory or secrets.

## Operational impact

- Downstream consumers can subscribe to `results` on a `Task` and break once a stable segment is received, which is the intended gating point for intent execution.
- Health queries are lock-protected and cheap enough for periodic orchestrator checks.
- The recursive lock in the mock prevents deadlock when `cancel()` is triggered re-entrantly by the stream's `onTermination` handler.

## Migration

- No breaking migration; this is a new vertical slice.
- Future real adapters will conform to the same protocol and replace the mock via configuration.

## Validation evidence

- [Tests/AuraSTTTests/AuraSTTEngineTests.swift](../Tests/AuraSTTTests/AuraSTTEngineTests.swift) contains 7 passing tests:
  - partial → stable streaming,
  - cancellation does not leak stable results,
  - health transitions,
  - bilingual deterministic commands,
  - technical vocabulary hints,
  - WER benchmark,
  - entity error rate benchmark.
- [scripts/aura-test.sh](../scripts/aura-test.sh) runs the suite with exit code 0 for `AuraSTTTests`.

## Consequences

- Adapters must be thread-safe internally. The protocol does not serialize calls.
- Consumers must not block the audio thread; they should process `AsyncStream` on a dedicated task.
- The mock's recursive-lock pattern is acceptable for a test double but should not be copied into a real-time audio adapter; real adapters should use queue-based isolation with minimal critical sections.
