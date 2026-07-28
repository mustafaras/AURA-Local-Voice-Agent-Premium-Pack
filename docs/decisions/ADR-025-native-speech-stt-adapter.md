# ADR-025: Native Speech.framework STT adapter with on-device recognition

- Status: accepted
- Date: 2026-08-05
- Owners: AURA core team
- Supersedes: —
- Superseded by: —

## Context

Phase 03 of the AURA roadmap adds a real streaming speech-to-text (STT) engine to complement the deterministic mock used for protocol validation and intent-layer tests. The chosen runtime must satisfy the project's priority order: Safety → Correctness → Recoverability → Latency → Convenience.

Key requirements:

- Audio and models must stay on-device (privacy-first default).
- The engine must conform to the existing `STTEngine` protocol and integrate with `STTPipeline` without changing the audio or intent contracts.
- It must expose partial results for responsiveness, stable segments for intent execution, alternatives/confidence for ranking, and cancellation for wake/interruption.
- It must be usable on macOS 27+ Apple Silicon with the toolchain available in this workspace (CommandLineTools only, no XCTest runtime via `swift test`).
- It must fail closed when permissions or availability checks fail.

## Decision

1. Introduce a `SystemSTTEngine` adapter in `Sources/AuraSTT/SystemSTTEngine.swift` that wraps `SFSpeechRecognizer` and `SFSpeechAudioBufferRecognitionRequest` from `Speech.framework`.
2. Force on-device recognition by setting `request.requiresOnDeviceRecognition = true`.
3. Enable partial results via `request.shouldReportPartialResults = true`.
4. Keep the `STTEngine` protocol's control methods (`start`, `ingest`, `finalizeSession`, `cancel`, `health`) and `results` stream shape unchanged.
5. Change `start()` from the previously typed `throws(AuraError)` to plain `throws` because `Task { @MainActor }.value` in Swift 6 surfaces `any Error`, which cannot be cleanly rethrown through a typed error signature.
6. Use `NSRecursiveLock` with a synchronous `withLock` helper for internal state, matching the isolation pattern already proven in the mock engine.
7. Wrap the synchronous `SFSpeechRecognizer.requestAuthorization` and recognition task setup in `Task { @MainActor }` because `Speech.framework` authorization and task creation must occur on the main actor.
8. Map `SFSpeechRecognitionResult` to `STTTranscriptResult` by taking `result.bestTranscription` as the primary transcript and `result.transcriptions.dropFirst()` as alternatives.
9. Convert `SFTranscriptionSegment.confidence` (a `Float`) to `Double` explicitly to match the protocol schema.
10. Add `NSSpeechRecognitionUsageDescription` to `Resources/AURA-Info.plist` so the permission dialog has a user-visible purpose string.
11. Wire `SystemSTTEngine` into `AuraKernel.makeSTTEngine(configuration:vocabulary:)` with engineID `native-speech`; keep `mock-stt` as a deterministic fallback for tests and unknown engineIDs.

## Alternatives considered

- **Whisper.cpp / Core ML adapter**: Would give a fully local neural STT path but introduces a third-party dependency, model weight distribution, and build complexity not justified for the current vertical slice. Deferred to a future ADR.
- **Keep only the mock STT engine**: The intent layer can be tested, but AURA cannot perform real speech recognition on-device. Rejected because real STT is required for a usable voice agent.
- **Typed throws `AuraError` in `start()`**: Reinstated after the mock was written, but Swift 6 `Task.value` returns `any Error`, which cannot be propagated as `AuraError` without manual rethrowing. Plain `throws` preserves the protocol's ergonomic conformance and still allows adapters to emit `AuraError` instances.

## Security and privacy impact

- `requiresOnDeviceRecognition = true` prevents audio from leaving the device for server-side transcription unless explicitly overridden by a future configuration.
- No audio samples, transcripts, or confidence values are logged, persisted, or transmitted by the adapter.
- Permission is requested through `SFSpeechRecognizer.requestAuthorization` before creating a recognition request; unauthorized or restricted status throws `AuraError.permissionDenied` so the caller cannot silently bypass the permission model.
- `cancel()` ends audio, cancels the recognition task, and finishes the `AsyncStream` continuation exactly once, preventing audio or result leakage after interruption.

## Operational impact

- `AuraKernel` can now select `native-speech` at composition time; the default remains `mock-stt` unless the configuration explicitly opts into native speech.
- The first real STT session triggers a one-time system speech-recognition permission prompt.
- `SFSpeechRecognizer` availability and authorization status are checked at `start()` time; failures surface as `AuraError` for orchestrator routing.
- The adapter's internal lock and MainActor-wrapped task keep the hot audio ingestion path synchronous and non-allocating (only buffer append), while Speech.framework callbacks are marshalled onto the stream continuation.

## Migration

- No breaking changes to `STTPipeline`, `AuraEventBus`, or intent consumers.
- Existing deterministic tests remain valid because `mock-stt` continues to be wired as a fallback.
- `DeterministicMockSTTEngine` and `RecordingSTTEngine` were updated to the plain `throws` `start()` signature.
- `AuraKernel.sttPipeline.start()` error mapping was updated to catch any `Error` and wrap it as `AuraError.sttEngineError`.

## Validation evidence

- `Sources/AuraSTT/SystemSTTEngine.swift` compiles cleanly for `AuraSTT` and `AURA` targets.
- `swift build --target AURA` passes with only non-critical CommandLineTools search-path warnings.
- `Tests/AuraSTTTests/SystemSTTEngineTests.swift` contains 7 passing tests:
  - `health is idle before start`
  - `start returns not authorized when speech recognition is not denied`
  - `cancel moves health to cancelled without crashing`
  - `stream terminates after cancel`
  - `ingest before start is safe when recognizer is unavailable`
  - `vocabulary hints are accepted without crashing`
  - `engineID and locale are exposed correctly`
- `Tests/AuraSTTTests/AuraSTTEngineTests.swift` contains 7 passing tests for the mock engine and benchmarks.
- `./scripts/aura-test.sh /tmp/aurabuild-stt AuraSTTTests` reports 14/14 passing tests across both suites.
- `./scripts/aura-test.sh /tmp/aurabuild-stt AURAIntegrationTests` reports 7/7 passing tests after integration wiring.

## Consequences

- The adapter is a thin, fail-closed boundary over `Speech.framework`. It does not implement its own acoustic model, so recognition quality and language coverage depend entirely on Apple's on-device models.
- Tests that depend on `SFSpeechRecognizer.authorizationStatus()` are written to remain deterministic in any authorization state; they assert invariants rather than requiring a specific status.
- `Speech.framework` callbacks are not strongly typed to `MainActor` in all SDK versions; the `Task { @MainActor }` wrapper provides a stable, serial context for authorization and task creation but adds a small hop.
- The `Float` → `Double` confidence conversion is explicit, avoiding subtle precision drift in downstream confidence thresholds.
