---
id: PA-4
sequence: 4
track: PA
depends_on: PA-3
next_prompt: PA-5
state: pending
design_docs: 05-wake-word-hey-aura, 07-cross-cutting-constraints
adr: ADR-068
---

# PA-4 — "Hey AURA" Wake Word

## Mission

Replace `DisabledWakeWordDetector()` with a real on-device detector built on Apple's `SpeechAnalyzer` stack, pinned to the exact phrase "hey aura", with anti-self-trigger, debounce, honest unavailability, live FAR/FRR evidence, and an ADR that amends ADR-042 §5.

## Read before acting

- Plan: `ledger/CURRENT_PHASE.md`, ledger tail, `00-working-protocol.md`, `05-wake-word-hey-aura.md`
- Repo: ADR-042 (§5, table row "Wake word via licensed local model"), ADR-055 §7, ADR-025 (native speech STT), `TOOLCHAIN.md`
- Code: `Sources/AuraAudio/WakeWordDetector.swift`, `WakeWordPipeline*.swift`, `AudioFrame.swift`, `Sources/AuraCore/Configuration_WakeWordConfiguration.swift`, `Sources/AuraSTT/SystemSTTEngine*.swift` (Speech import precedent), `Sources/AURA/AuraKernel_Construction.swift:480-500`, `AuraAppModel_Interaction.swift` (PTT listening window), `AuraMenuView.swift:330-370` (onboarding wakeWord stage), `ProductUIState.swift:791-794`
- SDK: `Speech.swiftmodule/arm64e-apple-macos.swiftinterface` in the installed macOS 27 SDK — `SpeechAnalyzer` (line 228), `SpeechTranscriber` (346, `.volatileResults` 378), `DictationTranscriber` (70-78), `SpeechDetector` (267), `AnalyzerInput` (13), `AssetInventory.assetInstallationRequest` (57), `bestAvailableAudioFormat` (254)
- Owner decision D-4 recorded.

## Hard boundaries

- **Allowed files:** `Sources/AuraSTT/SpeechAnalyzerWakeWordDetector.swift` (new), `Sources/AURA/AuraKernel_Construction.swift` (one composition line), `AuraAppModel_Interaction.swift` (wake-activated listening reuses the PTT path), `AuraMenuView.swift` (stage presentation), `AuraMenuView_Content.swift` (pill copy), `ProductUIState.swift` (copy), voice resource governor configuration if a consumer class is needed, tests, `docs/decisions/ADR-068-*.md`, ledgers.
- Forbidden: downloading any model artifact; adding a package dependency; changing `WakeWordDetector`'s protocol; a free-text phrase editor; a silent PTT fallback when assets are unavailable; touching the stage machine.
- Every Speech API is typecheck-probed against the real SDK before use (G4-1) — no assumed signatures.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G4-1 | SDK verification: `swiftc -typecheck` probe compiles against the real SDK for `SpeechAnalyzer`, `SpeechTranscriber`/`DictationTranscriber`, `AnalyzerInput`, `AssetInventory`; measured volatile-result latency on a 2 s clip decides transcriber choice; ADR-068 drafted | probe file + output in `evidence/PA-4/`; latency numbers |
| G4-2 | Detector: streaming adapter, exact `hey`+`aura` match with bounded gap and a spelling set, confidence, mute-while-speaking, VAD gating, `reset()`, `unavailable` when assets missing | `unit` with injected transcript source |
| G4-3 | `[policy]` Composition + pin: kernel composes the detector; production `phrase == "hey aura"` pinned by test; near-miss rejection ("hey", "aura", "hey siri") | `unit`; `grep -n DisabledWakeWordDetector Sources/AURA/` = 0 |
| G4-4 | UI: onboarding wakeWord stage is a live "Hey AURA deyin" check; pill copy EN/TR; Models tab names the engine; `voice.wake_word` row `Hazır` | `integration` view tests; copy guard |
| G4-5 | Live FAR/FRR table from `05-…md` §6 (positive 1 m/3 m, 30-min negative soak, near-miss, self-trigger, TR/EN, latency, 30-min CPU/energy); Turkish spelling set fixed from captured transcripts | `live-local` + `os-observed` numbers in `evidence/PA-4/far-frr.md` |
| G4-6 | Full verification + governance: suite ×2–3, ADR-068 accepted with achieved numbers, repo ledgers, `CURRENT_STATE` | `evidence/PA-4/` |
| G4-7 | Machine coherence | validator OK, `awaiting-approval` |

## Per-gate procedure

- **G4-1:** write `evidence/PA-4/speech-probe.swift`; `xcrun swiftc -typecheck -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macos27 evidence/PA-4/speech-probe.swift`; then a tiny runnable probe measuring first-volatile-result latency; record.
- **G4-2:** implement; tests with an injected `AsyncStream<String>` transcript source; no real Speech in unit tests.
- **G4-3:** compose; pin test; near-miss tests via the pipeline with the new detector.
- **G4-4:** presentation and copy; tests.
- **G4-5:** stable-signed bundle, `open -a`; run the table; owner speaks; capture `wakeWordFalseAccepts` via the telemetry surface; Activity Monitor numbers by owner attestation or `ps -o %cpu` sampling.
- **G4-6/G4-7:** closing sequence.

## Evidence template

```text
## SEQ-00NN — <ISO> — PA-4 — G4-k PASSED
- evidence: …
- verified: …
- adr: ADR-068   ← G4-3
- numbers: FRR=<x/y> FAR=<n per 30 min> latency_median_ms=<n> cpu_avg=<n%>
```

## Risks / reverting

If G4-1 shows volatile latency unusable for a wake word after trying both transcribers and `SpeechDetector` gating, the phase stops `blocked` with numbers and the owner decides (PTT remains). Reverting is restoring the composition line to `DisabledWakeWordDetector()`.

## Session script

Protocol §5, then G4-1 → G4-7. End with `awaiting-approval`.

## Cognitive completion gate

(1) What exact tokens trigger the assistant, and what proves "aura" alone does not? (2) What happens when AURA itself says "hey aura"? (3) What does the owner see when speech assets are missing?
