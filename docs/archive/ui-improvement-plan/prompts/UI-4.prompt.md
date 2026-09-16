---
id: UI-4
sequence: 4
track: UI
depends_on: UI-3
next_prompt: UI-5
state: pending
design_docs: 05-settings-restructure, 13-advanced-surfaces (§2)
---

# UI-4 — Settings Restructure

## Mission

Category-navigable Settings (General / Permissions / Integrations / Privacy & Config) with the pinned confirmation card **first in every category**. Live confirmation acceptance via the driver is mandatory — two prior live incidents make "tests pass" insufficient evidence here.

## Read before acting (anti-amnesia context)

- CURRENT_PHASE + ledger tail + `00-working-protocol.md` §3–§5
- `05-settings-restructure.md`, `13-advanced-surfaces.md` §2
- Code: `AuraMenuView.swift` (AuraSettingsView section), `ProductUIState.swift` (state fields + copy keys), `AuraDesign.swift` (components)
- Verified baseline: sidebar + identifiers stable (UI-3), driver leg green, fail-closed paths pinned, copy-table floor (>150 keys), `aura.ui.state` persistence, sound scaffold from UI-0 (adoption decision lives in the UI-0 ADR — read it, do not re-decide).

## Hard boundaries

- Scope guard (allowed files): `AuraMenuView.swift` (Settings section), `ProductUIState.swift` (only if a Settings preference is added), `AuraDesign.swift` (component additions only), integration tests, plan ledger. **Nothing else.**
- The confirmation card's behavior is **pinned** (five fail-closed paths, pinned tests + live evidence): presentation order changes allowed, behavior changes are defects.
- Sound preference row appears **only if** the UI-0 ADR adopted it — otherwise G4-3 is `N/A` with a ledger note; do not silently invent the preference.
- No invented permission states — grouping keys off real permission state only.
- Copy via `AuraCopy` keys (EN/TR genuine); no inline ternaries.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G4-1 | Category picker via local `@State` (General/Permissions/Integrations/Privacy & Config); confirmation card is the **first element in EVERY category** | view-construction test asserts card-first ordering per category |
| G4-2 | Permission grouping by real permission state only | view-construction test green; no invented-state grep |
| G4-3 | Sound preference row (conditional on UI-0 ADR decision; `N/A` path documented in ledger if rejected) | copy keys EN/TR real; copy guard green; ledger note |
| G4-4 | Full keyboard traversal of every category live; Escape/close fail-closed behavior re-tested unchanged | fail-closed close-path tests green |
| G4-5 | **Live confirmation acceptance** via AppleScript driver: open every category, confirm card-first, run one full fail-closed cycle live | driver leg evidence in plan ledger |
| G4-6 | Full verification loop + governance: suite green ×2–3; ADR + repo ledger + `CURRENT_STATE.md` | suite exit 0 ×2–3; artifacts in plan ledger |
| G4-7 | Machine coherence: validator OK, all gates `passed`, `awaiting-approval` | validator OK |

## Per-gate procedure

**G4-1:** category picker is local `@State` (no persistence — Settings position is not a product state); structure each category as `[confirmationCard, ...categoryRows]` and assert ordering in a view-construction test per category (4 assertions, not one).

**G4-2:** permission rows group by the actual permission state model (granted/denied/restricted as it exists); a state the model does not have is a defect, not a design idea.

**G4-3:** read the UI-0 ADR first. Adopted → row bound to the reducer-owned field, EN/TR copy keys, copy guard green. Rejected/later → record `G4-3: N/A (ADR decision: <x>)` in the ledger and move on.

**G4-4:** traversal: Tab cycles every category and lands back on the card's Deny button first; Escape and window-close fail-closed tests re-run **unchanged** (editing these tests is a defect — investigate the code instead).

**G4-5:** driver leg is mandatory: per category, open → card first → one live confirm/deny cycle → close. Two prior live incidents mean this gate cannot pass on unit tests alone; the driver output goes verbatim into the plan ledger.

**G4-6/G4-7:** full loop + governance; validator.

## Evidence templates (minimum per SEQ entry)

- G4-1: four per-category ordering test results
- G4-2: view-construction pass counts; grep proving no invented state keys
- G4-3: copy-guard pass counts + ADR decision quote, or the N/A ledger note
- G4-4: fail-closed suite pass counts; `git diff --stat` proving close-path tests untouched
- G4-5: driver leg script + output excerpt in plan ledger (mandatory)
- G4-6/G4-7: rerun counts ×2–3; ADR path; validator output

## Risks and rollback

| Risk | Mitigation |
| --- | --- |
| Category restructure displaces the confirmation card | Card-first is a tested ordering invariant, not a convention |
| New category state persists and fights `aura.ui.state` | Picker is local `@State` — nothing new persisted |
| Live confirmation regression (third incident) | G4-5 mandatory driver leg; suite alone never satisfies it |

Rollback: Settings restructure is contained in one view section + optional one state field; revert independently; fail-closed suites green after rollback check.

## Session script (anti-amnesia)

1. Parallel reads (CURRENT_PHASE, ledger tail, this prompt, `05` doc, UI-0 ADR, Settings files).
2. Validator; on FAIL repair first.
3. Restate: "Aktif faz UI-4; tamamlanan: [gates]; sıradaki kapı G4-N."
4. One gate per checkpoint.
5. On G4-7: `awaiting-approval`; ask *"Faz UI-4 tamamlandı; UI-5'e geçiş için onayınız?"*; **stop**.

## Cognitive completion gate (answer in ledger before awaiting-approval)

1. What exactly changed? (files + line ranges)
2. What evidence proves each gate?
3. What observation would falsify "settings restructured with pinned behavior"?
4. Why is UI-5 safe to start? (card invariant tested, driver leg green, suite green)
5. What residual risk remains, and why is it outside UI-4?
