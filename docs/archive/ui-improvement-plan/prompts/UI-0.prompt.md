---
id: UI-0
sequence: 0
track: UI
depends_on: none
next_prompt: UI-1
state: pending
design_docs: 08-design-vision, 09-visual-language, 10-icon-identity, 11-motion-system, 12-sound-design, 13-advanced-surfaces
---

# UI-0 — Identity Foundation

## Mission

Land the identity foundation the whole plan consumes: the **Iris app icon end-to-end** (from the verified zero-icon state), **tokens v2** in `AuraDesign.swift` (strictly additive), the **motion vocabulary + Reduce Motion helper**, and the **sound decision scaffold**. Everything downstream consumes this vocabulary; the icon is the first landable, zero-behavior-risk item.

## Read before acting (anti-amnesia context — full re-read after every compaction)

- `ui-improvement-plan/ledger/CURRENT_PHASE.md` + `ledger/PHASE_LEDGER.md` (tail) + `00-working-protocol.md` §3–§5
- Design authority: `08-design-vision.md`, `09-visual-language.md`, `10-icon-identity.md`, `11-motion-system.md`, `12-sound-design.md`, `13-advanced-surfaces.md`
- Code: `Sources/AURA/AuraDesign.swift` (whole file), `Sources/AURA/ProductUIState.swift:297-736` (copy table)
- Tests: `Tests/AURAIntegrationTests/R9ProductUIStateTests.swift:435-450` (typography pin)

## Hard boundaries

- Work only UI-0's gates; prompt files for future phases are **frozen**.
- Typography tokens (`R9ProductUIStateTests.swift:435-450`) are **extended, never mutated**.
- No view-file edits in this phase; app builds + full suite green at every gate.
- No commit/push without explicit go-ahead in the turn; never `tail` the test runner (grep only).
- No synthetic data in any new component; no literals outside `AuraDesign`.

**Verified baseline (do not re-verify):** no `.icns` anywhere, no `CFBundleIconFile` in `Resources/AURA-Info.plist`, no icon step in `scripts/build-app-bundle.sh` (108 lines; `$CONTENTS/Resources` created at its line 48); copy table at `ProductUIState.swift:297-736` (>150-key guard floor); UserDefaults key `aura.ui.state`; xattr discipline `scripts/aura-test.sh:86-91`; tests only via `./scripts/aura-test.sh` (22 targets, rerun 2–3x, grep never tail).

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G0-1 | Icon pipeline: vector masters (light/dark/tinted) in `Resources/brand/` + `scripts/generate-app-icon.sh` (iconset 16→1024 @1x/@2x + `iconutil -c icns`) → `Resources/AURA.icns` | `ls Resources/brand/` (3 masters), `ls -la Resources/AURA.icns`, generator exit 0 |
| G0-2 | Bundle wiring: `CFBundleIconFile = AURA` in `Resources/AURA-Info.plist`; one copy line in `scripts/build-app-bundle.sh` into `$CONTENTS/Resources/`; codesign re-verified | `plutil -p Resources/AURA-Info.plist \| grep CFBundleIconFile`; `grep -n "AURA.icns" scripts/build-app-bundle.sh`; `codesign --verify` on fresh bundle |
| G0-3 | Tokens v2 additive-only in `AuraDesign.swift`: `Palette` (observatory neutrals + biolume accents, dark+light), `Materials` (L0–L3 ladder), `Measure`, `Motion`; zero mutation of pinned Typography | grep for the four enums; pinned-token grep unchanged; suite green |
| G0-3a | `statusColor(_:)` remapped in place to v2 tokens (idle→biolume, active→biolume, restricted→cautious, error→critical) so pill/badges/task rows change coherently in one place | status-mapping unit test green |
| G0-4 | WCAG contrast unit-test gate: body ≥ 7:1, meta ≥ 4.5:1, graphical ≥ 3:1, dark+light variants | matching test target green, pass counts captured |
| G0-4a | v2 token-existence tests (Palette/Materials/Measure/Motion members present and typed) | test target green |
| G0-5 | Motion helper: `AuraDesign.motion(_:)` returns nil under `accessibilityReduceMotion`; static-readout rule documented in code | unit test green |
| G0-6 | Sound scaffold: `soundFeedbackEnabled` (default off) + EN/TR copy keys; adoption decision recorded in the ADR (adopt-now / adopt-later / reject) | grep soundFeedbackEnabled; copy guard green |
| G0-7 | Full verification loop: `./scripts/aura-test.sh` full loop green, bundles 2–3×, grep output (never tail) | script exit 0 ×2–3; greps in ledger |
| G0-8 | Repo governance + live icon acceptance: ADR `docs/decisions/ADR-NNN-ui0-identity-foundation.md` + `ledger/PROJECT_LEDGER.md` append + `CURRENT_STATE.md` atomic rewrite; live check (Dock sizes, fresh bundle path, light/dark desktops, 16 px legibility) + screenshots as evidence | ADR exists; repo ledgers updated; screenshots listed in plan ledger |
| G0-9 | Machine coherence: `bash ui-improvement-plan/validate-continuity.sh` exit 0, all UI-0 gates `passed`, `phase_status: awaiting-approval` | validator OK + status line correct |

## Per-gate procedure

**G0-1 (icon pipeline):**

1. Draw three SVG masters into `Resources/brand/`: `iris-dark.svg` (canonical: dark glass disc, biolume `#5AE6C8`→`#1FB59A` ring, core dot upper-right, aura field), `iris-light.svg` (paper disc, deep-teal ring), `iris-tinted.svg` (monochrome glass). The 16 px legibility gate (ring+core only) is a design requirement — simplify bevels at ≤ 32 px.
2. Write `scripts/generate-app-icon.sh` (`set -euo pipefail`): renderer check (`rsvg-convert` → `qlmanage`+`sips` fallback chain), render each master to the full iconset size table, `iconutil -c icns` → `Resources/AURA.icns`. The generator is the only path to the `.icns` — PNGs are generated, never committed.
3. Verify: masters present (3), `.icns` exists, generator exit 0.

**G0-2 (bundle wiring):** insert `CFBundleIconFile = AURA` (string) via `plutil`/PlistEdit; add the copy line in `build-app-bundle.sh` after the plists copy; re-codesign per `scripts/codesign-adhoc.sh`; verify on a **fresh bundle path** (Dock caches in-place rebuilds).

**G0-3 + G0-3a (tokens v2):** append `Palette`, `Materials`, `Measure`, `Motion` enums to `AuraDesign.swift` (values per `09-visual-language.md` §3–§5); remap `statusColor(_:)` internally; before/after `grep -c` the five pinned typography styles to prove zero mutation; suite green after each sub-step.

**G0-4 + G0-4a (contrast + token tests):** contrast test computes WCAG relative-luminance ratios for every text-on-surface pair, both variants (body ≥ 7:1, meta ≥ 4.5:1, graphical ≥ 3:1); token-existence test asserts each new enum member resolves. Both land in the integration test target.

**G0-5:** `motion(_:)` helper + unit test (nil under reduced motion; tokens non-nil otherwise).

**G0-6:** `soundFeedbackEnabled` field in `ProductUIState` (default off; reducer-owned, persisted via UserDefaults `aura.ui.state`), Settings copy keys with genuine Turkish (copy guard stays green); the **adoption decision** itself goes in the ADR — the scaffold does not pre-decide.

**G0-7:** `./scripts/aura-test.sh` full loop, 2–3 bundle reruns, capture pass counts + failed-bundle greps.

**G0-8:** ADR (alternatives, decision, consequences — template per `docs/decisions/ADR_TEMPLATE.md`), append `ledger/PROJECT_LEDGER.md`, atomic `ledger/CURRENT_STATE.md` rewrite, live icon acceptance with screenshots (16/32/128/512, both desktops, tinted mode).

**G0-9:** update CURRENT_PHASE gate statuses → `passed`, `phase_status: awaiting-approval`, run validator → OK.

## Evidence templates (minimum content per SEQ entry)

- G0-1: `ls Resources/brand/` output, `ls -la Resources/AURA.icns`, generator exit 0, 16 px screenshots (dark+light)
- G0-2: `plutil -p | grep` output; `grep -n "AURA.icns" scripts/build-app-bundle.sh` line number; `codesign --verify` output; fresh-bundle-path relaunch result
- G0-3/G0-3a: enum grep output; before/after `grep -c` of pinned styles (identical); suite pass counts
- G0-4/G0-4a/G0-5: test names + pass counts; variant results table for contrast
- G0-6: copy-guard pass counts; `grep -n soundFeedbackEnabled` line numbers; ADR decision one-liner
- G0-7: rerun counts ×2–3; empty failed-bundle grep as evidence line
- G0-8: ADR path; ledger append line range; CURRENT_STATE rewrite timestamp; screenshot paths
- G0-9: validator output (all checks OK)

## Risks and rollback

| Risk | Mitigation |
| --- | --- |
| iCloud/xattr codesign breakage when adding resources | Reuse xattr-strip discipline (`scripts/aura-test.sh:86-91`) inside the generator if needed |
| Dock cache shows stale glyph | Verify via fresh bundle path, never in-place rebuild |
| Owned palette diverges from user expectations | System accent retained for interactive controls (09 §3.2, decided in ADR) |
| Typography pin temptation | Additive-only rule; mutation requires deliberate test change + design sign-off |

Rollback: revert `AuraDesign.swift` to pinned baseline; `.icns`/plist/script changes are additive and independently revertible; `aura-test.sh` loop green after any rollback check.

## Session script (anti-amnesia)

1. Read CURRENT_PHASE + ledger tail + this prompt + design docs (parallel reads, one turn).
2. `bash ui-improvement-plan/validate-continuity.sh`; on FAIL repair the machine first.
3. Restate aloud: "Aktif faz UI-0; tamamlanan: [gates]; sıradaki kapı G0-N."
4. One gate per checkpoint: verify → SEQ append → CURRENT_PHASE rewrite (`updated`, status, evidence, `last_seq`).
5. On G0-9: `phase_status: awaiting-approval`; ask *"Faz UI-0 tamamlandı; UI-1'e geçiş için onayınız?"*; **stop**.

## Cognitive completion gate (answer in ledger before awaiting-approval)

1. What exactly changed? (files + line ranges)
2. What evidence proves each gate? (command + output per gate)
3. What observation would falsify "identity foundation landed"?
4. Why is UI-1 safe to start? (vocabulary present, suite green, zero view churn in UI-0)
5. What residual risk remains, and why is it outside UI-0?
