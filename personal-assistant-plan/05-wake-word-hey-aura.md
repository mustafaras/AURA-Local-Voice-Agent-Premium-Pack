# PA-4: "Hey AURA" — a real on-device wake word

**Phase:** PA-4. **Effort:** L. **ADR:** ADR-068 (new) — "On-device wake word via Apple Speech; amends ADR-042 §5".
**Owner instruction covered:** "WAKE UP WORD HEY AURA VE SADECE HEY VE AURA OLMALI" — the phrase is exactly the two tokens *hey* + *aura*.

---

## 1. Evidence

| Fact | Evidence |
| --- | --- |
| The production detector cannot detect | `AuraKernel_Construction.swift:492` composes `DisabledWakeWordDetector()`; `WakeWordDetector.swift:27-45` ("This is deliberately not a degraded-ready signal: it can never detect") |
| The whole pipeline around it exists | `WakeWordPipeline` actor (`WakeWordPipeline.swift:10`, `_EventHandling`, `_Emitters`, `_Lifecycle`), started by the kernel (`AuraKernel_StartStop.swift:28-38`); events `WakeWordHypothesisEvent`, `WakeWordDetectedEvent`, `WakeWordMetricsEvent`; `PerformanceSampler.wakeWordFalseAccepts`; activation source `.wakeWord` (`TurnContext.swift:7`) |
| Configuration already says "hey aura" | `Configuration_WakeWordConfiguration.swift:39` `phrase: String = "hey aura"`; threshold 0.75, debounce 2 s, anti-trigger on, speaker verification off (`:39-49`) |
| Detector contract is per-frame and synchronous | `WakeWordDetector.analyze(_ frame: AudioFrame, vadResult:) -> WakeHypothesis` (`WakeWordDetector.swift:19-26`); frames are mono float 16 kHz (`AudioFrame.swift:9`, `Configuration_AudioConfiguration.swift:16`) |
| Why it was excluded | ADR-042 §5 and table row "Wake word via licensed local model — Deferred (excluded) — No candidate qualified (FAR/FRR, TR support, noise/distance, license/hash, soak); authority forbids download/install in this pass"; ADR-055 §7 kept the exclusion |
| The SDK now has an on-device streaming recognizer | `Speech.swiftmodule/arm64e-apple-macos.swiftinterface`: `AnalyzerInput` (line 13), `AssetInventory.assetInstallationRequest(supporting:)` (57), `DictationTranscriber` presets incl. `.progressiveShortDictation` (70-78), `SpeechDetector` module (267), `SpeechTranscriber` with `.volatileResults` (378, 424), `SpeechAnalyzer` actor (228) with `bestAvailableAudioFormat(compatibleWith:)` (254) |
| Onboarding and copy still say "no acoustic model" | `ProductUIState.swift:791-794` (`onboarding.explain.wakeWord`); `AuraMenuView.swift:335,363` |
| Privacy-mode arming | `WakeWordConfiguration.privacyModeRequiresKeyboardShortcut = true`, shortcut `⇧⌘L` (`:47-49`) — privacy mode is a separate, owner-invoked state and stays |

## 2. Problem statement

The owner wants to say "Hey AURA" and be heard, always. ADR-042 excluded wake word because the only candidates were downloadable third-party models that could not be licensed, hashed, or soak-tested inside the authority of that phase. The installed macOS 27 SDK removes that constraint: Apple's `SpeechAnalyzer` stack runs on-device, ships with the OS (assets installed through `AssetInventory`, no third-party download), supports Turkish and English, and streams volatile hypotheses fast enough for keyword spotting. Push-to-talk remains available; it is no longer the only activation.

## 3. Design

### 3.1 Detector choice (D-4)

`SpeechAnalyzerWakeWordDetector` in **`AuraSTT`** (the only module that already imports `Speech`; `AuraAudio` stays framework-free). It conforms to `WakeWordDetector` through a streaming adapter:

- An `AsyncStream<AnalyzerInput>` fed from `analyze(_:vadResult:)` — each `AudioFrame` is converted to an `AVAudioPCMBuffer` in the format returned by `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` (resample from 16 kHz if required; verify the returned format live).
- A `SpeechTranscriber` (or `DictationTranscriber(.progressiveShortDictation)` — G4-1 decides by measured latency) with `.volatileResults`, locale chosen from the owner's UI language, on-device assets ensured via `AssetInventory.assetInstallationRequest` at first start (recorded in runtime health; if assets are missing and cannot be installed, the detector reports `unavailable` and the UI says so — never a silent PTT fallback).
- Keyword spotting on the rolling volatile transcript: normalize (lowercase, strip punctuation/diacritics), match the exact token pair `hey` `aura` with a bounded gap (≤ 1 filler token) and a small closed set of ASR spellings for *aura* (`aura`, `ora`, `avra`, `awra` — the set is fixed by live evidence in G4-5, not guessed), producing `WakeHypothesis(detected:confidence:matchedPhrase:)` where confidence derives from match tightness and the transcriber's per-result confidence when available.
- `analyze()` stays synchronous: it enqueues the frame and returns the latest hypothesis computed by the background task (one-frame latency, well inside the 2 s debounce). `reset()` restarts the analyzer session.
- VAD gating: frames below `vadEnergyThresholdDB` are not fed (saves CPU, matches the pipeline's VAD-first design).

Rejected: Porcupine / openWakeWord / sherpa-onnx KWS — all require downloading a model artifact or a licence; ADR-042's "authority forbids download/install" is not lifted by this plan, and the on-device Apple path makes it unnecessary.

### 3.2 Exact phrase, pinned

- `WakeWordConfiguration.phrase` stays `"hey aura"`; a test asserts the production configuration's phrase is exactly `"hey aura"` and that the detector rejects `"aura"` alone, `"hey"` alone, and `"hey siri"`.
- The Settings/onboarding surface shows the phrase read-only as **Hey AURA**; there is no free-text phrase editor (the owner said *only* Hey AURA).

### 3.3 Anti-self-trigger and etiquette

- Existing `enableAntiTriggerProtection` path: the detector is muted while TTS is speaking (`isSpeakingResponse` signal already feeds the Orb) plus a 300 ms tail.
- Debounce 2 s (existing). A detection sets `activationSource: .wakeWord`, plays the wake grain only if sound feedback is on (UI-0 scaffold), and opens a listening window identical to PTT's.
- Privacy mode (⇧⌘L) still suspends wake listening; the status pill says so.

### 3.4 Always-on capture and resources

Continuous 16 kHz mono capture through the existing `AuraAudio` ring buffer; the resource governor (ADR-042) must classify the analyzer as a steady low-priority consumer. G4-5 records idle CPU % and energy impact (Activity Monitor "Energy Impact" column, `os-observed`) over 30 min; acceptance threshold proposed: ≤ 4 % CPU average on the host, documented as evidence not as a promise.

### 3.5 UI and copy

- Onboarding `wakeWord` stage becomes a live check: "Hey AURA deyin" with the Orb reacting; copy `onboarding.explain.wakeWord` rewritten EN/TR; stage remains optional in the reducer (behavior-frozen).
- Status pill: EN "Listening for Hey AURA" / TR "Hey AURA için dinliyor"; Capabilities: `voice.wake_word` row `Hazır`.
- Models tab shows the wake engine as "Apple Speech (on-device)".

## 4. Files touched

`Sources/AuraSTT/SpeechAnalyzerWakeWordDetector.swift` (new), `Sources/AURA/AuraKernel_Construction.swift:492` (composition), `Sources/AuraCore/Configuration_WakeWordConfiguration.swift` (doc comment only), `Sources/AURA/AuraMenuView.swift` (onboarding stage presentation), `AuraMenuView_Content.swift` (pill copy), `ProductUIState.swift` (copy), `AuraAppModel_Interaction.swift` (wake-activated listening window reuses PTT path), tests, ADR-068, ledgers. Voice resource governor configuration if a new consumer class is required.

## 5. Tests

- **New:** `SpeechAnalyzerWakeWordDetectorTests` with an injected transcript source (no real Speech in unit tests): exact match, near-miss rejection, gap rule, spelling set, mute-while-speaking, debounce interaction via `WakeWordPipeline` with the new detector; phrase pin test; asset-unavailable → `unavailable` status test; copy keys.
- **Reused:** the existing `WakeWordPipeline` tests with `MarkerWakeWordDetector` stay untouched (pipeline semantics unchanged).
- **Typecheck probe (G4-1):** a `swiftc -typecheck` probe file exercising `SpeechAnalyzer`, `SpeechTranscriber`, `AnalyzerInput`, `AssetInventory` against the real SDK, per the repo's verified-API rule (memory: every API verified against real SDK headers before use).

## 6. Live acceptance (FAR/FRR evidence, `live-local` + `owner-attested`)

| Leg | Procedure | Record |
| --- | --- | --- |
| Positive | 20 × "Hey AURA" at ~1 m and 10 × at ~3 m, normal voice | detections / attempts (FRR) |
| Negative soak | 30 min of speech radio/TV and conversation without the phrase | false accepts (FAR) via `wakeWordFalseAccepts` |
| Near-miss | 10 × "hey", 10 × "aura", 5 × "hey siri" | must be 0 detections |
| Self-trigger | AURA speaks a sentence containing "hey aura" via TTS | 0 detections |
| Turkish/English | 10 × each UI language | detections |
| Latency | phrase end → listening pill | median ms |
| Resource | 30 min idle CPU % and Energy Impact | numbers |

Acceptance is recorded as numbers; the ADR states the achieved FAR/FRR. There is no pass/fail threshold invented in advance — the owner reads the numbers and approves.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Volatile-result latency too high for a wake word | G4-1 measures; `DictationTranscriber(.progressiveShortDictation)` and `SpeechDetector` gating are the fallbacks; PTT stays |
| Turkish ASR spells "aura" unpredictably | Spelling set fixed by live transcripts captured in G4-5 (stored in `evidence/`), not guessed |
| Continuous recognition CPU/energy on a 16 GB host | Measured in G4-5; VAD gating; governor class |
| Locale assets not installable offline | Detector reports `unavailable` honestly; onboarding explains; owner installs via the system dialog |
| Speech Recognition TCC | Already granted in PA-1's pass (`NSSpeechRecognitionUsageDescription` present) |

## 8. Owner decisions consumed

D-4.
