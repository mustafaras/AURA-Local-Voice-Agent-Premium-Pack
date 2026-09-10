---
id: UI-1
sequence: 1
track: UI
depends_on: UI-0
next_prompt: UI-2
state: pending
design_docs: 01-conversation-experience, 13-advanced-surfaces (§1-2, §4)
---

# UI-1 — Conversation Experience

## Mission

Rebuild the conversation surface: markdown rendering, live draft bubble, honest auto-scroll, thinking placeholder, the shared **`AudioLevelBridge`**, and the **Aura Orb + ambient canvas**. Highest user-time surface; strongest test protection; produces the level bridge UI-2 consumes.

## Read before acting (anti-amnesia context — full re-read after every compaction)

- `ui-improvement-plan/ledger/CURRENT_PHASE.md` + ledger tail + `00-working-protocol.md` §3–§5
- `01-conversation-experience.md`, `13-advanced-surfaces.md` §1–§2/§4, `09-visual-language.md` §4 (materials ladder)
- Code: `Sources/AURA/AuraAppModel_Runtime.swift:240-274` (event handling), `Sources/AURA/AudioSampleBridge.swift:19-67` (bridge model), `Sources/AURA/AuraMenuView_Content.swift` (conversation + composer), `AudioEventPayloads_AudioFrameEvent.swift:4-28` (`AudioFrameEvent`), `AuraAudio_Capture.swift:132-146` (`AuraAudio.frame(sequenceIndex:)`)
- Tests: copy-table guard, view-construction suites, `R9ProductUIStateTests.swift:435-450` (typography pin)

## Hard boundaries

- Scope guard (allowed files): `AuraAppModel*.swift` (draft + level state only), `AudioLevelBridge.swift` (new), `AuraMenuView_Content.swift`, `AuraOrb.swift` (new), integration tests, plan ledger. **Nothing else — anything else is scope creep = defect.**
- Transcript data structure unchanged (rendering evolution only).
- No token streaming (out of scope per 06 §8); no synthetic waveform anywhere.
- Level stream: transform-only rendering — never `withAnimation` on `inputLevel` (11 §5).
- Typography tokens extended, never mutated; no literals outside `AuraDesign`; every user-facing string via `AuraCopy` (real Turkish or nothing).
- Tests only via `./scripts/aura-test.sh` (2–3×, grep never tail); no commit/push without go-ahead.

**Verified baseline:** no per-frame level event exists — raw 16 kHz mono samples via `AudioFrameEvent` + `AuraAudio.frame(sequenceIndex:)`; VAD computes RMS→dBFS internally (`VoiceActivityDetector.swift:114-115`); replies arrive as atomic `ResponsePlanEvent.summary` (Ollama client has no streaming); conversation capped at 40 messages; a11y identifiers unique/never-localized via `AuraAccessibilityID` (`AuraAccessibilityIdentifiers.swift:8-82`).

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G1-1 | `AudioLevelBridge` (new file, modeled on `AudioSampleBridge`): subscribes `AudioFrameEvent`, fetches via `AuraAudio.frame(sequenceIndex:)`, throttled 15–30 Hz, `@Published var inputLevel: Double?` nil-when-not-listening; scalar only, no persistence/logging | unit tests: throttle cadence, nil-when-not-listening, scalar-only (no ring buffer of samples held) |
| G1-2 | Markdown rendering: `AttributedString(.inlineOnlyPreservingWhitespaces)` primary path, plain-text fallback; inline-only verified (no block semantics) | unit tests: bold/italic/code/links render; malformed input falls back to plain text |
| G1-3 | Draft bubble: partial transcript as draft in the stream; single combined a11y element announcing "draft: [text]" via new `a11y.draftPrefix` copy key (real EN/TR) | copy guard green; a11y label test |
| G1-4 | Auto-scroll: `ScrollViewReader` stick-to-bottom + jump-to-latest; honest (no auto-scroll while user is scrolled up) | view-construction test; live driver check |
| G1-5 | Thinking placeholder in transcript (copy keys EN/TR, copy guard green) | copy-guard test green |
| G1-6 | Orb component `AuraOrb.swift`: Canvas-based; inputs `status` / `inputLevel: Double?` / `isSpeakingResponse`; state→layer mapping as pure logic; honesty contract (no synthetic data drives any layer) | state-mapping unit tests green |
| G1-7 | Ambient canvas: conversation surface on observatory canvas + L1 panels + instrument spacing; transcript data structure unchanged | full suite green; view-construction tests pass |
| G1-8 | Full verification loop + governance: suite green ×2–3; a11y identifiers per the ID contract for every new control; live AppleScript driver leg for touched surfaces; ADR + `ledger/PROJECT_LEDGER.md` append + `CURRENT_STATE.md` atomic rewrite | suite exit 0 ×2–3; governance artifacts recorded in plan ledger |
| G1-9 | Machine coherence: validator exit 0, all UI-1 gates `passed`, `phase_status: awaiting-approval` | validator OK |

## Per-gate procedure

**G1-1 (AudioLevelBridge):**

1. New file `Sources/AURA/AudioLevelBridge.swift` mirroring `AudioSampleBridge`'s structure (`AudioSampleBridge.swift:19-67`): @MainActor ObservableObject; bus subscription in init; `deinit` unsubscribe.
2. On `AudioFrameEvent`: throttle to 15–30 Hz (named constant, e.g. `levelRefreshInterval`); fetch `AuraAudio.frame(sequenceIndex:)`; compute scalar RMS→dBFS the same way VAD does; normalize to 0…1 for display; publish `@Published var inputLevel: Double?`.
3. Publish `nil` when capture is not active (honest idle); no sample buffering beyond the scalar; no persistence; no logging.
4. Tests: throttle cadence (event count → publish count), nil-when-not-listening, scalar-only shape. Name the file to match the integration test target layout.

**G1-2 (markdown):** primary path `AttributedString(markdown, options: .inlineOnlyPreservingWhitespaces)`; on throw, render raw text verbatim (never drop content); test bold/italic/inline-code/links + malformed markdown fallback.

**G1-3 (draft bubble):** distinct draft styling; single a11y element with prefix label from new copy key (e.g. `aura.copy.draftPrefix` = "Draft: " / "Taslak: "); draft updates in place (no re-entry animation per 11 §4).

**G1-4 (auto-scroll):** stick-to-bottom tracking; jump-to-latest affordance when user scrolls up; never scroll while user reads history; live driver leg verifies both.

**G1-5:** thinking placeholder row driven by the real `.thinking` status — no spinner cliché; copy keys EN/TR.

**G1-6 (Orb):** `AuraOrb` view; inputs: `status`, `inputLevel: Double?`, `isSpeakingResponse`; Canvas-based ring/core/field; state→layer mapping as pure logic extracted for testing; listening ring = live waveform arc of the real level (transform-only); thinking = orbiting arc; speaking = ≤ 3-bar equalizer from real TTS state; restricted = amber segment + reason text; error = red segment; idle = rest luminance. Under Reduce Motion: still readout, never blank (11 §6).

**G1-7 (ambient canvas):** conversation surface on `palette.void` + L1 panels per the materials ladder; instrument spacing from `AuraDesign` tokens only; transcript data structure untouched.

**G1-8:** full suite ×2–3; new controls get `AuraAccessibilityID` entries (unique, never localized, capability-ID-derived); AppleScript driver leg for conversation surface; ADR + repo ledger + `CURRENT_STATE.md`.

## Evidence templates (minimum per SEQ entry)

- G1-1: bridge file path + test names + pass counts; throttle numbers used
- G1-2/G1-3/G1-5: test names + pass counts; copy key names added (EN/TR)
- G1-4: driver leg output line for auto-scroll behavior
- G1-6: state→layer test matrix results (all 6 statuses)
- G1-7: suite pass counts
- G1-8: rerun counts ×2–3, driver leg evidence, ADR path, ledger line range
- G1-9: validator output

## Risks and rollback

| Risk | Mitigation |
| --- | --- |
| Level bridge widens the shared bus contract | Read-only subscriber over existing `AudioFrameEvent` — zero writes to the bus |
| Markdown renderer edge cases (block syntax artifacts) | Fallback path is the pinned test case; never drop content |
| Auto-scroll fights user scrolling | Stick-to-bottom only when already at bottom; live check |
| Orb performance on the 15–30 Hz stream | Transform-only rendering; budget per 11 §5; live PTT turn acceptance |

Rollback: bridge is additive (delete file + tests); view changes revert per-file; transcript state machine untouched, so reducer tests prove no behavior drift.

## Session script (anti-amnesia)

1. Parallel reads: CURRENT_PHASE + ledger tail + this prompt + `01`/`13` docs + target code files.
2. `bash ui-improvement-plan/validate-continuity.sh`; on FAIL repair the machine first.
3. Restate aloud: "Aktif faz UI-1; tamamlanan: [gates]; sıradaki kapı G1-N."
4. One gate per checkpoint (SEQ + CURRENT_PHASE rewrite).
5. On G1-9: `awaiting-approval`; ask *"Faz UI-1 tamamlandı; UI-2'ye geçiş için onayınız?"*; **stop**.

## Cognitive completion gate (answer in ledger before awaiting-approval)

1. What exactly changed? (files + line ranges)
2. What evidence proves each gate?
3. What observation would falsify "conversation experience rebuilt"?
4. Why is UI-2 safe to start? (bridge exists and is tested; suite green; chrome untouched by UI-1 beyond composer)
5. What residual risk remains, and why is it outside UI-1?
