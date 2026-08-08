> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Streaming Speech-to-Text

## Design
Define an `STTEngine` protocol supporting partials, stable segments, language hypotheses, timestamps, confidence, cancellation, and model health.

`results` is engine-lifetime, not single-turn. Finalizing one speech session
must preserve the sequence for later Push-to-Talk turns. A final native Speech
callback remains valid after `endAudio()` and is the only result authorized to
enter intent routing; adapter errors are health events, never user utterances.

The AVFoundation tap must copy callback-owned PCM before crossing an async or
actor boundary. Conversion vends that owned input once. Downstream consumers
resolve the retained frame by exact sequence index and submit only that real,
non-empty sample frame to STT; metadata-only placeholder audio is forbidden.

## Engine strategy
- Primary local engine optimized for Apple Silicon.
- Secondary lightweight fallback for degraded mode.
- Models are configurable and benchmarked on Turkish, English, code-switching, application names, and technical vocabulary.
- Maintain a user vocabulary for repository names, contacts, commands, and acronyms.
- Never auto-execute from unstable partial transcripts.
- Intent execution requires stable text or a deterministic early-command rule.

## Accuracy handling
- Preserve alternatives for low-confidence entities.
- Confirm ambiguous destructive targets.
- Use context to rank, not silently rewrite, uncertain transcription.
- Record confidence and evidence in the task plan.

## Benchmarks
Measure word error rate, entity error rate, first-partial latency, stable-segment latency, memory, CPU, and energy.

## R7 implementation boundary

`STTRouter` selects the first local engine that actually starts and records the
selected engine ID, locale, offline capability, and router generation in
health/result metadata. The native Speech adapter checks both recognizer
availability and `supportsOnDeviceRecognition` before setting
`requiresOnDeviceRecognition`; an unsupported locale is not represented as a
ready offline engine. The engine-lifetime result stream remains reusable after
session cancellation, and duplicate result IDs are discarded by
`STTPipeline`.

The current fallback is another Apple on-device locale adapter, not a silently
quality-switching Whisper claim. Live Turkish/English/mixed-language WER and
entity evaluation, a qualified local Whisper/equivalent fallback, microphone
permission acceptance, and release-hardware recovery remain open.
