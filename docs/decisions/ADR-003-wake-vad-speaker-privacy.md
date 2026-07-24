# ADR-003: Wake-Word, VAD, Speaker Verification, and Privacy Controls

- Status: Accepted
- Date: 2026-07-24
- Owners: Audio Pipeline / Security / Memory and Ledger
- Supersedes: None

## Context

Phase 2 of the AURA build adds wake-word detection, voice-activity detection (VAD), optional speaker verification, privacy-mode controls, and anti-trigger protection. These components sit between the real-time audio tap and downstream intent/speaker systems. They must:

- Run deterministically in unit tests without microphone access or ML model downloads.
- Respect strict Swift 6.4 concurrency isolation.
- Prevent self-trigger from the assistant's own TTS output and from media/conversation in the environment.
- Support a privacy mode that disables all ambient wake-word processing unless explicitly armed by a visible/audible keyboard-shortcut signal.
- Treat speaker verification as an identity hint, never as an authorization grant for high-risk actions.
- Capture measurable false-accept and false-reject rates across acoustic conditions.

## Decision

1. **Layered detection architecture.** The audio tap feeds `AudioFrameEvent` metadata to `WakeWordPipeline`. The pipeline also exposes `ingestSampleFrame(_:)` so deterministic tests can seed the exact sample buffer that synchronous analyzers need. The event carries only sample-count/timestamp metadata; sample buffers are never placed on the event bus to avoid logging ambient audio.
2. **Synchronous analyzers with lock-protected mutable state.** `VoiceActivityDetector` and `WakeWordDetector` expose synchronous `@Sendable` methods. Their deterministic implementations (`EnergyVAD`, `MarkerWakeWordDetector`) hold mutable adaptation state behind an `NSLock` and are marked `nonisolated` or use `nonisolated(unsafe)` state, satisfying the protocol without actor hop latency on the real-time path.
3. **Wake-word abstraction.** `WakeWordDetector` is phrase-aware and confidence-thresholded. The default test implementation uses a marker tone (configurable frequency window) so tests can verify phrase mapping, confidence, debounce, and rejection of off-marker audio without requiring a trained keyword model.
4. **Anti-trigger suppression.** `WakeWordPipeline` tracks an `outputActive` flag and a debounced cooldown window. While output is active or a recent synthetic echo window has not elapsed, wake hypotheses are counted as suppressions and never promoted to activations. This protects against TTS self-trigger and media playback.
5. **Privacy mode with keyboard-shortcut arming.** `WakeWordConfiguration` can require `privacyModeRequiresKeyboardShortcut`. When privacy is enabled the pipeline enters `.privacyArmed`; wake hypotheses are dropped until `privacyShortcutPressed()` is invoked. State transitions emit `PrivacyModeEvent` and UI indicators can observe them.
6. **Speaker verification as identity hint only.** `SpeakerVerifier` returns a `SpeakerVerificationEvent` whose `isAuthorization` field is always `false`. Enrollment stores a deterministic marker-energy profile; verification returns a `score` and optional `profileID`. The pipeline may attach the hint to a `WakeActivationEvent` but never uses it to bypass policy for sensitive actions.
7. **Metrics and acceptance harness.** `WakeWordPipeline` maintains `WakeWordMetrics` (hypotheses, accepted activations, anti-trigger suppressions, false accepts, false rejects). Tests seed synthetic audio under quiet, noise, and intermittent conditions and assert on these counters.

## Alternatives considered

- **Actor-isolated synchronous analyzer methods.** Attempted; the compiler rejects synchronous `@Sendable` protocol requirements implemented by actor-isolated instance methods. We chose nonisolated lock-protected implementations instead.
- **Carrying raw sample arrays inside `AudioFrameEvent`.** Rejected: ambient audio must not transit the event bus or be persisted in logs.
- **Speaker verification authorizing sensitive actions.** Rejected by the security model; speaker identity is a soft signal and must remain subordinate to the policy engine.
- **Embedding an actual on-device wake-word ML model in Phase 2.** Deferred; the abstraction is ready, but the model asset, inference latency budget, and anti-spoof checks are Phase 3 work.

## Security and privacy impact

- Ambient audio samples are never emitted on the event bus; only de-identified metadata and lifecycle events propagate.
- Privacy mode blocks wake-word processing by default until an explicit keyboard shortcut is pressed, satisfying the "visible/audible indicator" requirement.
- Speaker verification cannot authorize actions; it only provides a hint attached to the activation event.
- Anti-trigger suppression prevents accidental activation during assistant speech or media playback, reducing false-accept risk.

## Operational impact

- `ingestSampleFrame(_:)` is intended for tests and internal tap wiring; callers must keep it off the hot real-time thread for anything heavier than the analyzer.
- The deterministic marker implementation is adequate for CI but must be swapped for a real wake-word model before release.
- Metrics counters are in-memory and reset on pipeline restart; long-term aggregation belongs to the observability subsystem.

## Migration

No migration required; this is the first wake/VAD subsystem implementation.

## Validation evidence

- `swift build --build-path /tmp/aurabuild` passes for all targets.
- `AuraAudioTests/WakeWordPipelineTests` passes 6/6, covering VAD, wake detection, anti-trigger suppression, privacy-mode arming, speaker verification, and wake/metrics acceptance.
- Full test execution via `scripts/aura-test.sh` verified after ADR creation.

## Consequences

- Real wake-word model integration must conform to the `WakeWordDetector` protocol and preserve the synchronous `@Sendable` contract.
- The separation between `AudioFrameEvent` metadata and `ingestSampleFrame(_:)` samples must be maintained; future designers must not put raw audio on the bus.
- False-accept/false-reject harness currently measures the deterministic marker detector; swap to real model metrics when the model arrives.
