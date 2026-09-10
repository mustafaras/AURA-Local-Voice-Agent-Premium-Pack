# ADR-057: UI-0 Identity Foundation — owned palette, Iris icon, motion gate, sound scaffold

- Status: Accepted
- Date: 2026-09-10
- Owners: AURA owner (UI plan UI-0)
- Supersedes: none
- Superseded by: none

## Context

The UI improvement plan (`ui-improvement-plan/`) opens with UI-0, the identity
foundation every later phase consumes. Three independent decisions were folded
into one phase by design (highest-visibility, zero-behavior-risk first):

1. **Icon gap (verified):** the app shipped with no `.icns`, no
   `CFBundleIconFile`, and no icon step in `build-app-bundle.sh` — the app
   showed the generic executable glyph in Dock/App Switcher/About
   (10-icon-identity.md §1).
2. **No owned chroma:** every color came from semantic system colors
   (`AuraDesign` v1), so the product read "generic macOS" and had no dark/light
   *strategy* (09-visual-language.md §1).
3. **Motion effectively absent; sound undecided:** status changes were instant
   swaps; sound adoption is a product decision that needed a recorded verdict
   (12-sound-design.md §8).

## Decision

- **Iris icon, generator-owned:** three SVG masters (`iris-dark` canonical,
  `iris-light`, `iris-tinted`) in `Resources/brand/`; the only path to
  `Resources/AURA.icns` is `scripts/generate-app-icon.sh` (renderer chain
  `rsvg-convert` → `qlmanage`+`sips`; PNGs never committed). Wired via
  `CFBundleIconFile = AURA` + one copy line at `build-app-bundle.sh:92`.
  Light/tinted variants are produced by the same masters; asset-catalog
  variant adoption (per-appearance `.icns` swapping) is deferred — the
  single-file `CFBundleIconFile` path ships the canonical dark icon first.
- **Owned palette "Observatory/Biolume", additive only:** `AuraDesign`
  gains `Palette`, `Materials`, `Measure`, `Motion` namespaces; the pinned
  `Typography` tokens are untouched (grep-count proof in the phase ledger).
  `statusColor(_:)` is remapped *in place* (idle/active → `biolume`,
  restricted → `cautious`, error → `critical`, neutral → `textTertiary`) so
  pill/badges/task rows change coherently in one place.
- **Accent split (09 §3.2):** brand surfaces (Orb, icon, identity marks, focus
  rings) use the owned biolume pair; **interactive control accents keep the
  system accent color** so AURA stays native. The two are never adjacent
  equals — biolume is luminous-on-dark, system accent follows the user theme.
- **Contrast gate as authority:** the WCAG unit gate (body ≥ 7:1, meta
  ≥ 4.5:1, graphical ≥ 3:1, both variants) adjusted token values, never
  thresholds: `textTertiary` 38% → 56% white, `cautious` light `#A66A08` →
  `#8A5606`. Future token changes must re-pass this gate.
- **Motion vocabulary with a hard accessibility gate:** `Motion` tokens
  (`standard/snappy/smooth/emergent/stagger`) exist, but every view routes
  through `AuraDesign.Motion.motion(_:)`, which returns `nil` under
  `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` (static-readout
  rule). Views referencing raw `Motion.*` are a review defect.
- **Sound: adopt-later.** The scaffold ships (default-off
  `soundFeedbackEnabled` preference, reducer-owned, persisted via
  `aura.ui.state`; EN/TR Settings copy stating honestly that no sounds play in
  this build), but no earcon channel, no `AuraEarconChannel`, no `.caf`
  assets, and no generator exist in this phase. The synthesized-set evaluation
  happens on the reference machine before any adoption commitment; if
  evaluation fails, the scaffold is inert by construction and costs nothing.
  The reject outcome remains open.

## Alternatives considered

- **Asset-catalog icon variants now** (per-appearance `.icns` via
  `.appiconset`): rejected for UI-0 — it changes the resource declaration
  shape and adds a build-system dependency for zero behavior gain; the
  generator keeps every future option open.
- **Owned accent for interactive controls too:** rejected — it abandons the
  native-feel guarantee (09 §3.2 decision point); system accent retained.
- **Adopt-now sound:** rejected — new sensory surface must be evaluated live
  with ears before shipping (12 §8); adopting blind contradicts the plan's
  honesty rules.
- **Lower contrast thresholds to keep the first token draft:** rejected —
  the gate's authority is the point; tokens were adjusted instead.

## Security and privacy impact

None. The icon is a static resource; tokens are presentation-only; the sound
preference stores a single boolean in the existing `aura.ui.state` UserDefaults
blob. No new data flows, permissions, or prompts. Reduce Motion remains
honored at the single gate point.

## Operational impact

- `scripts/generate-app-icon.sh` is a new deterministic generator (exit 0
  verified; deterministic re-runs; no hand-exported PNGs possible).
- `build-app-bundle.sh` gains one icon copy line; `--skip-update` added to its
  six swift build steps to avoid a Desktop File Provider TCC boundary failing
  dependency resolution (environment note in the phase ledger).
- Bundle size grows ~1.1 MB (the `.icns`).

## Migration

None required. `soundFeedbackEnabled` decodes to `false` for users with a
pre-existing `aura.ui.state` payload (Codable default on missing key). No
schema break; the added enum case is backward-compatible because the state is
decoded by key, not by case ordinality.

## Validation evidence

- G0-1: 3 masters + `AURA.icns` (1109018 bytes) + generator exit 0
  (`PHASE_LEDGER.md` SEQ-0004).
- G0-2: `CFBundleIconFile = AURA` (plutil grep), copy line at
  `build-app-bundle.sh:92`, codesign `--verify --deep --strict` OK on a fresh
  `BUILD_DIR=/tmp/aura-release-app` bundle (SEQ-0005).
- G0-3/3a: four enum greps; pinned typography counts identical before/after;
  build exit 0 (SEQ-0006).
- G0-4/4a/5: `AURAIntegrationTests` 136→137 tests, 25 suites, 0 failures,
  script exit 0 (SEQ-0007, SEQ-0008); contrast failures adjusted tokens;
  motion helper API verified from the installed SDK
  (`NSAccessibility.h:103`).
- G0-6: preference + copy keys + copy guard green (SEQ-0008).

## Consequences

- UI-1..UI-5 consume `Palette`/`Materials`/`Measure`/`Motion` vocabulary;
  every new literal outside `AuraDesign` is a review defect.
- Sound adoption (if pursued later) lands `AuraEarconChannel` +
  `scripts/generate-earcons.sh` under a separate ADR update; the preference
  and copy already exist.
- Per-appearance icon variants (light/tinted) remain a deliberate follow-up,
  gated on an asset-catalog migration decision.
- The Reduce Motion gate is the single choke point for the motion vocabulary
  — the choreography table (11-motion-system.md §4) is consumed by UI-1..UI-3
  through `Motion.motion(_:)`.