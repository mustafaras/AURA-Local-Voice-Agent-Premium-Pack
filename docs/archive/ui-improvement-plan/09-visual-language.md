# UI-V: Visual Language v2 — Tokens, Materials, Precision Grammar

**Volume:** I — Identity & Foundations.
**Status:** Design proposal; token names and values are the phase-UI-0 decision surface. All existing-code claims verified.
**Implements:** Design Vision Pillars 2 and 3 ([08-design-vision.md](08-design-vision.md)).

---

## 1. Current token inventory (verified)

`AuraDesign` today (`AuraDesign.swift:14-84`): 6 spacing steps, 4 radii, 5 typography tokens (all relative styles), one panel background, one status color map. Color comes almost entirely from **semantic system colors** (`controlBackgroundColor`, `separatorColor`, `.green/.orange/.red/.secondary`) — which is why the app reads "generic macOS": it has no owned chroma. There is no dark/light *strategy* (system colors follow the OS), no numeric typography, no measurement grammar.

Constraint to respect: `R9ProductUIStateTests.swift:435-450` pins the *current* five typography tokens to exact relative styles. **v2 extends the vocabulary; it never mutates pinned tokens.** If any existing token is repurposed, the test change is explicit, ADR-documented, and the old value's consumers are re-audited.

## 2. v2 token architecture

`AuraDesign` gains three new namespaces; nothing in `Spacing`/`Radius` changes:

```swift
enum AuraDesign {
  // existing: Spacing, Radius, Typography (pinned), panelBackground, statusColor

  enum Palette {      // owned color tokens (new)
  enum Materials {    // surface ladder (new)
  enum Motion {       // vocabulary shared with 11-motion-system.md (new)
  enum Measure {      // precision grammar constants (new)
}
```

Token rule: a view may reference `AuraDesign.*` only. Any new literal found in review is a defect (this formalizes the existing doc comment discipline, `AuraDesign.swift:3-13`).

## 3. Color system — "Observatory / Biolume"

### 3.1 Neutrals — the observatory scale

Dark-first. The main window adopts a deeper, owned neutral scale instead of raw `windowBackgroundColor` (this is the single biggest visual shift):

| Token | Value (dark) | Role |
| --- | --- | --- |
| `palette.void` | `#0B0E13` | Window base — the deep background behind everything |
| `palette.surface` | `#12161C` | Panel fill (replaces `controlBackgroundColor` on L1 surfaces) |
| `palette.surfaceRaised` | `#181E26` | Raised card fill |
| `palette.hairline` | white @ 8% | Separator, grid lines |
| `palette.textPrimary` | `#ECF1F4` | Body text (contrast ≥ 12:1 on surface) |
| `palette.textSecondary` | white @ 62% | Meta text (contrast ≥ 7:1) |
| `palette.textTertiary` | white @ 38% | Trace/provenance text (≥ 4.5:1) |

Light variant "Daylight Lab" inverts the neutrals (paper-white lab bench) with the same accents; both variants are defined at token level and validated per [§6](#6-contrast-validation-mandatory-gate).

### 3.2 Accents — Biolume (owned, not system)

The identity accent is an owned pair, chosen from the instrument/aurora family and checked against both neutrals:

| Token | Value (dark) | Role |
| --- | --- | --- |
| `palette.biolume` | `#5AE6C8` (spectral teal) | Primary luminous accent: Orb core, listening state, focus rings, active tab |
| `palette.biolumeDeep` | `#1FB59A` | Gradient partner (core depth), pressed states |
| `palette.signal` | `#8AB4FF` (cool blue) | Information/system accents that must not compete with the core |
| `palette.cautious` | `#F2B84B` (amber) | Restricted, pending confirmation, mock-derived — inherits current orange semantics |
| `palette.critical` | `#FF6B5E` | Error, emergency stop — inherits current red semantics |

Status semantics stay exactly where they are: `AuraDesign.statusColor(_:)` (`AuraDesign.swift:74-84`) is remapped *inside* to these tokens (idle → biolume, active states → biolume, restricted → cautious, error → critical) so every consumer — pill, badges, task rows — changes coherently in one place.

**Decision point (UI-0 ADR):** owned accent vs. keeping the user's system accent color. Recommendation: owned accent for brand surfaces (Orb, icon, identity mark), system accent retained for interactive control accents (buttons, toggles) so AURA still feels native. The two must never be adjacent equals — biolume is luminous-on-dark, system accent follows the user's theme.

### 3.3 What is forbidden

- Gradients in text; glows behind body text (glass rule, `AuraDesign.swift:57-61`); more than one luminous element in a viewport except the Orb; pure `#000` fills (use `void`).

## 4. Materials ladder

| Level | Token | Definition | Used for |
| --- | --- | --- | --- |
| L0 | `materials.base` | `palette.void` fill | Window background |
| L1 | `materials.panel` | `palette.surface` fill + `palette.hairline` stroke, radius tokens as today | `AuraPanel`, cards (`AuraDesign.swift:62-68` evolved to tokens) |
| L2 | `materials.chrome` | `.glassEffect(.regular)` — floating interactive chrome | Status pill, tab bar/sidebar, composer (as today, `AuraMenuView_Content.swift:269-310`) |
| L3 | `materials.hero` | `.glassEffect(.regular.tint(…))` with luminous content | The Orb, the listening bar, overlays |

One light model: shadows only from L2 up, single-source top light, blur radii tokenized (`materials.blurSmall/Medium`). No material sits directly on its parent level without a stroke or spacing separation — the "controlled depth" rule.

## 5. Typography extension and precision grammar

### 5.1 New tokens (additive only)

```swift
// extended Typography (pinned tokens unchanged):
static let numeric = Font.body.monospacedDigit()            // quantitative readouts
static let numericSmall = Font.caption.monospacedDigit()
static let display = Font.largeTitle.weight(.light)          // Orb scale moments, onboarding title
```

Every latency, percent, count, confidence, and timestamp in the UI migrates to `numeric` tokens during UI-3's instrument pass.

### 5.2 Measurement grammar (`Measure`)

- `tickMajor`/`tickMinor` heights for gauge scales; `hairline` = 1 pt stroke of `palette.hairline`.
- **Instrument brackets**: L1 panels in telemetry surfaces get 6-pt corner marks (top-leading/bottom-trailing) — the scientific signature detail, drawn as `Canvas`/shapes, `accessibilityHidden`.
- Grid: 8-pt rhythm on top of existing `Spacing`; tabular alignment for the config-governance key list (monospaced keys, `LabeledContent` restyled).

## 6. Contrast validation (mandatory gate)

New owned colors are **not done** until validated:

1. A unit test computes WCAG contrast ratios for every text-on-surface token pair in both variants (dark/light) — thresholds: body ≥ 7:1, meta ≥ 4.5:1 (exceeding AA where the tokens make it free).
2. Accent-on-surface pairs ≥ 3:1 for graphical objects (WCAG 1.4.11 non-text contrast) — the Orb ring, focus rings, tick marks.
3. Status token pairs re-validated against the *new* surfaces, since the existing `.green/.orange/.red` choices were tuned for system backgrounds.

## 7. Data-viz palette (used by UI-3 charts and the telemetry deck)

Derived from the signal palette, color-blind-safe ordering (teal → blue → amber → violet), max 4 series per chart before shape encoding takes over (dashes/markers — color never the only channel). Sparklines and gauges draw axes/ticks in `palette.hairline`, data in `palette.biolume`, budget thresholds as dashed `palette.cautious` reference lines with a text label (never line-only).

## 8. Files to touch

| File | Change |
| --- | --- |
| `AuraDesign.swift` | New `Palette`, `Materials`, `Measure` enums; `statusColor` remap; `AuraPanel`/`panelBackground` evolve to L1 tokens |
| `AuraMenuView_Content.swift`, `AuraMenuView_Tabs.swift` | Migrate surface literals to tokens (mechanical, test-guarded) |
| `R9ProductUIStateTests.swift` | *Extended* (not mutated): contrast ratio tests, token existence tests |
| `AuraAccessibilityIdentifiers.swift` | Unchanged |

## 9. Risks

| Risk | Mitigation |
| --- | --- |
| Owned palette drifts from system appearance (increased-contrast, accent users) | `@Environment(\.colorSchemeContrast)` variants defined at token level; system accent retained for controls (§3.2) |
| Dark-first re-skin touches dozens of literals at once | Token-first migration: literals replaced per surface, one tab per commit-sized unit, full suite after each |
| R9 typography pin temptation to mutate | Rule encoded in the ADR: tokens are additive; mutation requires the pinned test's deliberate update with design sign-off |
