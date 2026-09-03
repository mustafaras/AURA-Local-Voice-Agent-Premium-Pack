# EV-SP-016-20260822-LIVE-STATE-OBSERVATION-02 — SP-016 live voice/recovery state observation via computer-use

## Record

- **Evidence ID:** `EV-SP-016-20260822-LIVE-STATE-OBSERVATION-02`
- **Timestamp:** 2026-08-22T19:20:00Z
- **Branch / commit:** `main`; live `HEAD == origin/main == 94ee2be355046cab97189764e2a9dfb4f7efd57a` (SP-015). Working tree carries the SP-016 deterministic edits (turn-end metric + test) plus the control-plane projections; nothing committed or pushed.
- **Prompt / gap:** `SP-016` / `OPEN-08` (R7: bilingual STT quality and voice recovery).
- **Environment:** macOS (arm64), installed `/Applications/AURA.app` (bundle id `ai.aura.local.agent`) launched via LaunchServices; Accessibility-driven computer-use observation (AppleScript/System Events) of the live running app's own UI.
- **Authority:** `launch_or_install_app:true` (explicitly authorized app launch); `mutate_permissions:false` (no TCC dialog was invoked, no permission changed). Computer-use tools authorized by the user ("computer use kullanabilirsin").

## Procedure

1. Launched the installed AURA app via `open /Applications/AURA.app`; confirmed running (`pgrep`).
2. Drove the app window with System Events Accessibility: enumerated the window accessibility tree (`AXIdentifier`s), navigated the six section tabs (Conversation / Tasks / Capabilities / Models / Privacy / Recovery), and read the live permission and runtime-health readouts the app itself displays.
3. Did **not** click "Request Microphone and Speech Access" (that would mutate TCC). Did **not** attempt a live spoken turn (the operator is speech-disabled; no speech-capable operator is present). Cleanly stopped the app at the end.

## Live result (read from the running app's own UI)

- **Permission indicators (Privacy tab):** `Microphone: Granted`, `Active speech recognition: Granted`, `Screen observation: Denied`.
- **Runtime health (Recovery tab), truthful matrix:**
  - `stt: ready. speech recognition started`
  - `audio: ready. audio capture started`
  - `voice-resources: ready. bounded local voice reservations active for 16384 MB physical memory`
  - `tts: ready. chatterbox: Female Yelda active while Chatterbox V3 warms locally`
  - `wake-word: unsupported. trained acoustic wake-word model is not bundled; Push to Talk is supported`
  - `plugins: degraded ... registry remains fail-closed`; `productivity: disabledByConfiguration`; `safari-bridge: disabledByConfiguration`; `screen: disabledByConfiguration`; backend adapters `degraded`.
- **Status pill:** `Idle. Ready — use Push to Talk`.

## Significance

This is direct **live-system** evidence that the AURA app, running on the actual target Mac, already holds **Microphone and Speech Recognition TCC grants** (from the earlier SP-002 PTT accommodation) and truthfully reports its STT (`stt ready`), audio capture (`audio ready`), voice-resource governor (16 GB budget), TTS (Yelda fallback), and wake-word (unsupported, Push-to-Talk only) health. The UI is honest: it never claims a live WER corpus, a trained wake model, or a permission that is not granted. This is a truthful-degradation / truthful-health live check, not a fabricated WER measurement.

## What this does NOT prove (keeps OPEN-08/SP-016 open)

- No bilingual Turkish/English/mixed WER/entity corpus was run and no WER/entity/turn-end metric was produced from live speech: the operator is speech-disabled and no speech-capable operator was present, so no real utterance was captured. The live mic path was not exercised.
- Barge-in, echo/self-transcription, headset/device switching, sleep/wake, interruption, TCC revocation, and helper-crash recovery were not exercised on real hardware.

## Falsification test

If the app had reported `Microphone: Denied`/`Not determined` or `stt` degraded/unavailable while claiming Push-to-Talk readiness, the truthful-degradation claim would be falsified. The observed health matrix is internally consistent and truthful.

## Limitations

- Observation was read-only (no live mic turn, no TTS synthesis, no TCC change, no device/hardware recovery exercise). The live bilingual WER corpus and the hardware recovery matrix remain unverified and are the continuing blockers for SP-016's completion gate.

## Artifacts

- Live AX readouts captured in the session (not stored verbatim); app cleanly stopped after observation. This artifact records the stable, redacted result.
