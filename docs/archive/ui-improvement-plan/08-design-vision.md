# UI-V: Design Vision — "The Instrument"

**Volume:** I — Identity & Foundations (this document and 09–13).
**Status:** Design proposal. Visual/design content is prescriptive direction; every implementation claim is grounded in the verified scan; every speculative element is marked *decision point* for its phase ADR.
**Priority:** The identity foundation (tokens v2, icon, motion/sound vocabulary) is **UI-0** — it precedes all five experience axes.

---

## 1. The problem with "nice"

The current surface is competent Apple-platform work: tokens, glass discipline, pinned accessibility. But nothing about it is *remembered*. There is no identity mark, no signature interaction, no moment a first-time user would describe to someone else. The verified inventory: no custom app icon exists at all (no `.icns` anywhere in the repo, no `CFBundleIconFile` in `Resources/AURA-Info.plist`, no icon step in `scripts/build-app-bundle.sh` — the Dock shows the default executable glyph), the header is a 34-pt rounded square with an SF Symbol, and every surface is a variation of `controlBackgroundColor` panels.

The brief this volume answers: **AURA should look like what it is — a precision, privacy-first, local voice intelligence instrument — designed to a standard that would be defensible on an Apple Design Award shortlist.** Scientific and science-fiction, but never cosplay: the futuristic language must be earned from the product's real signals (mic levels, TTS state, latency budgets, policy confirmations), which is exactly what this product already has and most "sci-fi UIs" do not.

## 2. Vision statement

> **AURA is an instrument, not a gadget.** It behaves like a calibrated scientific device: states are measured, never simulated; every luminous element is driven by a real signal; depth is physical, motion is causal, and silence is a designed state.

The name gives us the visual thesis for free: an **aura** is a luminous field surrounding a body. AURA's entire identity is *the state made visible as light around a core*. Listening, thinking, speaking, restricted, error — all become variations of one continuous object rather than scattered UI state.

## 3. Benchmark and reference set

| Reference | What we take | What we reject |
| --- | --- | --- |
| Apple HIG + Liquid Glass (the platform we ship on) | Material system, motion springs, Dynamic Type, icon variant system (light/dark/tinted) | Default-looking results; HIG is the floor, not the ceiling |
| Precision instruments (oscilloscopes, spectrographs, observatory consoles) | Monospaced measurements, tick scales, hairline grids, "data is the decoration" | Cluttered cockpit density; AURA is an instrument that stays calm |
| Apple Design Award winners (interaction & delight tier, recent years) | One signature interaction executed flawlessly everywhere; restraint | Feature-parody surfaces; ornament without function |
| Sci-fi interface canon (film-grade HUDs) | Depth, luminous cores, causal motion | Unreadable chrome, decoration without a data source — our honesty rules forbid it |
| High-end audio hardware (studio monitors, hi-fi front panels) | The waveform as brand geometry, machined surfaces, tactile feedback | Skeuomorphic knobs and leather |

The synthesis: **observatory glass** — dark, deep, optically clear surfaces with a single luminous core and instrument-grade measurement language.

## 4. Brand attributes (the words every design decision must survive)

1. **Local** — the light is *yours*; nothing leaves. Privacy is not a footnote, it is the aesthetic (the core glows, the cloud is absent).
2. **Calibrated** — numbers in monospace, states in tokens, no synthetic progress.
3. **Alive** — the core breathes with real input; stillness only when idle.
4. **Composed** — one thing moves at a time; motion is causal (a state changed), never ambient noise.
5. **Bilingual by design** — every instrument label carries full EN/TR; typographic identity must be as strong in Turkish as in English.

## 5. The four design pillars

### Pillar 1 — The Living Core

One signature element carries the whole identity: the **Aura Orb** — a layered luminous disc whose rings are driven by the product's real signals (defined fully in [13-advanced-surfaces.md](13-advanced-surfaces.md)):

- **Listening** → the outer ring is a live waveform of the actual mic level (`AudioLevelBridge`, UI-1).
- **Thinking** → a single arc orbits the core (real `.thinking` status; no spinner clichés).
- **Speaking** → the ring becomes a slow spectral equalizer driven by real TTS state (UI-2).
- **Restricted** → the ring cools to a single amber segment with the reason text beside it.
- **Idle** → the core rests at minimum luminance — stillness is designed, not default.

The Orb is *the* identity mark: it reappears as the app icon (Dock), the menu bar glyph, the header identity mark, and the onboarding signature. One geometry, five scales, one behavior family.

### Pillar 2 — Precision Instrument

- All quantitative readouts (latency percentiles, task percentages, memory confidence, sample counts) render in a **monospaced numeric style** so digits do not dance (`AuraDesign.Typography` v2 extension; the existing pinned tokens are *extended*, never mutated — see [09 §3](09-visual-language.md)).
- Critical surfaces carry **measurement grammar**: hairline tick scales on gauges, corner index marks on panels ("instrument brackets"), aligned baselines.
- The Recovery tab graduates into a **telemetry deck** (UI-3 §4.3 + [13 §5](13-advanced-surfaces.md)): budget thresholds drawn as actual scale marks, breach markers visible, mock-derived samples carrying their orange flag.

### Pillar 3 — Controlled Depth

- A four-level material ladder (base → panel → chrome glass → hero glass) with one light model, documented in [09 §4](09-visual-language.md). Depth is earned by information hierarchy, not by stacking blur.
- Glass morphing (`GlassEffectContainer`, already in the codebase at `AuraMenuBarPanel.swift:25`, `AuraMenuView_Content.swift:269`) becomes the transition language: chrome *morphs* between states rather than crossfading (pill → orb, composer → listening bar).

### Pillar 4 — Quiet Authority

- Emergency stop and confirmation challenges are the two loudest moments in the product and they get the most restrained treatment: full-strength amber/red semantics, zero ornament, instant under Reduce Motion. Authority is calm.
- Sound design (if adopted, [12-sound-design.md](12-sound-design.md)) follows the same rule: a single soft glassy grain, ≤250 ms, never melodic, always paired with a visible state change.

## 6. What "international standards" concretely means here

| Standard | How the plan meets it |
| --- | --- |
| WCAG 2.2 AA (and the repo's stronger existing rules: color-never-alone, Dynamic Type, VoiceOver-first labels) | Every v2 token ships with a contrast validation step ([09 §6](09-visual-language.md)); the existing pinned tests keep enforcing |
| Apple HIG / Liquid Glass guidance | The material ladder is derived from Apple's own anti-pattern list (`AuraDesign.swift:57-61` already cites it) |
| Apple Design Award criteria (interaction, innovation, inclusion, visual craft) | Signature interaction (Orb), innovation (honest signal-driven futurism), inclusion (Reduce Motion/VoiceOver mapped for every effect) |
| Design-engineering traceability | Every visual rule lands as a token or test; the repo's ADR/ledger discipline applies to design decisions like any other |

## 7. What changes, what does not

- **Changes:** icon identity (from zero), color/material/typography vocabulary (v2 extension), motion and sound vocabulary, hero components, chrome transitions.
- **Does not change:** any pinned accessibility identifier, any fail-closed confirmation path, any honesty rule, any behavior behind a control, `AuraCopy` governance (it *grows*), the reducer-owned UI state machine.

## 8. Volume I document map

| Doc | Scope |
| --- | --- |
| [09-visual-language.md](09-visual-language.md) | Tokens v2: color system, materials ladder, typography extension, precision grammar, data-viz palette |
| [10-icon-identity.md](10-icon-identity.md) | App/Dock icon (from zero, with the verified asset-pipeline gap), menu bar glyph, in-app identity mark |
| [11-motion-system.md](11-motion-system.md) | Motion vocabulary, state choreography, performance budgets, Reduce Motion mapping |
| [12-sound-design.md](12-sound-design.md) | Sonic identity, earcon set, integration and accessibility constraints |
| [13-advanced-surfaces.md](13-advanced-surfaces.md) | Aura Orb, ambient canvas, command palette, telemetry deck, glass morphing |
