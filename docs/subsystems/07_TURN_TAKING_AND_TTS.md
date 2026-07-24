> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Turn Taking, Interruption, and Text-to-Speech

## Turn-taking
- Use VAD plus semantic completion heuristics.
- Do not wait for long fixed silence after obvious commands.
- Do not cut off reflective speech during planning.
- Allow follow-up utterances to attach to the active session.

## Barge-in
- Authorized user speech immediately attenuates and cancels queued TTS.
- Preserve the unspoken response in session state.
- Resume only when context makes it useful.

## TTS abstraction

The `TTSEngine` protocol is a `Sendable` adapter boundary. It accepts text fragments with optional prosodic hints and streams audio buffers to the audio output path. Concrete adapters are loaded in priority order:

1. **Primary:** Chatterbox TTS — preferred for natural prosody and explicit expressive control (rate, pitch range, emphasis).
2. **Experimental:** Dia TTS — used for advanced non-verbal expression and emotional range when available and user-enabled.
3. **Fallback:** macOS system speech synthesizer (`AVSpeechSynthesisProvider` / `AVSpeechSynthesizer`) — always available, no external dependency.

All adapters must:
- Expose `speak(_: TTSPrompt) -> AsyncStream<TTSChunk>`.
- Honor immediate `stop()`/`pause()`/`resume()` calls without audio leakage.
- Report synthesis errors as typed `AuraError.ttsAdapterFailed` events.
- Never send transcript text off-device unless an explicitly opted-in remote adapter is selected.

## Voice persona

AURA's spoken persona is defined in `persona/AURA_VOICE_AND_BEHAVIOR.md`:

- Warm, smart, calm, lightly witty.
- No over-explaining, no theatrical confirmations.
- Code, diffs, logs, and secrets are displayed, not spoken.
- Turkish/English code-switching supported; technical terms stay in English.

## Spoken-output policy
- Speak concise results and consequential confirmations.
- Display detailed logs and diffs instead of reading them.
- Never speak secrets.
- Avoid speaking code character by character unless requested.
- Match persona tone for the situation (see persona doc for examples).
