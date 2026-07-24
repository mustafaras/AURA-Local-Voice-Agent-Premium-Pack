# ADR-005 — Conversation State Machine, Turn-Taking, and TTS Scheduling

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-07-25 |
| **Author** | GitHub Copilot |
| **Supersedes** | — |

## Context

Phase 4 of the AURA implementation roadmap required a conversation coordinator that owns the canonical turn state, schedules TTS, handles interruptions (barge-in), enforces timeouts, and supports deterministic voice commands. The component sits between streaming STT, the intent/policy engine, and the TTS adapter. It must be testable without live audio or a real synthesizer, and it must respect the project's safety/privacy ordering (Safety → Correctness → Recoverability → Latency → Convenience).

## Decision

1. **Actor-isolated state machine.** `Conversation` is a Swift `actor` with a single canonical `state: ConversationState`. All state transitions happen through `transition(to:reason:)`, which is synchronous and emits a typed `ConversationStateEvent`. Actor isolation removes data races on state, queue, timeout task, and turn text.

2. **Nonisolated event emission.** `emit(_:)` is `private nonisolated` and creates an `EventEnvelope` synchronously, then spawns a `Task` to push it onto the event bus. This lets event construction happen on the actor without hopping, while bus I/O remains async and non-blocking.

3. **TTS scheduling via a serial queue.** The `Conversation` actor maintains `[TTSPrompt]`. The first prompt is the active one; the rest are pending. `scheduleNextSpeech()` removes the first prompt, starts an unstructured `Task` that consumes `TTSEngine.speak(_:)` `AsyncStream<TTSChunk>`, and finally calls `onSpeechFinished()`. The active task is tracked with `activeSpeechTask` and cancelled on barge-in or deterministic stop.

4. **Barge-in coherency flag.** Barge-in is handled by capturing the current state, emitting `BargeInEvent(atState:)`, setting `bargeInStopping = true`, cancelling the active TTS task, clearing the queue, and transitioning to `.listening`. The `onSpeechFinished()` path checks `bargeInStopping` and returns early so the cancelled TTS task cannot race back to `.idle` or schedule the next queued prompt. The flag is cleared after the transition.

5. **Barge-in grace window.** `bargeInGraceUntil` records when the grace window expires. Repeated `bargeInDetected` calls inside the window are ignored. Grace duration is read from `ConversationConfiguration.bargeInGraceMilliseconds`.

6. **Semantic turn completion.** A stable STT segment ends the listening turn, moves state to `.thinking`, emits `TurnCompletedEvent`, and schedules a thinking timeout. A deterministic command in the segment bypasses policy review (`requiresPolicyReview: false`) and is handled before the turn-completed path.

7. **Deterministic voice commands.** `ConversationConfiguration` carries `deterministicStopCommands` and `deterministicPauseResumeCommands`. Stop clears the queue and TTS and returns to `.idle`; pause/resume toggles `pauseSpeaking()`/`resumeSpeaking()` on the current engine.

8. **Timeouts per state.** Listening, thinking, and speaking each have their own timeout. `scheduleTimeout` creates an unstructured `Task`; `cancelTimeout` cancels it. If a timeout fires, the actor checks that state matches the target before emitting `ConversationTimeoutEvent` and moving to `.timeout`.

9. **Task-shared mutable state via `SentValueBox<T>`.** Inside `runSpeechStream`, a `SentValueBox<Bool>` tracks whether the speech timeout fired, avoiding mutable captured state in nested `Task` closures and satisfying Swift 6 region-isolation checks.

10. **Mock TTS deterministic synthesis.** `MockTTSEngine` in `AuraAudio` splits the response text into short word fragments, yields `TTSChunk` values with a deterministic duration, and can be cancelled mid-stream. It uses `NSLock.withLock { }` for async-safe mutable state access and clears the current prompt inside the detached synthesis task so `stopSpeaking()` removes the active prompt immediately.

11. **Configuration decode tolerates partial JSON.** `AuraConfiguration` and all nested structs (`AppConfiguration`, `AudioConfiguration`, `STTConfiguration`, `TTSConfiguration`, `ConversationConfiguration`, `WakeWordConfiguration`, `PrivacyConfiguration`, `LoggingConfiguration`) implement custom `init(from decoder:)` with `decodeIfPresent` so missing keys fall back to struct defaults. This fixes a Swift synthesized-Codable limitation discovered when `configurationLoadingMergesDefaults()` loaded `{"audio":{"sampleRate":48000}}`.

## Consequences

- **Positive:** The conversation actor is strictly isolated, fully testable with the mock engine, and emits typed events for every state change and TTS milestone. Barge-in and deterministic stop are race-free in unit tests. Partial configuration overrides merge reliably with defaults.
- **Negative:** `Conversation` does not yet integrate with a real wake pipeline, intent engine, or policy engine; it consumes typed events and will need to be wired into the orchestrator in a later phase. The mock TTS engine is not real-time safe and must be replaced or wrapped for production audio output.
- **Risk:** Unstructured `Task` boundaries inside an actor can still hide ordering bugs; the barge-in flag is a targeted fix. Longer term, explicit structured concurrency (e.g., a child task tree) should be considered for timeout and TTS management.

## Related

- `prompts/implementation/04_04_CONVERSATION.prompt.md`
- `docs/subsystems/07_TURN_TAKING_AND_TTS.md`
- `docs/subsystems/08_INTENT_ENGINE.md`
- `docs/persona/AURA_VOICE_AND_BEHAVIOR.md`
- `Sources/AuraAgent/Conversation.swift`
- `Tests/AuraAgentTests/ConversationTests.swift`
- `Sources/AuraAudio/MockTTSEngine.swift`
- `Sources/AuraCore/TTSEngine.swift`
- `Sources/AuraCore/AuraConfiguration.swift`
