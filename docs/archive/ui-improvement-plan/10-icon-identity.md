# UI-V: Icon & Identity System — The Iris

**Volume:** I — Identity & Foundations.
**Status:** Design proposal with a verified pipeline gap. This is the highest-visibility, lowest-behavior-risk item in the whole plan: it touches zero Swift code paths and zero pinned tests.
**Implements:** Design Vision Pillar 1 ([08-design-vision.md](08-design-vision.md)).

---

## 1. Verified current state: there is no icon

- No `.icns`, no `.appiconset`, no `Assets.xcassets` anywhere in the repo (tree-wide search, `.build`/`.git` excluded).
- `Resources/AURA-Info.plist` declares no `CFBundleIconFile`/`CFBundleIconName` (grep: zero hits).
- `scripts/build-app-bundle.sh` (108 lines) copies plists, entitlements, and the Safari extension resources — it has **no icon copy step**.
- Consequence: the installed app shows the generic default executable glyph in the Dock, in the menu bar, and in the App Switcher. For a product targeting premium identity this is the single highest-leverage fix available.

## 2. Concept — "The Iris"

The icon is the Orb's most compact ancestor ([08 §5 Pillar 1](08-design-vision.md)). Design:

- **Geometry:** a dark glass disc (squircle per the platform icon grid) containing three concentric elements: a thin luminous **iris ring** (spectral teal `#5AE6C8` → deep teal gradient), a **core dot** slightly above center-right (the "pupil" — the only asymmetric element, giving the mark a direction of attention), and a faint radial gradient field between ring and core (the "aura").
- **Reading at every size:**
  - 1024/512/256: full detail — glass depth, aura gradient, hairline ring bevel.
  - 128/64: ring + core + aura; bevel simplified.
  - 32/16 (menu bar, small Dock): **ring + core only** — the mark must survive as two luminous strokes on dark glass. This is the legibility gate.
- **Variants:** light (daylight lab: paper disc, deep-teal ring), dark (default: the canonical dark glass), **tinted** (monochrome glass variant per the platform's tinted appearance mode) — the platform icon system expects all three as separate layered assets.
- **What it is not:** no microphone glyph (generic assistant cliché), no letterform "A" (wordmark belongs in the UI, not the icon), no face/robot (AURA is an instrument, not a character).

## 3. Identity mark family (one geometry, five scales)

| Scale | Surface | File today | Change |
| --- | --- | --- | --- |
| 1024–16 px | Dock/App Switcher/About | **absent** (verified §1) | New `.icns` + pipeline (§4) |
| ~18 pt | Menu bar glyph (`MenuBarExtra` label, `AURA.swift:30-40`) | SF Symbol per status | Keep status-symbol behavior (it is functional chrome); the About/window identity uses the Iris mark; menu bar glyph stays status-driven by design |
| 34 pt | Header identity mark (`AuraMenuView_Content.swift:59-67`) | Generic rounded square + status symbol | Replaced by the Iris mark (static); status color stays with the pill — matching the existing "identity stays visually stable" comment |
| Full-bleed | Onboarding signature (UI-5), Settings About row (UI-4) | — | Iris at hero scale, animated per 11-motion-system.md if Reduce Motion off |
| ~280 pt panel | Menu bar panel header (today: status pill only) | — | Optional 20-pt Iris above the pill for identity continuity (*decision point*) |

## 4. Asset production plan

1. **Source of truth:** a vector master (SVG) of the Iris in three variants — checked into `Resources/brand/` so every future size is regenerable, never hand-rescaled.
2. **Raster pipeline:** a new `scripts/generate-app-icon.sh` renders the master to the full iconset (16, 32, 64, 128, 256, 512, 1024 at @1x/@2x) and runs `iconutil -c icns` → `Resources/AURA.icns`. Deterministic and re-runnable; no hand-exported PNGs in the tree.
3. **Bundle wiring (the verified gap):**
   - Add `CFBundleIconFile = AURA` to `Resources/AURA-Info.plist`.
   - Add one line to `scripts/build-app-bundle.sh` copying `AURA.icns` into `$CONTENTS/Resources/` (the script already creates that directory at its line 48).
4. **Codesign:** ad-hoc signing flow (`scripts/codesign-adhoc.sh`) is unaffected by resource addition; re-verify signature after bundling per existing practice.
5. **Variant assets:** light/dark/tinted masters as separate files; the single-file `CFBundleIconFile` path ships the default (dark) first — variant adoption via an asset-catalog migration is a *decision point* recorded in the phase ADR (it changes the resource declaration shape).

## 5. Verification and acceptance

- Dock check at all magnifications; App Switcher; About panel; Finder (list + icon views); menu bar (status glyph unchanged).
- 16 px legibility test: Iris still reads as ring+core at 16 px on both light and dark desktops.
- Tinted-appearance check (system tinted icons mode): the mark survives monochrome rendering.
- Bundle content check: `.icns` present at `AURA.app/Contents/Resources/`, `Info.plist` key present, app relaunches with icon (Dock caches; verify via fresh bundle path, not in-place rebuild).
- Existing tests: no Swift surface changes — full suite must pass without any test edit.
- Ledger evidence: screenshots at 16/32/128/512, both desktop appearances.

## 6. Risks

| Risk | Mitigation |
| --- | --- |
| Icon looks generic at small sizes | The 16 px reduction is a design requirement with its own acceptance check (§5), not an afterthought |
| iCloud/xattr codesign breakage when adding resources | Reuse the established xattr-strip discipline from `scripts/aura-test.sh:86-91` in the generator script if needed |
| Brand vs. platform tension (owned accent in icon vs. system accent UI) | Icon is always brand-owned; interactive accents stay system (09 §3.2 decision) |
| Vector master drift vs. rendered PNGs | PNGs are never committed — only generated (§4.2), so drift is impossible |

## 7. Effort

S–M. Highest visibility per unit of work in the entire plan; zero behavior risk. Recommended to land **first**, even before UI-1, as the identity proof-of-concept for the whole Volume I language.
