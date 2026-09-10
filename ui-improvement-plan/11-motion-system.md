# UI-V: Motion System

**Volume:** I — Identity & Foundations.
**Status:** Design proposal. Extends (does not replace) the transition rules proposed in UI-2 ([03-live-status-feedback.md](03-live-status-feedback.md)); UI-2 remains the *experience* phase that wires real events — this document defines the vocabulary those transitions use.
**Implements:** Design Vision Pillars 1 and 4.

---

## 1. Current state (verified)

Motion today is effectively absent: status changes are instant swaps (no animation anywhere in `AuraDesign.swift` or the views); the only dynamic elements are SwiftUI defaults (button presses, sheet presentation). The glass containers (`GlassEffectContainer` at `AuraMenuBarPanel.swift:25`, `AuraMenuView_Content.swift:132,269`) already hold the morphing capability the platform provides — unused for transitions.

## 2. Philosophy: causal motion

Every animation must answer "what physical thing happened?" before it plays:

- A **state changed** (status, task state, confirmation appearance) → the change animates once, causally.
- A **value updated** (level, latency, progress) → the value *is* the animation (transform-driven, continuous); no decorative loop is added on top.
- **Nothing else animates.** No ambient particles, no idle pulses, no login-screen drift. An instrument at rest is at rest — the designed stillness of [08 §5 Pillar 1](08-design-vision.md).

This single rule is what separates AURA's futurism from screensaver futurism, and it is also what keeps the honesty rules ([06 §5](06-cross-cutting-constraints.md)) intact under motion.

## 3. Motion vocabulary (`AuraDesign.Motion`)

| Token | Definition | Used for |
| --- | --- | --- |
| `motion.standard` | spring, ≈350 ms duration, low bounce (0.15–0.2) | Status transitions, panel entrance, Orb state morphs |
| `motion.snappy` | spring, ≈200 ms, higher bounce | Controls: buttons, toggles, tab selection |
| `motion.smooth` | ease-in-out, ≈250 ms | Color/fill changes, crossfades, glass tint shifts |
| `motion.emergent` | ≈150 ms, no bounce | *Destructive-critical only*: emergency stop, confirmation cards — fast, sober, no bounce |
| `motion.stagger` | 40 ms per element, max 3 elements | List/card entrance on tab switch |

Rules: durations live in tokens (no magic numbers — the repo's own code-smell rule); only springs for geometry, only eases for color; **one choreography owner per moment** (the largest state change wins; subordinate elements follow, never lead).

## 4. State choreography table

The single table that maps every runtime state change to its motion treatment (consumed by UI-1, UI-2, UI-3):

| Transition | Motion | Notes |
| --- | --- | --- |
| idle → listening | Orb ring expands from core with `standard`; composer morphs the Push-to-Talk glass into the listening bar (`GlassEffectContainer` morph) | Driven by real status + real `inputLevel` |
| listening → thinking | Listening ring collapses; thinking arc fades in orbiting with `smooth` | No spinner; the arc *is* the thinking state |
| thinking → speaking | Arc resolves into the answer bubble (`standard`); TTS equalizer bars rise with `snappy` per bar, max 3 | Driven by `TTSStartedEvent` (UI-2) |
| any → restricted | Ring cools to amber segment with `smooth`; reason text appears (never color alone) | Uses existing reason strings |
| any → error | Ring snaps to critical red with `emergent`; message appears immediately, no motion delay | Errors never wait for animation |
| emergency stop activated | `emergent` — badge appears instantly, one single pulse, then static | The only permitted pulse; static under Reduce Motion |
| confirmation card appears | Sheet-like rise with `standard`, tinted heading present at first paint (the card's prominence rule, `AuraMenuView.swift:24-27`) | Never blocks the Deny-first tab order |
| tab switch | Content crossfade `smooth` + `stagger` entrance, 3 elements max | Under Reduce Motion: crossfade only |
| message arrival | New bubble rises 8 pt with `snappy`; draft bubble updates in place (no re-entry animation on text updates) | Auto-scroll behavior owned by UI-1 |

## 5. Performance budget

- **Never animate on the `inputLevel` stream** (15–30 Hz updates): level drives `transformEffect`/scale — a render-only path — never layout, never `withAnimation`.
- Equalizer/waveform frame cadence capped (≈30 fps via `TimelineView`); pause when the surface is not visible (menu bar panel closed, tab not selected).
- Blur count per viewport ≤ 3 live glass surfaces (existing discipline: pill, tab bar, composer — the Orb's hero glass replaces, never adds a fourth live blur in the same window).
- Budget check on the acceptance gate: no frame drop during a live PTT turn on the reference machine, verified live per phase.

## 6. Reduce Motion and accessibility mapping

- `AuraDesign.motion(_:)` helper (proposed in UI-2 §4.5) returns `nil` under `accessibilityReduceMotion`; every token in §3 routes through it.
- Under Reduce Motion: springs → instant state change; arcs/equalizers → static final-state rendering; the Orb renders its current state as a **still instrument readout** (ring position + text), never blank.
- VoiceOver: no motion carries information not already in labels/traits (the existing color-never-alone rule extended to motion-never-alone); announced state text is unchanged by any animation.

## 7. Files to touch

| File | Change |
| --- | --- |
| `AuraDesign.swift` | `Motion` namespace (§3), `motion(_:)` helper |
| All view files | Adopt tokens per the §4 choreography during their owning phases |
| `R9ProductUIStateTests.swift` | Extended: token existence; motion tokens return nil under reduced-motion environment in view-construction paths |

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| Motion system becomes an ornament source | §2 causal rule is review-enforced; every animation in review must name its physical cause |
| Glass morphing API edge cases (merging shapes across containers) | Morphs stay within one `GlassEffectContainer` (platform contract, already followed at `AuraMenuView_Content.swift:269`); fallback to crossfade on any merge artifact |
| Performance regression on older hardware | Budget §5 with a live PTT turn as the phase acceptance scenario |
