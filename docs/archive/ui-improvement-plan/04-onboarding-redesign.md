# UI-5: Onboarding Redesign

**Priority:** P3 (fifth implementation phase, sequenced as UI-5).
**Surfaces touched:** `AuraOnboardingView` (`AuraMenuView.swift:177-291`), `ProductUIState.swift` (copy keys), new design-system onboarding components.
**Depends on:** design-system additions from earlier phases (status rows, motion helper); the stage machine itself must not change.

---

## 1. Current state (verified)

- Onboarding is a fixed-size sheet (560×300) with a linear `ProgressView` (value = stage raw value, total 12), a title pulled from `onboarding.stage.copyKey`, a multi-sentence explanation, and Skip/Next buttons (`AuraMenuView.swift:177-210`).
- The 13-stage machine (`privacy=0 … complete=12`, optional stages flagged) is a reducer-managed state machine (`ProductUIState.swift:213-248`) with action routing in the app model (`AuraAppModel_Interaction.swift:257-340`). Progress arithmetic and stage order are pinned by `R9ProductUIStateTests`.
- The stage explanations are hardcoded inline `language == .turkish ? … : …` ternaries inside the view (`AuraMenuView.swift:212-276`) — outside the `AuraCopy` governance table, contradicting the copy discipline that `AuraCopyTableGuardTests` enforces elsewhere.
- Primary-button labels per stage are also inline ternaries (`AuraMenuView.swift:278-286`).
- There are no icons, no per-stage illustration, no sense of "13 steps, here is where you are" beyond the bare progress bar.

## 2. Goals

1. Onboarding reads as a guided welcome, not a checklist form: per-stage iconography, clearer progress, calmer layout.
2. All onboarding copy moves into `AuraCopy` (single localization mechanism, test-guarded).
3. Zero behavior change: the stage machine, action routing, and accessibility identifiers stay exactly as pinned.

## 3. Non-goals

- Adding/removing/reordering stages or changing optionality (raw values are pinned by tests and are a compatibility surface).
- Making the sheet resizable or turning it into a full window (the fixed sheet matches the flow's purpose).
- Changing what any stage's primary action *does* (permission requests, emergency-stop test, etc. — `AuraAppModel_Interaction.swift:277-340`).

## 4. Proposed design

### 4.1 Layout

- Keep the sheet dimensions; restructure content as: stage icon in an accent-tinted rounded disc (top-leading), step counter ("Step 4 of 13" via a new `onboarding.stepCounter` key), title, explanation, then the existing button row.
- Replace the bare `ProgressView` with a segmented step indicator (13 compact segments, optional stages visually distinguished) with a text fallback for Dynamic Type at large sizes; the segments are `accessibilityHidden` — the existing progress accessibility label ("Setup step N of 13", `AuraMenuView.swift:190-192`) remains the announced truth.
- Optional stages get a visible "Optional" chip (new `onboarding.optionalChip` key) beside the title, mirroring `stage.isOptional`.

### 4.2 Stage iconography

- A static `icon(for stage:)` map in the view layer (SF Symbols: e.g. `lock.shield` → privacy, `waveform` → voice test, `speaker.wave.2` → TTS, `hand.raised` → emergency stop, `checkmark.seal` → complete). Decorative only: `accessibilityHidden(true)`; the copy keys remain the semantic content.
- The `complete` stage gets a distinct treatment (larger disc, tint shift) so the flow ends on a clear note.

### 4.3 Copy migration (the substantive part)

- Move all 13 explanation strings and all 4 non-default primary-button labels from inline ternaries into `AuraCopy` under new namespaced keys (`onboarding.explain.privacy`, `onboarding.primary.voicePermissions`, …), with genuine Turkish copy (most strings already have Turkish text to carry over verbatim — written by this project, currently trapped in the view).
- Delete the `explanation` switch's inline strings; the switch becomes a key lookup: `AuraCopy.text("onboarding.explain.<stage>", language:)`.
- The copy table guard will enforce both languages from then on, closing the same F-005-class gap the emergency controls were fixed for (`EmergencyControlLocalizationTests`, `AuraAccessibilityIdentifierTests.swift:106-147`).

### 4.4 Persistence note

- `AuraProductUIState.onboarding` persists via `aura.ui.state` (`AuraAppModel_Runtime.swift:352-355`); this phase changes presentation only — no state schema change.

## 5. Files to touch

| File | Change |
| --- | --- |
| `AuraMenuView.swift` (`AuraOnboardingView`) | New layout, icons, segmented indicator; explanation/button-label switches become key lookups |
| `AuraDesign.swift` | `AuraStepIndicator` component (reusable) |
| `ProductUIState.swift` | ~26 new `onboarding.*` copy keys (13 explanations, 4 primary labels, step counter, optional chip) |
| `Tests/AURAIntegrationTests/` | Extended `AccessibilityCopyCoverageTests`-style assertions for the new keys |

## 6. Testing and acceptance

- `R9ProductUIStateTests` onboarding-machine tests (advance/skip/close, stage localization coverage, `R9ProductUIStateTests.swift:12-49`) must pass **unchanged** — they pin the machine, not the pixels.
- Copy table guard green with the new keys; both languages genuinely differ (the existing Turkish strings qualify).
- Live acceptance: walk the full 13-stage flow via the driver (`aura.onboardingPrimary` / `onboardingSkip` / `onboardingClose` identifiers unchanged, `AuraAccessibilityIdentifiers.swift:72-74`); verify VoiceOver announces step counter + title + explanation in both languages.
- Full suite via `./scripts/aura-test.sh`, rerun 2–3×.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Copy migration shifts tone/meaning in Turkish | Carry the existing Turkish strings over verbatim; only their *location* moves |
| 13-segment indicator too small at large Dynamic Type | Text fallback branch at accessibility sizes; segments hidden |
| Sheet feels longer with step counter | Counter is one caption line; no added height |
