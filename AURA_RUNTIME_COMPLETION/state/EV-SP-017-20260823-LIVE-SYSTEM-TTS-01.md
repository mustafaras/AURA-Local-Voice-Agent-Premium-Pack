# EV-SP-017-20260823-LIVE-SYSTEM-TTS-01

- **Timestamp:** 2026-08-23T14:16:32Z
- **Branch / commit:** `main` / `f6518e1333015b31c4783f0a4e8f033555f6e1f1` (working-tree edits were present; no commit or push)
- **Evidence class:** direct live system-TTS procedure plus prompt-relevant regression
- **Command:** `AURA_ENABLE_SYSTEM_TTS_LIVE_TESTS=1 swift test --filter 'SystemTTSLatencyTests|SystemTTSEngineTests|releaseTTSDefaultIsSystemOnly' --build-path /tmp/aura-sp017-live-final`
- **Environment:** macOS 27.0 build `26A5416b`, Apple Silicon `arm64`, Apple M5 (`Mac17,4`), 16 GiB unified memory, 10 CPUs; system `AVSpeechSynthesizer` path; no TCC mutation and no raw audio retention.
- **Result:** exit 0; `AuraCoreTests` release-default assertion passed; the two live system-TTS suites passed **14/14** in 5.428 s. `firstChunkLatencyIsUnderBudget` passed in **0.733 s** and `fullUtteranceLatencyIsUnderBudget` passed in **1.400 s**. Stop, pause/resume, active-stream interruption/barge-in, consecutive-stop idempotence, and anti-trigger lifecycle tests also passed.
- **Artifact path / hash:** `/tmp/aura-sp017-live-final` (ephemeral Swift build output; no raw audio artifact retained and therefore no audio hash). This evidence record is the durable artifact.
- **Scope:** proves the release-qualified system voice can start, emit, interrupt, pause/resume, and complete on the target host. It supports the system-TTS-only release path and does not qualify Chatterbox/Dia, wake word, human listening, room acoustics, or speaker-to-microphone echo.
- **Limitations:** latency is a direct live synthesizer test, not a user-perceived acoustic measurement; the command does not establish an 8-hour neural soak, MPS behavior, thermal energy budget, or physical microphone echo behavior.
