# EV-SP-003-20260816-RISKS-AND-UI-19

**Session:** AURA-SP-003-LIVE-DIALOGUE-20260815
**Timestamp:** 2026-08-16T08:20:49Z
**Branch / commit:** `main`, on top of `86bd957`
**Environment:** macOS 27 / Apple Silicon arm64 / Swift 6.4 / CommandLineTools
**Evidence class:** Source change plus deterministic regression evidence. No live-model run.

## Purpose

User instruction to resolve the two remaining SP-003 residual risks and to rework the product UI.
Records what was actually closed, what was only narrowed, and why.

## 1. `RISK-SP-003-NLU-DOWNGRADE-VARIANCE` — CLOSED

**Correction to the previous disposition.** `EV-SP-003-20260815-INJECTION-COVERAGE-18` recorded
this risk as not fixable without weakening the safety test
`structuredModelActionProposalCannotBecomeExecutableIntent`. That conclusion was wrong, and the
reason is worth recording: the test's proposed capability ID, `shell.execute`, **is not a
registered capability at all** — `InitialCapabilitySet` registers `shell.execute_typed`. The test
was therefore asserting behaviour for a *hallucinated* ID, and the two cases had been conflated.

R2 §C requires unknown capability IDs to be **rejected**. Rejecting a hallucination means
discarding the proposal and falling back to the deterministic classification — not manufacturing
ambiguity from it. The previous code treated any proposal as evidence of user ambiguity, which is
what produced the spurious downgrade of plain questions.

Change:

- `IntentEngine` gains an optional `capabilityRegistry`. `applyStructuredNLUIfNeeded` now checks a
  proposed capability ID against it via a new `isHallucinatedCapability(_:)` helper.
- Unregistered ID → proposal discarded, turn stays `.converse` (still not executable).
- Registered ID → existing downgrade to `.unknown`/`.clarify` retained.
- No registry wired in → nothing is verifiable, so the conservative downgrade still applies. The
  fix can never make an unverifiable case less safe.
- `AuraKernel_Construction` passes the real registry in production.

Verification — `AuraIntentTests` **72/72** (70 before, +2):

- `structuredModelActionProposalCannotBecomeExecutableIntent`, re-pointed to the registered
  `shell.execute_typed`, still asserts `.unknown`/`.clarify`.
- `hallucinatedCapabilityProposalIsRejectedAndKeepsConversation` — invented ID keeps `.converse`,
  `.answer`, non-ambiguous, and the invented name never reaches the typed intent's slots.
- `withoutARegistryAProposedCapabilityStillDowngrades` — the no-registry path stays conservative.

The safety invariant is unchanged in every branch: a model proposal never becomes executable.

## 2. `RISK-SP-003-LIVE-VOICE-RESIDUAL` — NARROWED, NOT CLOSED

Previously recorded as unclosable because the operator is speech-disabled. That framing was too
broad: the risk covers Turkish/English *recognition quality*, and `SystemSTTEngine` ingests
`AudioFrame`s through `SFSpeechAudioBufferRecognitionRequest`, so real audio from any source can
drive the real recognizer — a human throat is not required.

Built `Tests/AuraSTTTests/BilingualSpeechRecognitionQualityTests.swift`: synthesizes Turkish
(`Yelda`) and English (`Samantha`) speech with `say --data-format=LEF32@16000`, decodes it with
`AVAudioFile`, feeds 100 ms frames at 16 kHz into a real `SystemSTTEngine`, and scores transcripts
by token overlap. Three tests: Turkish recognized, English recognized, and locale actually
selecting the recognition language rather than being stored and ignored.

**It cannot execute in this environment, and that is the finding.** TCC authorization is granted
per executable. SP-002's Speech Recognition grant belongs to `AURA.app`; the SwiftPM test helper
is a separate bare binary with no `Info.plist`, so it holds no grant, and calling
`SFSpeechRecognizer.requestAuthorization` from it aborts the process outright (observed: test
helper exit 134, SIGABRT — macOS kills a process that requests a TCC-protected API without a usage
description). The harness now checks `authorizationStatus()` and throws a precise error instead of
crashing the suite.

Two container details were also established by direct observation rather than assumption: `say`
refuses little-endian float into AIFF (`Opening output file failed: fmt?`) because AIFF is
big-endian, so the harness writes WAV.

Status change: from "unverifiable in principle" to **"verifiable, blocked on test-host
packaging"**. Closing it requires running this harness inside a bundled host carrying
`NSSpeechRecognitionUsageDescription`. That is real remaining work, not a formality, so the risk
stays open.

Also unchanged: synthesized speech is cleaner than human speech — no accent variation, disfluency,
room noise, or microphone colouration — so any accuracy this harness eventually measures is
optimistic and is not a WER figure for real users. It does not exercise microphone hardware
capture either; SP-002 covered that half separately.

## 3. Product UI rework

New `Sources/AURA/AuraDesign.swift` centralizes spacing, radius, typography, panel surfaces, and
status colour. Motivation is drift, not decoration: the UI spans several files and every ad-hoc
literal is a place the product falls out of alignment with itself. All colours resolve through
semantic system colours, so light/dark, increased contrast, and the user's accent colour keep
working without a second palette.

| Surface | Before | After |
|---|---|---|
| Header | Icon plus `status — detail` text | Identity mark, wordmark, subtitle, and a colour-coded `AuraStatusPill` |
| Navigation | Six tabs in one segmented control | Icon + full-name pills |
| Transcript | Every turn an identical `GroupBox` | `AuraMessageBubble` — user right-aligned and accent-filled, AURA left-aligned on a neutral surface |
| Composer | Text field above a full-width mic bar | One row: field, inline send, prominent Push-to-Talk |
| Confirmation | Plain `GroupBox` | `AuraPanel` with orange heading and a risk icon |
| Section titles | `.title3.bold()` label | `AuraSectionHeader` with tinted glyph and optional subtitle |

Two decisions worth stating:

- **Colour never carries meaning alone.** Status is stated in text beside the dot, the selected tab
  carries `.isSelected` rather than relying on tint, and every existing accessibility label,
  `.isHeader` trait, and bilingual `copy(...)` lookup is preserved.
- The six-tab segmented control was replaced primarily because it was **unreadable in Turkish**,
  where the section names are longer and were being truncated to a few characters — a legibility
  fix, not a style preference.

No model, state, or public API changed; the rework is view composition and styling only.

## Verification

- Full sweep: **21/21 bundles, 0 failed**.
- `AuraIntentTests` 72/72; `AuraAgentTests` 220/220.
- `AuraSTTTests` 19/19 in the default configuration — the live speech suite is gated behind
  `AURA_ENABLE_LIVE_SPEECH_TESTS=1` and disabled by default, so it does not affect the sweep.
- second-pass, repo-hygiene, and supply-chain validators pass.

## Scope and limitations

- No live-model inference and no live-voice recognition was performed for this record. The UI was
  not exercised by launching the app; SwiftUI view code is covered only by compilation and by the
  existing state-level tests, which assert `ProductUIState`/`AuraAppModel` rather than rendering.
- Visual result has not been confirmed against a running window in this session.

## Verdict

`RISK-SP-003-NLU-DOWNGRADE-VARIANCE` closed. `RISK-SP-003-LIVE-VOICE-RESIDUAL` narrowed to a
packaging blocker and left open. UI reworked with accessibility preserved. No live-model or
live-voice run is claimed by this record.
