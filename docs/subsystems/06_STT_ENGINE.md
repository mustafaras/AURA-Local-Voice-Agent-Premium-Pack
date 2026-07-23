> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Streaming Speech-to-Text

## Design
Define an `STTEngine` protocol supporting partials, stable segments, language hypotheses, timestamps, confidence, cancellation, and model health.

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
