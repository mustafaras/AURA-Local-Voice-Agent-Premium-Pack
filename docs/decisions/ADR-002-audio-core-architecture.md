# ADR-002: Audio Core Architecture

- Status: Accepted
- Date: 2026-07-24
- Owners: Audio Pipeline / macOS Systems Engineering
- Supersedes: None

## Context

Phase 1 of the AURA build implements the real-time audio capture path. The system must ingest microphone audio on macOS, normalize it to a mono 16 kHz float stream for wake-word and streaming STT processing, and expose short-term pre-roll context while preserving privacy. The implementation must compile under Swift 6.4 with strict concurrency and target macOS 27.

Key constraints discovered during implementation:

- The deprecated `installTap(onBus:bufferSize:format:block:)` has been replaced on macOS 27 by a throwing `installAudioTap(onBus:bufferSize:format:tapProvider:)` that vends an `AVReadOnlyAudioPCMBuffer`.
- `AVReadOnlyAudioPCMBuffer` is `Sendable` but is not a subclass of `AVAudioBuffer`, so it cannot be returned directly from `AVAudioConverter.convert(to:error:withInputFromBlock:)`.
- `AVAudioSession` is unavailable on macOS; device/route change recovery must use `AVAudioEngineConfigurationChange` notifications instead.
- The real-time tap queue must not perform allocation, model loading, disk I/O, or blocking calls.

## Decision

1. Use `AVAudioEngine.inputNode.installAudioTap(...)` as the modern capture API.
2. Copy the `AVReadOnlyAudioPCMBuffer` into a mutable `AVAudioPCMBuffer` via the new `AVAudioPCMBuffer(copying:)` initializer before handing it to `AVAudioConverter`. The copy is created once per tap callback and is not retained beyond the conversion call.
3. Convert to the target format with `AVAudioConverter` and then copy the converted samples into an `AudioFrame` value for the event bus and ring buffer.
4. Implement `AudioRingBuffer` as an `NSLock`-protected circular buffer of immutable `AudioFrame` values. Mark it `@unchecked Sendable` because all mutable state is guarded by the lock.
5. Listen for `AVAudioEngineConfigurationChange` and, if capture was active, restart the engine after a short debounce using an isolated actor task.
6. Emit typed lifecycle, frame, error, and privacy-indicator events through the existing `EventEnvelope` system.
7. Default privacy controls disable diagnostic retention and require an explicit opt-in plus an encryption flag.

## Alternatives considered

- **Manual sample-rate/channel conversion.** Rejected: `AVAudioConverter` is the supported framework primitive and keeps the code aligned with future hardware format changes.
- **Using the deprecated `installTap(onBus:bufferSize:format:block:)`.** Rejected: it is deprecated in macOS 27 and emits warnings; the modern API provides `Sendable` buffers and a throwing contract.
- **Returning `AVReadOnlyAudioPCMBuffer` to `AVAudioConverter`.** Attempted; rejected because the type is unrelated to `AVAudioBuffer` and the compiler rejects it.
- **Persisting raw ring buffer audio to disk by default.** Rejected: violates the privacy-first default of zero ambient-audio retention.

## Security and privacy impact

- No ambient audio is retained unless `PrivacyControls.enableDiagnosticCapture` is explicitly set to `true`.
- Diagnostic retention duration is bounded by `diagnosticRetentionHours` and an encryption expectation flag is stored alongside.
- A visible indicator event is emitted so that downstream UI can show when capture is active.
- Capture buffers are copied locally and never forwarded to network services or model prompts in this subsystem.

## Operational impact

- The tap callback still performs a buffer copy and conversion; this is acceptable for the primary 16 kHz mono target but must be budgeted in the 38_PERFORMANCE_BUDGETS latency envelope.
- Device-change recovery is best-effort and logged; it does not yet guarantee gap-free capture across route changes.

## Migration

No migration required; this is the first audio subsystem implementation.

## Validation evidence

- `swift build --build-path /tmp/aurabuild` passes for all targets.
- `AuraAudioTests` compiles and covers ring buffer behavior, frame immutability, state transitions, privacy controls, and start-idempotency without requiring a microphone.
- Full test execution via `scripts/aura-test.sh` to be verified after ADR creation.

## Consequences

- Future optimization may avoid the extra copy if AVFoundation introduces a converter API that accepts read-only input directly.
- Ring buffer capacity is configured in seconds and frames; very long pre-roll windows increase memory usage linearly.
- Route-change restart logic may need refinement once multi-device (Aggregate, Bluetooth headset) scenarios are tested.
