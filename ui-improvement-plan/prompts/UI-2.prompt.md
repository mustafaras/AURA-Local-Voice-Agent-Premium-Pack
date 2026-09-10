---
id: UI-2
sequence: 2
track: UI
depends_on: UI-1
next_prompt: UI-3
state: pending
design_docs: 03-live-status-feedback, 11-motion-system (§3-6), 13-advanced-surfaces (§4)
---

# UI-2 — Live Status Feedback

## Mission

Wire real events into visible feedback: animated pill transitions with the motion vocabulary, listening pulse from the real level, TTS-driven speaking indicator, emergency badge — the chrome becomes alive, causally.

## Read before acting (anti-amnesia context)

- CURRENT_PHASE + ledger tail + `00-working-protocol.md` §3–§5
- `03-live-status-feedback.md`, `11-motion-system.md` §3–§6, `13-advanced-surfaces.md` §4
- Code: `Sources/AURA/AuraAppModel_Runtime.swift` (TTS event handling), `AuraMenuView_Content.swift` (status pill), `AuraMenuBarPanel.swift`, `AuraOrb.swift` (from UI-1)
- Verified baseline: `TTSStartedEvent`/`TTSStoppedEvent` exist on the bus; `AudioLevelBridge.inputLevel` exists from UI-1; `AuraDesign.Motion` tokens exist from UI-0; the five fail-closed confirmation paths are pinned by tests + live evidence EV-SP-030-20260831-R11-LIVE-GATE-02.

## Hard boundaries

- Scope guard (allowed files): `AuraAppModel*.swift` (TTS state only), `AuraMenuView_Content.swift`, `AuraMenuBarPanel.swift`, `AuraOrb.swift` (ring behaviors), integration tests, plan ledger. **Nothing else.**
- All five fail-closed paths (Settings close, window close, emergency stop, 60s expiry, supersession) re-verified unchanged.
- `isSpeakingResponse` derives ONLY from real `TTSStartedEvent`/`TTSStoppedEvent` — no synthetic equalizer in any demo path.
- Level stream stays transform-only; motion tokens carry all durations (no magic numbers); one choreography owner per moment (11 §3).
- Emergency control behavior + localization (F-005 class) untouched; color/motion never the only carrier (VoiceOver-first).

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G2-1 | Status pill transitions use `AuraDesign.Motion` tokens; one choreography owner per moment | view-construction tests; grep: no raw durations outside tokens |
| G2-2 | Listening pulse driven by real `AudioLevelBridge.inputLevel` — transform-only | unit test: zero `withAnimation` on the level stream; transform path tested |
| G2-3 | `@Published var isSpeakingResponse` from real TTS events; ≤ 3-bar equalizer from real TTS state; no synthetic source in demo paths | event-mapping unit tests; grep demo paths |
| G2-4 | Emergency badge: `emergent` motion, instant, one pulse, static under Reduce Motion; emergency-stop path untouched | emergency-control tests green unchanged |
| G2-5 | Confirmation card entrance per 11 §4 (sober, Deny-first tab order preserved); all five fail-closed paths re-verified | fail-closed test set green |
| G2-6 | Full verification loop + governance: suite green ×2–3; a11y IDs per contract; live driver leg; ADR + repo ledger + `CURRENT_STATE.md` | suite exit 0 ×2–3; artifacts in plan ledger |
| G2-7 | Machine coherence: validator OK, all gates `passed`, `awaiting-approval` | validator OK |

## Per-gate procedure

**G2-1:** replace instant status swaps in the pill with `AuraDesign.motion(.standard)` transitions; `smooth` for color shifts; verify no raw `withAnimation` duration strings remain in touched files (grep).

**G2-2:** listening pulse: scale/opacity from `inputLevel` via `transformEffect` only; paused when panel closed or tab not visible (11 §5 cadence rules); unit test asserts the transform path is the only consumer of the stream.

**G2-3:** app-model: subscribe TTS events → `isSpeakingResponse` toggle (nil-safe for text-only mode); equalizer bar onset uses `motion.snappy`, max 3 bars; grep proves no demo/mock path publishes a synthetic level.

**G2-4:** emergency badge state + `emergent` treatment; run the full emergency-control test set unchanged (a green suite with an edited emergency test is a defect — investigate, never adapt the test).

**G2-5:** confirmation card entrance uses `motion.emergent` (fast, sober, no bounce); first paint includes the tinted heading (`AuraMenuView.swift:24-27` prominence rule); Deny-first tab order verified live.

**G2-6/G2-7:** full loop + governance; validator.

## Evidence templates (minimum per SEQ entry)

- G2-1: grep output (zero raw durations) + view-construction test counts
- G2-2: test name + assertion (transform-only) + pass count
- G2-3: event-mapping test results (start/stop/text-only mode); grep output proving no synthetic source
- G2-4: emergency-control suite pass counts (unchanged test files, `git diff --stat` as proof)
- G2-5: fail-closed set pass counts; live tab-order check line
- G2-6/G2-7: rerun counts ×2–3, driver leg, ADR path, validator output

## Risks and rollback

| Risk | Mitigation |
| --- | --- |
| Motion on high-frequency signals costs frames | Transform-only + cadence caps (11 §5); live PTT acceptance |
| Fail-closed paths regress silently | The five paths re-run at G2-5 — same tests, unchanged |
| TTS state flicker (rapid start/stop) | Debounce equalizer onset, never the state itself; state remains truthful |

Rollback: motion adoption is per-chrome-element; revert view files; the app-model gains only `isSpeakingResponse` (independently revertible); fail-closed suites prove zero behavior drift.

## Session script (anti-amnesia)

1. Parallel reads (CURRENT_PHASE, ledger tail, this prompt, `03`/`11` docs, chrome files).
2. Validator; on FAIL repair first.
3. Restate: "Aktif faz UI-2; tamamlanan: [gates]; sıradaki kapı G2-N."
4. One gate per checkpoint.
5. On G2-7: `awaiting-approval`; ask *"Faz UI-2 tamamlandı; UI-3'e geçiş için onayınız?"*; **stop**.

## Cognitive completion gate (answer in ledger before awaiting-approval)

1. What exactly changed? (files + line ranges)
2. What evidence proves each gate?
3. What observation would falsify "live feedback wired"?
4. Why is UI-3 safe to start? (motion vocabulary in use; TTS state published; suite green)
5. What residual risk remains, and why is it outside UI-2?
