# UI-V: Advanced Surfaces — The Orb, Ambient Canvas, Command Palette, Telemetry Deck

**Volume:** I — Identity & Foundations.
**Status:** Design proposal. This document specifies the four hero surfaces that carry the identity; each is built *during* an experience phase (UI-1/2/3) that owns its data, not as a separate phase. The Orb is the one exception — it is the identity proof, spec'd here as the component every other document references.
**Implements:** Design Vision Pillars 1, 2, 3 ([08-design-vision.md](08-design-vision.md)).

---

## 1. The Aura Orb (the signature component)

The single element the whole identity rests on. One geometry, driven entirely by real signals — the honest-futurism thesis made visible.

### 1.1 Anatomy

| Layer | Element | Source of truth |
| --- | --- | --- |
| Core | luminous disc, `palette.biolume` gradient, minimum-luminance at rest | status color map |
| Inner ring | hairline separator between core and field | static (the "calibration" line) |
| Outer ring | state-dependent instrument readout (§1.2) | real signals only |
| Field | faint radial gradient (the "aura") | opacity follows level when listening; fixed otherwise |

No synthetic data may ever drive any layer (honesty rule, [06 §5](06-cross-cutting-constraints.md)). The Orb's entire contract is: **what it shows is what is happening.**

### 1.2 State behavior (the ring is the instrument)

| Status | Outer ring | Motion token |
| --- | --- | --- |
| idle | hairline ring, core at rest luminance | — |
| listening | live waveform arc driven by `AudioLevelBridge.inputLevel` — the ring *is* the mic meter | transform-only (11 §5) |
| thinking | single arc orbiting the core, constant angular velocity | `smooth` in, continuous rotation at ≤ 30 fps |
| speaking | slow spectral equalizer (3 bars max) driven by real TTS state | `snappy` per bar onset |
| restricted | ring collapses to a single amber segment + reason text beside the Orb | `smooth` |
| error | critical red segment, full opacity, no pulse | `emergent` |

### 1.3 Scales (one geometry, five homes)

Dock icon ([10-icon-identity.md](10-icon-identity.md)) → header identity mark (34 pt, static) → panel hero (~120–160 pt, full behavior) → onboarding signature (hero, animated) → **never** as a tiny chrome glyph (the menu bar stays status-symbol-driven; an 18 pt Orb would lose the ring detail and the mark dies — this is the explicit boundary of the family).

### 1.4 Implementation shape

`AuraOrb` in `Sources/AURA/` (new view file), `Canvas`-based (vector rendering, no blur cost at the ring layer; the core uses one `materials.hero` glass surface). Inputs: `status`, `inputLevel: Double?`, `isSpeakingResponse`. Reducer-owned status only — the Orb never computes state itself. Testable: state→layer mapping as pure logic; snapshot-friendly because every layer derives from deterministic inputs.

## 2. Ambient conversation canvas (UI-1 surface upgrade)

The conversation view becomes the Orb's home: the Orb sits at the head of the transcript as the conversation's living core; bubbles render on the observatory canvas (`palette.void` base, L1 panels) with instrument spacing. The transcript remains the same data structure (`transcript` entries) — this is a rendering evolution, not a data change. The draft bubble (partial transcript) sits *under* the Orb like a specimen being examined — the sci-fi moment that is also completely literal: it shows what the model is actually receiving.

## 3. Command palette (⌘K)

A keyboard-first surface for power users, consistent with the app's existing keyboard discipline:

- Scope: tab navigation, push-to-talk toggle, settings open, emergency stop (with its existing fail-closed confirmation — the palette *opens* the same confirmation card, it never shortcuts it), copy transcript, clear composer.
- Implementation: a new `AuraCommandPalette` view over `GlassEffectContainer` (L3), opened via `.keyboardShortcut("k", modifiers: .command)`; entries are a static table — no fuzzy-search dependency, no new subsystem. Identifiers follow the accessibility-ID contract so the AppleScript driver can exercise it.
- Deliberately **excluded**: arbitrary settings mutation (the confirmation card path stays canonical), anything touching voice pipeline state directly.
- Acceptance: full keyboard-only walkthrough live; Escape/Cancel behavior fail-closed-tested like every dismissal path.

## 4. Glass morphing (the transition language)

`GlassEffectContainer` (already used at `AuraMenuBarPanel.swift:25`, `AuraMenuView_Content.swift:132,269`) becomes the way chrome *changes shape* rather than crossfades:

| Morph | From → To | Owner phase |
| --- | --- | --- |
| Composer morph | Push-to-Talk glass pill → listening bar with waveform | UI-1 |
| Pill morph | status pill → emergency badge state | UI-2 |
| Panel morph | menu bar panel content between tabs (shared chrome) | UI-3 |

Rule (from [11 §3](11-motion-system.md)): morphs stay within one `GlassEffectContainer`; any cross-container merge artifact falls back to a `smooth` crossfade. Glass never contains more than 3 live blurred surfaces per window (performance budget).

## 5. Telemetry deck (Recovery tab evolution, UI-3)

The Recovery tab graduates from a list into the instrument surface Pillar 2 promises:

- Latency percentiles rendered as **gauge scales** with hairline ticks (`Measure.tickMajor/tickMinor`), budget thresholds as dashed `cautious` reference lines with text labels — the pull-only `LatencyPercentileSummary` data already in the model, now drawn as an instrument instead of text.
- Breach markers: budget breaches appear as tick marks on the scale (color + marker shape — never color alone).
- Mock-derived samples carry their existing orange flag *and* a text annotation (honesty rule: provenance is always visible).
- Sparklines use the data-viz palette ([09 §7](09-visual-language.md)); monospaced numerals throughout ([09 §5.1](09-visual-language.md)).
- No new event plumbing: everything on this deck reads from state that already exists; the optional `LatencySampleEvent` extension remains the recorded decision point from UI-3.

## 6. What is deliberately NOT here

- **No ambient/particle backgrounds, no aurora animations** — decoration without a signal violates the causal-motion rule ([11 §2](11-motion-system.md)).
- **No custom window chrome / transparent title bars** — fragile, accessibility-hostile, and against the native-feeling principle.
- **No 3D/metal scenes** — the Orb is 2D vector glass; Metal adds build complexity for zero signal honesty.
- **No HUD overlays on other apps** — AURA is an instrument on your desktop, not an overlay on your life.

## 7. Files to touch

| File | Change |
| --- | --- |
| `Sources/AURA/AuraOrb.swift` | New: the Orb (§1) |
| `Sources/AURA/AuraCommandPalette.swift` | New: ⌘K surface (§3) |
| `AuraMenuView_Content.swift` | Conversation canvas (§2), composer morph (§4) |
| `AuraMenuView_Tabs.swift` | Recovery → telemetry deck (§5) |
| `R9ProductUIStateTests.swift` / integration tests | Orb state-mapping tests; palette keyboard-traversal and fail-closed tests |

## 8. Risks

| Risk | Mitigation |
| --- | --- |
| The Orb becomes a decorative gimmick | Its contract is signals-only (§1.1); every layer names its data source in review |
| ⌘K palette drifts into a settings bypass | Static entry table; confirmation paths remain canonical (§3) |
| Canvas-based Orb rendering cost | Canvas draws are vector/cheap; per-state acceptance on the reference machine; Reduce Motion renders the still readout |
| Telemetry deck implies new data collection | Explicitly reads existing state only; the sampling event stays a decision point, default no |
