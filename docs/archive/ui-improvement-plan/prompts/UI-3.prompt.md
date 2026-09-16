---
id: UI-3
sequence: 3
track: UI
depends_on: UI-2
next_prompt: UI-4
state: pending
design_docs: 02-information-architecture, 09-visual-language (§7), 13-advanced-surfaces (§3, §5)
---

# UI-3 — Information Architecture

## Mission

Restructure navigation around a sidebar, task progress rings from the real `TaskProgressEvent` payload, latency sparklines + the telemetry deck, `AuraStatusRow`, and the ⌘K command palette. The **AppleScript driver re-run** is the phase's riskiest item and its named gate — navigation churn breaks the driver before it breaks anything visible.

## Read before acting (anti-amnesia context)

- CURRENT_PHASE + ledger tail + `00-working-protocol.md` §3–§5
- `02-information-architecture.md`, `09-visual-language.md` §7 (data-viz palette), `13-advanced-surfaces.md` §3 (task rings) + §5 (telemetry deck)
- Code: `AuraMenuView.swift` (tab machine), `AuraMenuView_Content.swift`, `AuraMenuView_Tabs.swift`, `AuraAppModel_Runtime.swift:240-252` (`TaskProgressEvent` payload **currently discarded** — this phase makes it real), `AuraAccessibilityIdentifiers.swift`
- Verified baseline: `AuraDesign.Motion` tokens + contrast gate from UI-0; `AudioLevelBridge`/`isSpeakingResponse` from UI-1/UI-2; `aura.ui.state` persistence; fail-closed confirmation paths pinned.

## Hard boundaries

- Scope guard (allowed files): `AuraMenuView.swift`, `AuraMenuView_Content.swift`, `AuraMenuView_Tabs.swift`, `AuraAppModel_Runtime.swift` (payload capture only), `AuraCommandPalette.swift` (new), `AuraDesign.swift` (component additions only), integration tests, plan ledger. **Nothing else.**
- `AuraProductTab` rawValues + accessibility identifiers are **compatibility anchors** — renamed rawValues break persisted `aura.ui.state` and the driver. Extend, never rename.
- The ⌘K palette must NOT become a second command path: it opens the **existing** confirmation card for destructive actions; Escape/Cancel are fail-closed.
- Sparkline buffer is in-memory only — no persistence, no file writes; mock-provenance annotated per 13 §5 (no real-looking fake data).
- Copy stays via `AuraCopy` keys; no inline TR/EN ternaries in new views.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G3-1 | Sidebar navigation preserving `AuraProductTab` rawValues + identifiers; full keyboard traversal verified live | view-construction tests; live traversal check |
| G3-2 | Task progress rings driven by `TaskProgressEvent` payload (percent + step description); payload no longer discarded | unit tests on event→ring-state mapping; runtime test green |
| G3-3 | Latency sparklines (in-memory ring buffer) + telemetry deck per 13 §5: gauge scales, tick marks, breach markers, provenance annotation | unit tests on summary→deck-state mapping |
| G3-4 | `AuraStatusRow` + data-viz palette (09 §7) adopted in Recovery tab; contrast gate still green for new colors | view-construction test; contrast tests green |
| G3-5 | ⌘K palette: static entry table; destructive entries route through the existing fail-closed card; Escape/Cancel verified; a11y IDs per contract | fail-closed tests for palette dismissal; identifier test green |
| G3-6 | **Driver re-run**: full AppleScript driver leg over every tab + palette + sidebar traversal (the phase's riskiest surface) | driver leg evidence in plan ledger |
| G3-7 | Full verification loop + governance: suite green ×2–3; ADR + repo ledger + `CURRENT_STATE.md` | suite exit 0 ×2–3; artifacts in plan ledger |
| G3-8 | Machine coherence: validator OK, all gates `passed`, `awaiting-approval` | validator OK |

## Per-gate procedure

**G3-1:** swap tab strip for sidebar list inside the panel; keep every `AuraProductTab` case → identifier mapping identical (grep identifiers before/after, diff must be zero); keyboard traversal checked with the driver, not by hand-assertions.

**G3-2:** first change: stop discarding the payload at `AuraAppModel_Runtime.swift:240-252` — map into `@Published` ring state (percent + step text, clamped 0...1); ring renders from state, not from time-based animation (never animate toward an unknown progress value).

**G3-3:** ring buffer of last N summary latencies in memory; deck per 13 §5 — every mock or projected series carries a visible provenance annotation; data-viz colors from 09 §7, added to the contrast test set (graphical ≥ 3:1).

**G3-4:** Recovery tab adopts `AuraStatusRow` with the deck colors; view-construction + contrast suites prove the new colors pass the same gate.

**G3-5:** palette is a static entry table (no fuzzy search, no async); destructive entries call the same confirmation card path (grep proves one card presentation site); Escape/Cancel fail-closed tests from the existing set re-run unchanged.

**G3-6:** driver leg: script the full tour (sidebar tabs → deck visible → palette open/Escape → confirmation card via palette → fail-closed close). This gate cannot pass on unit tests alone.

**G3-7/G3-8:** full loop + governance; validator.

## Evidence templates (minimum per SEQ entry)

- G3-1: before/after identifier grep diff (zero change); traversal evidence
- G3-2: mapping test names + pass counts; the one-line diff showing payload now mapped
- G3-3: deck mapping test results; provenance annotation grep
- G3-4: view-construction + contrast pass counts for new colors
- G3-5: fail-closed pass counts; grep output proving single card site
- G3-6: driver leg script + output excerpt in plan ledger
- G3-7/G3-8: rerun counts ×2–3; ADR path; validator output

## Risks and rollback

| Risk | Mitigation |
| --- | --- |
| Sidebar churn breaks keyboard traversal / driver | G3-6 is dedicated to the driver; traversal fixed before deck work begins |
| Palette becomes a bypass around fail-closed card | Single card-presentation-site grep at G3-5 |
| Data-viz colors fail contrast | Colors enter the contrast test set at G3-4, before deck polish |
| `TaskProgressEvent` payload assumptions wrong | Map defensively (clamp, nil-safe); event contract tests pin the shape |

Rollback: sidebar and palette are separable — revert view files independently; the payload capture is one app-model field; `aura-test.sh` loop green after any rollback check.

## Session script (anti-amnesia)

1. Parallel reads (CURRENT_PHASE, ledger tail, this prompt, `02`/`13` docs, tab/content files).
2. Validator; on FAIL repair first.
3. Restate: "Aktif faz UI-3; tamamlanan: [gates]; sıradaki kapı G3-N."
4. One gate per checkpoint.
5. On G3-8: `awaiting-approval`; ask *"Faz UI-3 tamamlandı; UI-4'e geçiş için onayınız?"*; **stop**.

## Cognitive completion gate (answer in ledger before awaiting-approval)

1. What exactly changed? (files + line ranges)
2. What evidence proves each gate?
3. What observation would falsify "navigation restructured safely"?
4. Why is UI-4 safe to start? (identifiers stable, driver leg green, suite green)
5. What residual risk remains, and why is it outside UI-3?
