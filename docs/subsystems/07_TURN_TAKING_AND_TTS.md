> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
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

The production Chatterbox adapter runs the pinned official Multilingual V3
implementation in a persistent local Python 3.11 helper. Model weights,
environment, cache, and the voice reference remain outside the app bundle under
the user's private AURA Application Support directory. Requests use bounded
stdin/stdout JSON; generated WAV files are path/size/type checked and removed
after playback. See ADR-031.

Neural voice identity is consent-bound. AURA activates Chatterbox speech only
when the user provides an owned or explicitly consented female WAV at
`~/Library/Application Support/AURA/Voices/aura-female-reference.wav`.
Otherwise it remains on the configured female Turkish Yelda system voice.
Warm-up and inference failures also fail closed to Yelda, so the assistant is
responsive while the neural model loads.

The system fallback normally ranks installed voices by exact locale match and
platform voice quality, but AURA's configured default explicitly selects
compact female `tr-TR` Yelda. A configured rate of `1.0` maps to
`AVSpeechUtteranceDefaultSpeechRate`, rather than the framework's absolute
maximum rate. Small local pre/post delays and a bounded emphasis-to-pitch
mapping improve phrasing without sending text or audio off-device.

All adapters must:
- Expose `speak(_: TTSPrompt) -> AsyncStream<TTSChunk>`.
- Honor immediate `stop()`/`pause()`/`resume()` calls without audio leakage.
- Report synthesis errors as typed `AuraError.ttsAdapterFailed` events.
- Never send transcript text off-device unless an explicitly opted-in remote adapter is selected.

## Voice persona

AURA's spoken persona is defined in `persona/AURA_VOICE_AND_BEHAVIOR.md`:

- Warm, smart, calm, respectfully sharp, and dryly witty.
- Teasing targets the situation or the assistant itself, never identity,
  appearance, vulnerability, protected traits, or a consequential mistake.
- Humor is disabled for safety, privacy, health, legal, financial, grief, and
  emergency contexts.
- No over-explaining, no theatrical confirmations.
- Code, diffs, logs, and secrets are displayed, not spoken.
- Turkish/English code-switching supported; technical terms stay in English.

## Spoken-output policy
- Speak concise results and consequential confirmations.
- Display detailed logs and diffs instead of reading them.
- Never speak secrets.
- Avoid speaking code character by character unless requested.
- Match persona tone for the situation (see persona doc for examples).

## R7 implementation boundary

Conversation state now applies a conservative bounded continuation window when a
stable segment visibly ends with a connector, delimiter, or open punctuation;
the text is never rewritten. System TTS retains its active synthesizer so
`stopSpeaking`, `pauseSpeaking`, and `resumeSpeaking` are real AVFoundation
operations on the serial synthesis queue. Chatterbox synthesis is bounded by a
helper timeout, memory reservation, private WAV validation/cleanup, and
system-Yelda fallback on timeout, failure, or resource denial. CPU is the safe
default; MPS remains opt-in until live thermal/latency qualification.

Live barge-in/echo behavior, consented neural reference and human listening
acceptance, first-audio latency, cache/soak evidence, and release-quality
neural-vs-system voice selection remain open.
