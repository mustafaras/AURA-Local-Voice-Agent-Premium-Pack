# ADR-023 — Release Readiness: Latency Instrumentation and Deterministic Budgets

## Status
Accepted

## Context
Phase 20 — Release Readiness requires measurable evidence for the master-spec acceptance gates:

- Median wake-to-acknowledgement latency below 500 ms.
- Median simple-command completion below 1.5 s when no remote model is required.
- Energy budget met.
- No release performed without explicit authorization.

The codebase currently ships only deterministic/mock speech engines:

- `MarkerWakeWordDetector` fires on a synthetic 1 kHz marker tone.
- `DeterministicMockSTTEngine` emits scripted transcripts after a fixed frame delay.
- `MockTTSEngine` emits progress markers with 1 ms per word.

Real on-device wake-word, STT, and TTS models are not yet integrated. Real Accessibility and Screen Recording permission behavior cannot be validated in the sandboxed/CommandLineTools environment. App-bundle codesign uses the local stable identity + hardened runtime; Developer ID signing and `notarytool` notarization are permanently out of scope for the local-only product (ADR-049).

Therefore Phase 20 must be split into **instrumentation + deterministic budget** work that can be verified now, and **packaging/signing/release** work that remains design-only until the real engines and signing credentials are available.

## Decision

1. Add a deterministic, end-to-end wake-to-acknowledgement latency measurement in `Conversation`, exposed via a new `LatencyMeasuredEvent` on the event bus.
2. Add a small `PerformanceSampler` / `HealthAggregator` actor in `AuraCore` that subscribes to existing metrics events and produces a `SystemHealthSnapshot`.
3. Add Swift Testing integration tests that drive the deterministic pipeline and assert the mock-engine median wake-to-ack latency is below 500 ms and simple-command completion is below 1.5 s. The tests, budget doc, and ledger must all label the result as **mock-engine only**.
4. Add one clean-install permission test for the Accessibility denied path using the existing `AccessibilityHealth` actor.
5. Leave app-bundle packaging, codesign, notarization, and the update mechanism as **design + scripts + documentation** in this slice. No release is performed.

## Consequences

- We gain a reproducible regression guard for control-path latency.
- The acceptance gate can be exercised in CI against the deterministic pipeline.
- The documented budget is honest about its mock-engine origin and explicitly blocks real-world release claims until real engines are integrated.
- No real microphone, TTS, or permission UX is exercised, so onboarding/recovery tests remain limited to event-level assertions.

## Implementation Notes

- The latency event must use the same `monotonicClock` injected into `WakeWordPipeline`, `STTPipeline`, and `Conversation`.
- `Conversation.wakeActivationStarted(privacyMode:)` records `wakeStartTime`.
- `Conversation.responsePlanReceived(_:)` computes `wakeToAckLatencySeconds` when the first plan with a spoken response is received.
- `Conversation.onSpeechFinished()` computes `simpleCommandCompletionLatencySeconds` for a completed deterministic command turn.
- `AuraKernel` subscribes `PerformanceSampler` to the event bus before starting audio.
- `PerformanceSampler` consumes `LatencyMeasuredEvent`, `WakeWordMetricsEvent`, `STTPipeline.Metrics`, and `OllamaHealthCheckEvent` and exposes median/worst values.
- The budget document fills only the mock-engine-derived row; real-device rows are left as TBD with explicit gate conditions.

## Rejected Alternatives

- **Claim the 500 ms / 1.5 s gates against mock engines as real-world proof** — rejected because it violates the project contract to never fabricate test results or misrepresent product state.
- **Add real codesign/notarization now** — rejected because the toolchain lacks Developer ID / `notarytool`; the work is captured as design-only.
- **Add cloud-based telemetry for regression storage** — rejected because it conflicts with the privacy-first, local-first posture.

## Related Documents

- [docs/testing/38_PERFORMANCE_BUDGETS.md](../testing/38_PERFORMANCE_BUDGETS.md)
- [docs/operations/35_RELEASE_CHECKLIST.md](../operations/35_RELEASE_CHECKLIST.md)
- [docs/operations/33_DEPLOYMENT.md](../operations/33_DEPLOYMENT.md)
- [docs/decisions/ADR-003-wake-vad-speaker-privacy.md](ADR-003-wake-vad-speaker-privacy.md)
- [docs/decisions/ADR-014-ollama-adapter.md](ADR-014-ollama-adapter.md)
- [docs/decisions/ADR-020-security-hardening.md](ADR-020-security-hardening.md)
- [docs/decisions/ADR-022-composition-root-wiring.md](ADR-022-composition-root-wiring.md)
