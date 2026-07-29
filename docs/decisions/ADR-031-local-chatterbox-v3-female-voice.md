# ADR-031 — Local Chatterbox V3 with Consent-Bound Female Voice

**Status:** Accepted
**Date:** 2026-07-29
**Supersedes:** ADR-024 and the TTS-selection portion of ADR-030

## Context

ADR-024 intentionally stopped at an adapter stub. The user has now authorized
real local Chatterbox Multilingual V3 inference and selected a female Turkish
voice. AURA must remain usable while the model is absent, warming, or failed,
and must not impersonate a person without an owned or explicitly consented
reference recording.

The published PyPI wheel does not expose the current V3 loader used by the
upstream source tree. The runtime therefore pins the official Chatterbox source
and model revisions instead of silently labeling a V2 wheel as V3.

## Decision

1. Run Chatterbox Multilingual V3 in a persistent, separate Python 3.11 process.
   Pin the official source, Perth watermark dependency, and model snapshot by
   immutable Git revisions.
2. Keep the virtual environment and model weights outside the repository under
   the user's AURA Application Support directory. Record an SHA-256 manifest
   for every downloaded model artifact.
3. Communicate through bounded newline-delimited JSON over stdin/stdout.
   Transcript text is never placed in argv or sent to a network endpoint.
4. Start the configured female `tr-TR` Yelda system voice immediately. Neural
   warm-up happens asynchronously; any validation, startup, synthesis, path, or
   playback failure returns to Yelda without exposing helper error internals.
5. Enable neural production speech only when
   `Voices/aura-female-reference.wav` is readable. That file must be owned by
   the user or accompanied by explicit speaker consent. It is never bundled,
   uploaded, or synthesized from an Apple system voice.
6. Restrict generated audio to a private `0700` directory, accept only bounded
   regular WAV files within that directory, and delete them after playback.
7. Bundle only the audited helper source. The runtime, weights, cache, and
   reference recording remain external mutable state.
8. Preserve the PerTh neural-audio watermark supplied by upstream.

## Security and privacy consequences

- Unsupplied or invalid runtime material fails closed to local system speech.
- The helper inherits no AURA secrets and runs with offline Hugging Face mode.
- A separate process provides crash and dependency isolation, but it is not an
  App Sandbox boundary. A future hardened helper/XPC service remains desirable.
- Model code and files are supply-chain pinned; installation is an explicit
  user action and is not performed on application launch.
- Voice identity is consent-gated. A generic model default may be used only for
  engineering diagnostics, never represented as the accepted female persona.

## Acceptance

- Strict Swift build and unit tests prove fallback, warm-up, request bounds,
  private-path enforcement, cleanup, stop behavior, and factory wiring.
- Python sources compile and the helper rejects incomplete model snapshots.
- A pinned snapshot installs with a complete SHA-256 manifest.
- A local diagnostic synthesis records load time, synthesis latency, memory,
  WAV metadata, and device fallback without remote transcript or audio transfer.
- Final product acceptance remains open until an owned/consented female WAV and
  one human-listened Turkish turn are available.
