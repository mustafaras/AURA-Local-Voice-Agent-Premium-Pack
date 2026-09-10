# UI-2: Live Status Feedback

**Priority:** P2 (second implementation phase, sequenced as UI-2).
**Surfaces touched:** `AuraDesign.swift` (`AuraStatusPill`, new animation helpers), `AuraMenuBarPanel.swift`, `AuraMenuView_Content.swift` (header), `AuraAppModel_Runtime.swift` (TTS event wiring).
**Depends on:** `AudioLevelBridge` from UI-1 (reused for the listening pulse). If UI-2 were built before UI-1, the bridge lands here instead — it is the phase's only new plumbing.

---

## 1. Current state (verified)

- Runtime status surfaces in three places: the header icon-in-disc, the glass status pill (tinted by `AuraDesign.statusColor`, `AuraDesign.swift:74-124`), and the `MenuBarExtra` label (`AURA.swift:33-38`). All change instantly with no transition; nothing animates.
- The app model never subscribes to TTS events directly — speaking state reaches it indirectly through `ConversationStateEvent` → `applyConversationState` (`AuraAppModel_Runtime.swift:227-238`). `TTSStartedEvent`/`TTSStoppedEvent` (with prompt IDs and stop reasons) exist on the bus (`AudioEventPayloads_TTSStartedEvent.swift`, `AudioEventPayloads_TTSStoppedEvent.swift`).
- The mic waveform (post UI-1) animates only in the composer; the menu bar panel shows none.
- Emergency stop flips a text label and disables the mic button (`AuraMenuBarPanel.swift:47-51`, `AuraMenuView_Content.swift:305`); there is no strong visual state change.
- No view currently consults `accessibilityReduceMotion`.

## 2. Goals

1. Status changes are *felt* — smooth color/label transitions instead of hard swaps — while never carrying meaning by color or motion alone (existing a11y discipline, `AuraDesign.swift:86-90`).
2. Speaking and listening states are embodied: breathing pulse while listening (level-driven), gentle equalizer while speaking (TTS-event-driven).
3. The emergency-stop state is unmistakable at a glance, in every surface, without motion.
4. All motion respects Reduce Motion and has zero information monopoly.

## 3. Non-goals

- Any new status semantics or new `AuraAppStatus` cases.
- Synthetic animation when real signals are absent (honesty rule): no equalizer animation unless a real `TTSStartedEvent` is active; no waveform without real mic levels (`AURA_TEXT_DEMO_SCRIPT` renders none).
- Menu bar panel scope expansion (stays the documented compact summary).

## 4. Proposed design

### 4.1 Status transitions

- Wrap status-pill content changes in `.animation(.snappy, value: model.status)` with `@ViewBuilder` transitions (opacity + slight scale, 150–250 ms) so color, symbol, and detail text crossfade instead of popping.
- Header icon-disc gets the same treatment; the disc's tint follows `AuraDesign.statusColor` with animation on the `Color` value.
- The `MenuBarExtra` label symbol updates remain instant (menu bar extras re-render cheaply; animation there is not worth the flicker risk).

### 4.2 Listening pulse (reuses UI-1 `AudioLevelBridge`)

- The status pill's leading dot and the header disc gently scale with `model.inputLevel` while `.listening` (transform effect on the 7-pt dot, subtle 0.9–1.15× range), in addition to the composer waveform from UI-1.
- Menu bar panel: reuse the same `AuraLevelMeter` component inline under the status pill while listening — the panel is where a user glances when a voice interaction starts away from the main window.

### 4.3 Speaking equalizer

- Subscribe to `TTSStartedEvent`/`TTSStoppedEvent` in `AuraAppModel_Runtime` (alongside the existing `ConversationStateEvent` subscription): `@Published var isSpeakingResponse = false`, set true on start, false on any stop reason.
- While true, render a small 3-bar equalizer animation beside the status pill's title (pure SwiftUI `TimelineView` or phase animator), `accessibilityHidden`, with the speaking state still carried by the pill's text and color.
- Stop-reason honesty: if the stop reason is a failure (`TTSStopReason` failure case), route through the existing error rendering rather than quietly animating back to idle.

### 4.4 Emergency-stop presence

- When `emergencyStopActive`: status pill region shows a persistent amber `hand.raised` badge (color + symbol + text — never color alone); the main window header disc switches to the same treatment; the menu bar panel's existing label gains the same badge.
- Add one gentle attention animation (single pulse on transition, not looping) — loops only if Reduce Motion is off, and the state is fully static when Reduce Motion is on.
- Every element keeps or gains text; no meaning is carried by motion or color alone (F-005 discipline).

### 4.5 Reduce Motion compliance

- A single helper `AuraDesign.motion(_ base: Animation)` returning `nil` when `@Environment(\.accessibilityReduceMotion)` is on; all new animations route through it. Status changes remain instant under Reduce Motion; equalizer/waveform render as static bars in their last real state.

## 5. Files to touch

| File | Change |
| --- | --- |
| `AuraDesign.swift` | `motion(_:)` helper; `AuraEqualizer`; status transition modifiers; amber emergency badge component |
| `AuraAppModel.swift` / `_Runtime.swift` | `isSpeakingResponse` publication; TTS event subscription; `inputLevel` reuse |
| `AuraMenuView_Content.swift` | Header disc transitions; emergency badge in main window |
| `AuraMenuBarPanel.swift` | Inline level meter; emergency badge |
| `ProductUIState.swift` | New copy keys if any new labeled text appears (keep minimal; reuse existing status copy) |

## 6. Testing and acceptance

- New unit tests: TTS event wiring (start sets flag; every stop reason clears it; failure surfaces error state), Reduce Motion helper returns no animation when the trait is set.
- View-construction suite extended (`R9ProductUIStateTests.swift:388-433` pattern); existing status-pill accessibility labels must pass unchanged.
- Live acceptance: manual observation recorded in the ledger — pill transitions, listening pulse during a real PTT turn, speaking equalizer during a real TTS turn, emergency-stop badge in all three surfaces, Reduce Motion on/off.
- Full suite via `./scripts/aura-test.sh`, rerun 2–3×.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Animation on `@Published` churn causes re-render cost | Animate only on status/flag *values*, not on high-frequency `inputLevel` (level drives transform effect, which is render-only) |
| Equalizer reads as "recording" | Only paired with TTS state; listening uses the waveform metaphor; both labeled by adjacent text |
| MenuBarExtra label flicker on rapid status changes | No animation in the menu bar label itself (§4.1) |
