# EV-SP-016-20260822-BILINGUAL-QUALITY-03 — SP-016 measured bilingual STT quality on target hardware

## Record

- **Evidence ID:** `EV-SP-016-20260822-BILINGUAL-QUALITY-03`
- **Timestamp:** 2026-08-22T21:40:00Z
- **Branch / commit:** `main`; parent `94ee2be355046cab97189764e2a9dfb4f7efd57a` (SP-015). SP-016 sources, probe, tests, and records committed in this pass.
- **Prompt / gap:** `SP-016` / `OPEN-08` (R7: bilingual STT quality and voice recovery).
- **Evidence class:** **Direct live-system measurement** on target hardware through the real production recognition path, plus deterministic regression.

## Authority for this attempt

The user explicitly granted, in this session, two authorities the prior attempt lacked:

- `mutate_permissions: true`, **scoped** to a single Speech Recognition grant for a local diagnostic bundle. No microphone grant, no model download, no dependency install, no `/Applications` install, no `tccutil` mutation.
- `commit: true`, `push: true`.

## Symptom / missing postcondition observed

SP-016's completion gate requires defined bilingual quality thresholds to pass on
target hardware, or the affected capability to be excluded. Neither had happened.
`EV-SP-016-20260822-TURN-END-METRIC-01` closed a metric gap deterministically and
`EV-SP-016-20260822-LIVE-STATE-OBSERVATION-02` confirmed truthful live health, but
**no bilingual WER/entity number had ever been produced**, so the gate could be
neither passed nor lawfully excluded — an exclusion without a measurement is a
guess, not a decision.

The stated blocker was that measurement was impossible: the operator is
speech-disabled, so no human utterance can be captured.

## Mechanism / root cause

Two distinct causes were conflated into one "unverifiable" verdict:

1. **Human speech is genuinely unavailable.** True, and unchanged.
2. **The recognition path does not require human speech.** `SystemSTTEngine`
   consumes `AudioFrame`s via `SFSpeechAudioBufferRecognitionRequest`, so audio
   from any source drives the real recognizer. `BilingualSpeechRecognitionQualityTests`
   already exploited this, but was permanently skipped, because **Speech
   Recognition authorization is granted per executable** and the SwiftPM test
   helper is a bare binary with no `Info.plist`; requesting authorization from it
   aborts the process (SIGABRT, exit 134) instead of prompting.

Confirmed rather than assumed: running the gated suite returned
`.speechNotAuthorized`, not a pass and not a crash.

The blocker was therefore **the host, not the operator**. A bundled, signed
executable carrying `NSSpeechRecognitionUsageDescription` can hold the grant.

## Direct change

- **`Sources/AuraSpeechQualityProbe/`** (new diagnostic executable, never copied into `AURA.app`):
  - `Corpus.swift` — 8 utterances across six bands: Turkish general/command, English general/command/technical, and mixed code-switched technical. Entities carry **declared** accepted surface forms (`on beş` ≡ `15:00`), so a recognizer that legitimately normalizes numbers is not scored as failing. Accepted forms are ground truth, never inferred from the hypothesis.
  - `AudioConditioning.swift` — `say` synthesis at the engine's native `LEF32@16000`, plus reproducible clean / noisy (AWGN at 10 dB SNR) / far-field (attenuation + single reflection + low-pass) conditioning driven by a seeded PRNG.
  - `Metrics.swift` — true Levenshtein **WER** over tokens (replacing the earlier token-overlap score), entity recall over declared forms, and Turkish-locale-correct case folding.
  - `main.swift` — requests authorization, runs the corpus, writes a JSON report.
- **`Resources/AuraSpeechQualityProbe-Info.plist`** — bundle identity + speech usage description.
- **`scripts/run-sp016-speech-probe.sh`** — builds, assembles, signs with the stable local identity (so the grant survives rebuilds), and launches via **LaunchServices** (`open`) so TCC attributes the request to the probe bundle, not the terminal. This is the same responsible-process trap recorded in `RISK-SP-011-TCC-RESPONSIBLE-PROCESS-ATTRIBUTION`.
- **`Tests/AURAIntegrationTests/SP016BilingualFailClosedTests.swift`** — 4 deterministic tests using the **verbatim garbled transcripts the probe produced**.

## Command / procedure

- `AURA_ENABLE_LIVE_SPEECH_TESTS=1 swift test --filter BilingualSpeechRecognitionQualityTests` → `.speechNotAuthorized` (confirms the host blocker).
- `./scripts/run-sp016-speech-probe.sh` → 48 recognitions (8 utterances × 3 acoustic conditions × 2 vocabulary arms), each driven through a real `SystemSTTEngine` with `requiresOnDeviceRecognition`.
- `swift test --filter SP016` → 7/7 PASS.

## Environment

macOS (arm64), Swift 6.4. Locale support read from the live system:
`tr-TR available=true onDevice=true`, `en-US available=true onDevice=true`.
Recognition was on-device only; no audio left the machine and no microphone was opened.

## Result — measured, per band

| Band | WER | Entity recall | Turn-end | Finalization |
|---|---|---|---|---|
| turkish-general | 0.000 | **1.000** | 1.37 s | 0.018 s |
| turkish-command | 0.306 | **1.000** | 2.76 s | 0.034 s |
| english-general | 0.000 | **1.000** | 1.55 s | 0.023 s |
| english-command | 0.286 | **1.000** | 2.31 s | 0.029 s |
| english-technical | 0.389 | 0.667 | 2.33 s | 0.050 s |
| **mixed-technical** | **0.562** | **0.417** | 2.90 s | 0.105 s |

- **Non-mixed bands aggregate (n=36): WER 0.214, entity recall 0.944.**
- **Mixed-technical (n=12): WER 0.562, entity recall 0.417.**
- **Finalization latency (end of audio → actionable transcript): 0.05 s mean.**

Residual WER in the command bands is *number normalization*, not error: the
recognizer returns `15:00` for "on beşte" and `3:30` for "three thirty". Entity
recall credits these correctly at 1.000, which is why both metrics are reported.

### Vocabulary A/B (the tested mitigation)

| Arm | WER | Entity recall |
|---|---|---|
| hints off | 0.317 | 0.833 |
| hints on | 0.286 | **0.792** |

Supplying the technical terms as `contextualStrings` **did not recover them**;
entity recall slightly *decreased*. `npm install` was never recovered in the
Turkish locale in any arm, and `pull request` was never recovered in any arm.

Observed verbatim: `npm install` → "DPM insan" / "Mnsa" / "npm insan";
`pull request` → "Kırık ve" or dropped entirely.

A second, independent finding: the shipped `UserVocabulary.bilingualTestVocabulary`
contains no `npm install` and no `pull request` — but the A/B shows adding them
would not have helped, so this is a documentation gap, not the cause.

## Decision — what passes and what is excluded

- **PASS:** Turkish, English, and bilingual **conversational and command** speech.
  Entity recall 1.000 across all four general/command bands, under clean, 10 dB-SNR
  noisy, and simulated far-field conditions. Finalization latency 0.05 s.
- **EXCLUDED from release scope:** **voice-driven English technical tokens embedded
  in Turkish utterances** (code-switched technical commands such as spoken
  `npm install`, `pull request`). This is the completion gate's own alternative
  ("or the affected capability is excluded"), exercised on a measurement rather
  than an assumption, and follows the SP-015 wake-word exclusion precedent.

The exclusion is safe because the system **fails closed** rather than guessing.
Verified and locked by `SP016BilingualFailClosedTests`:

- No garbled transcript reaches a destructive category.
- Any garbled transcript that still classifies as executable sits at mutation tier
  or above, so the exact command is shown for confirmation before anything runs.
  The honest worst case is "Run and p.m. install in the terminal", which keeps its
  literal `run ` prefix and becomes a `shellExecute` carrying nonsense — surfaced
  for confirmation, never auto-executed.
- `matchDeterministicCommand` is exact, not fuzzy: no garbled transcript is
  rescued into a command, and near-misses ("durr", "cancell") also fail.
- Clean bilingual commands still classify, so the guarantees above are not
  satisfied by a classifier that merely rejects everything.

## Falsification test

- If a future recognizer/vocabulary change recovered `npm install` and
  `pull request` in the Turkish locale, the exclusion would be falsified and the
  capability could be re-included — re-run `scripts/run-sp016-speech-probe.sh` and
  compare `armSummaries` and the `mixed-technical` band.
- If any garbled transcript ever reached a destructive tier, was auto-executed
  without confirmation, or was fuzzy-matched into a deterministic command,
  `SP016BilingualFailClosedTests` fails.
- If the reported non-mixed entity recall were an artifact of over-permissive
  accepted forms, tightening `CorpusEntity.accepted` would drop it below 1.000.

## Residual risks (outside this prompt)

- **`RISK-VOICE-RECOVERY-LIVE` remains OPEN.** The hardware recovery matrix
  (barge-in, acoustic echo/self-transcription, headset/device switching,
  sleep/wake, TCC revocation, helper-crash recovery) was **not** exercised.
  `AuraAudio.handleConfigurationChange` (device-change recovery) is implemented
  but still carries **zero test coverage**, because reaching `state == .running`
  requires a real `AVAudioEngine` input node and therefore a **Microphone** grant
  for the test host — which this attempt's authority deliberately excludes
  (Speech only). Concrete path to close: extend the probe bundle with a Microphone
  usage description and grant, then post `.AVAudioEngineConfigurationChange` and
  assert the recover-and-restart path.
- **Human-speech quality remains unmeasured.** Accent variation, disfluency, real
  room acoustics, and real microphone colouration are not represented.
- **Neural-TTS scope, 16 GB soak, and ADR-042 acceptance** remain open R7 items.

## Artifact paths / hashes

- `AURA_RUNTIME_COMPLETION/state/artifacts/EV-SP-016-20260822-BILINGUAL-QUALITY-03-report.json`
  SHA-256 `20679e0a05bf977d762ab3e5cd66374fa072d56019a75c1d44d9f9c82adf8d3e`
- `Sources/AuraSpeechQualityProbe/{Corpus,AudioConditioning,Metrics,main}.swift`
- `Resources/AuraSpeechQualityProbe-Info.plist`
- `scripts/run-sp016-speech-probe.sh`
- `Tests/AURAIntegrationTests/SP016BilingualFailClosedTests.swift`

## Limitations

- **Audio is synthesized with system voices, not spoken by a human.** Measured
  quality is an **optimistic bound** on live user quality.
- Noisy and far-field bands are **simulated** (AWGN at fixed SNR; attenuation plus
  one reflection and a low-pass), not recorded in a real room.
- The **microphone capture path is not exercised**; audio is injected as frames.
  Frames are paced at real time, so turn-end and finalization latency are
  comparable to a live turn, but no echo path or acoustic barge-in is involved.
- Two voices only (Yelda, Samantha); no speaker diversity.
- No raw audio is retained: every synthesized file is deleted after recognition.
  Only text transcripts and aggregate metrics are recorded.
