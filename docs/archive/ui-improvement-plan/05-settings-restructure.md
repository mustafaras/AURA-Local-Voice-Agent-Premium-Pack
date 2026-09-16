# UI-4: Settings Restructure

**Priority:** P3 (fourth implementation phase, sequenced as UI-4).
**Surfaces touched:** `AuraSettingsView` (`AuraMenuView.swift:293-437`), `AURA.swift` (Settings scene declaration).
**Depends on:** nothing hard; visual language benefits from earlier phases.

---

## 1. Current state (verified)

- Settings is one grouped `Form`, fixed 620×600, with seven sections stacked vertically: product UI, voice, system permissions (7 buttons), VS Code bridge, startup, privacy notes, config governance (`AuraMenuView.swift:333-418`).
- Two pinned behaviors constrain any redesign, both documented from live-incident evidence:
  1. A confirmation challenge raised by a Settings control must render **inline as the first row** of the form (sheets inside the `Settings` scene do not present reliably), and must be scrolled into view on appear — the off-screen-expiry incident is recorded at `AuraMenuView.swift:305-328` (evidence `EV-SP-030-20260831-R11-LIVE-GATE-02`).
  2. Closing Settings with a pending confirmation denies it fail-closed (`AuraMenuView.swift:423-425`, `AuraAppModel_Settings.swift:146-149`).
- The permission section is a wall of seven sibling buttons with no grouping by purpose (request vs. open System Settings) (`AuraMenuView.swift:351-359`).
- The config-governance section mixes a toggle, a note, counts, a differing-keys list, and a refresh button (`AuraMenuView.swift:401-417`).

## 2. Goals

1. Settings is navigable by category without losing the inline-confirmation contract.
2. Permission actions are grouped by intent (grant here vs. open System Settings) so the wall of buttons becomes two clear groups.
3. No fail-closed path changes; no accessibility identifier changes.

## 3. Non-goals

- Moving Settings into the main window or merging it with any tab (it stays the platform-standard `Settings` scene).
- Changing any settings *behavior* (launch-at-login logic, VS Code bridge provisioning rules, config-governance toggles).
- Persisting tab selection for Settings (not part of `AuraProductUIState`; if added later it is a separate decision).

## 4. Proposed design

### 4.1 Category navigation inside the Form

- Keep `Form` + `.formStyle(.grouped)` but add a `Picker`-driven category switcher pinned above the form (segmented or toolbar style): **General** (product UI, startup), **Permissions** (voice + system permissions), **Integrations** (VS Code bridge), **Privacy & Config** (privacy notes, config governance).
- The picker routes through local `@State` (Settings layout is not product UI state); all sections stay in the form's data model — switching filters visibility only, so `ScrollViewReader` scrolling and `.onChange(of: model.pendingConfirmation != nil)` keep working unchanged.
- **Confirmation card contract:** the card remains the first element of the form and renders in **every** category (it must be visible regardless of which pane raised the challenge — this is the exact failure mode the anchor ID exists for, `AuraMenuView.swift:305-328`). The scroll-into-view `onChange` (lines 429-434) is untouched.
- The fail-closed `.onDisappear` denial stays on the form (lines 425-426).

### 4.2 Permission grouping

- Split the seven buttons into two labeled groups inside the Permissions category:
  - *Grant from AURA*: "Request Microphone & Speech", "Request Accessibility", "Request Screen Recording".
  - *Open System Settings*: the four deep links, presented with `gearshape`-symbol labels (matching the `integrations.systemSettings` icon language, `AuraMenuView_Tabs.swift:379-388`).
- Keep the "Refresh permissions" action; add the current permission state summary (reuse `permissionIndicator(_:_:)` from `AuraMenuView_Tabs.swift:656-664`) above the groups so users see state before acting.

### 4.3 Visual notes

- Section headers adopt the `AuraSectionHeader` component (already in `AuraDesign.swift:127-150`) for consistency with the main window.
- VS Code bridge section unchanged except header adoption (its provisioning flow was live-verified and is left alone).

## 5. Files to touch

| File | Change |
| --- | --- |
| `AuraMenuView.swift` (`AuraSettingsView`) | Category picker; section grouping; header component adoption |
| `AuraDesign.swift` | (Only if a reusable settings-header component is extracted) |
| `ProductUIState.swift` | New copy keys for category labels (`settings.category.*`) with real Turkish copy |

## 6. Testing and acceptance

- `R9ProductUIStateTests` constructs `AuraSettingsView` (`R9ProductUIStateTests.swift:388-433`) — must pass unchanged.
- Confirmation fail-closed tests (`RuntimeUIRemediationTests.swift:25-41`) and the confirmation-copy tests stay green.
- **Live acceptance is mandatory for this phase** (two prior live incidents live here): with the app running, raise a confirmation from the launch-at-login toggle in the *Startup* category while scrolled deep into another category — the card must appear and be scrolled into view; answering must succeed; closing Settings with a pending card must deny fail-closed. Record in ledger.
- Full suite via `./scripts/aura-test.sh`, rerun 2–3×.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Category filtering hides the confirmation card | Card renders in all categories, first in source order; explicit live acceptance test |
| Scroll-into-view `onChange` misses when target section is filtered out | Startup section lives in General; keep it visible in the default category, and scroll logic is category-independent (ScrollViewReader spans the form) |
| Settings scene quirks (sheets not presenting) resurface in new wrappers | No sheets introduced; inline pattern preserved per the documented evidence |
