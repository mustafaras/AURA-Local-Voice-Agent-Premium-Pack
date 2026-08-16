# EV-SP-003-20260816-UI-SCENE-AND-GLASS-20

**Session:** AURA-SP-003-LIVE-DIALOGUE-20260815
**Timestamp:** 2026-08-16T09:05:00Z
**Branch / commit:** `main`, on top of `a83ae85`
**Environment:** macOS 27 / Apple Silicon arm64 / Swift 6.4 / CommandLineTools
**Evidence class:** Direct live application evidence (launched, measured, screenshotted) plus
source change and full regression sweep.

## Symptom reported

Two AURA interfaces visible, and a second entry among applications resembling `AuraPluginHost`.

## Root cause — it was not the plugin host

`AuraPluginHost` was investigated and cleared: it is a pure CLI process with no `AppKit`/`SwiftUI`
import and no `NSApplication`, its `Info.plist` sets `LSBackgroundOnly = true`, and it is nested
correctly at `Contents/Helpers/AuraPluginHost.app`. It is not the duplicate.

The duplication came from `Sources/AURA/AURA.swift`, and there were two independent causes:

1. The main scene was a **`WindowGroup`**, which permits unlimited duplicate windows of the whole
   assistant (⌘N). An assistant has one conversation and one runtime, so this is wrong by
   construction.
2. The **`MenuBarExtra` rendered the identical full `AuraMenuView`**. The complete interface —
   conversation, all six tabs, the runtime health list — therefore existed twice with independent
   scroll state.

## Change

- `WindowGroup` → single `Window(id: "aura.main")` with `.windowResizability(.contentMinSize)`.
- New `Sources/AURA/AuraMenuBarPanel.swift`: the menu bar surface is now a compact status readout
  (status pill, Push-to-Talk, "Open AURA" which raises the existing window via `openWindow(id:)`,
  emergency indicator, Quit) rather than a second copy of the app.

## Live verification (measured, not assumed)

Bundle built via `scripts/build-app-bundle.sh`, ad-hoc signed, and launched. Signing initially
failed with "resource fork, Finder information, or similar detritus not allowed" because the repo
lives under an iCloud-synced Desktop; signing succeeded after copying the bundle outside that tree
and running `xattr -cr`.

| Measurement | Result |
|---|---|
| Processes matching AURA/helpers | `AURA` only, one PID |
| Visible (non-background) applications | `AURA` only |
| `AuraPluginHost` in either list | absent |
| Window count via Accessibility | **1** |

## Liquid Glass adoption — API verified before use

Per AGENTS.md's rule against writing code against unverified APIs, the material APIs were
probe-compiled against the real SDK before adoption
(`swiftc -typecheck -target arm64-apple-macos27.0`): `GlassEffectContainer`,
`.glassEffect(.regular.tint(_:).interactive(), in:)`, `.glassEffectID(_:in:)`,
`.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` all compiled with zero errors. The
package already targets `.macOS(.v27)`, so no availability guards are required.

Glass was applied only where it is earned, and deliberately withheld elsewhere:

| Surface | Material | Reason |
|---|---|---|
| Status pill | Glass, tinted by live status | Floating chrome over changing content |
| Composer field | Glass `.interactive()` | Interactive control |
| Push-to-Talk | `.glassProminent` | Primary action |
| Tab pills | Glass container | Floating navigation |
| Panels behind body text | Plain material | Glass behind dense long-lived text costs legibility; "apply glass to every view" is a documented anti-pattern |

Sibling glass shapes are wrapped in `GlassEffectContainer`, which is the documented requirement
for merging/morphing and avoids paying for several independent glass passes side by side.

## Layout defect found by looking at the running app

The first screenshot showed a wide band of dead space beneath the composer: the transcript was
pinned to `maxHeight: 300` inside the outer `ScrollView`. Fixed by giving the conversation tab the
window's full height (transcript grows, composer anchors to the bottom) while the other tabs —
which are lists of arbitrary length — keep scrolling as a whole. Confirmed corrected in a second
screenshot.

## Verification

- Full sweep: **21/21 bundles, 0 failed**.
- Clean `swift build --product AURA`: succeeds with **zero warnings** (two pre-existing
  `var trimmed` warnings in `OllamaStructuredRequest` were also corrected to `let`).
- App launched, measured, and quit cleanly.

## Scope and limitations

- Visual confirmation covers the Conversation tab in dark appearance at one window size. The other
  five tabs, light appearance, increased-contrast, and dynamic-type variations were not
  screenshotted.
- Accessibility was preserved structurally (labels, `.isHeader`, `.isSelected`, colour never the
  sole carrier of meaning) but was not re-audited with VoiceOver in this session.
- No live-model or live-voice run is claimed by this record.

## Verdict

The duplicate-interface report is resolved at its real cause, verified against the running
application rather than inferred. Liquid Glass adopted against SDK-verified APIs and confined to
appropriate surfaces.
