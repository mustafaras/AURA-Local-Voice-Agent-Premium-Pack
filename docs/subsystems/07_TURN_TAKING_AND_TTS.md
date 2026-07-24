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
Support macOS system voices and optional local neural TTS through a streaming protocol.

## Spoken-output policy
- Speak concise results and consequential confirmations.
- Display detailed logs and diffs instead of reading them.
- Never speak secrets.
- Avoid speaking code character by character unless requested.
