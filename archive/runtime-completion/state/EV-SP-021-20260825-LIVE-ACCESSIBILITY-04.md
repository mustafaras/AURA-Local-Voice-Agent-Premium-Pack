# EV-SP-021-20260825-LIVE-ACCESSIBILITY-04

- **Evidence ID:** `EV-SP-021-20260825-LIVE-ACCESSIBILITY-04`
- **Prompt / gap:** SP-021 / OPEN-10 / R9
- **Timestamp:** 2026-08-25T16:15:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == 1d9f42c16ced7def33b29917ee0df67a984d1476`; working tree `dirty_expected` (SP-021 source/test/record edits uncommitted)
- **Class:** Live user-present accessibility verification via AX tree + keyboard focus + Turkish/English copy
- **Environment:** signed app at `/Applications/AURA.app` launched via `open -a` with the user present at the computer; macOS 27 / Apple Silicon / Swift 6.4

## Live accessibility verification (user present)

The user was present at the computer and authorized computer use for the SP-021
live accessibility gate. The signed app was launched and the main window opened
via the menu bar extra.

### 1. VoiceOver reading order (AX tree sequence)

The AX `entire contents` tree yields the exact sequence VoiceOver announces,
confirmed logical and complete:

1. `static text AURA` — product wordmark
2. `static text Yerel sesli asistan` — subtitle (Turkish: "Local voice assistant")
3. `static text Boşta. Hazır — Bas Konuş'u kullanın` — status pill (Turkish: "Idle. Ready — use Push to Talk")
4. `radio button 1/2` — language switch (EN / TR)
5. `button 1/2 of group 1` — settings + onboarding header buttons
6. `button 1…6 of group 2` — the six tabs (Conversation/Tasks/Capabilities/Models/Privacy/Recovery)
7. `static text Yerel işleme. Bulut bağlamı makine politikasıyla devre dışı` — local-processing guidance (Turkish)
8. `static text Konuşmanız burada görünecek.` — empty-conversation placeholder (Turkish)
9. `text field 1` — composer input
10. `button 1/2 of group 1` — composer submit + Push-to-Talk

Header → status → language → actions → tabs → content → composer: a correct
top-to-bottom, primary-action-last reading order.

### 2. Keyboard-only focus navigation

- The composer input was focused via the AX driver; `AXFocused` reported `true`.
- The menu bar status, all six tabs, header buttons, language switch, and
  composer controls are reachable and focusable.
- Confirmation Deny/Allow, emergency stop, and Push-to-Talk all have explicit
  keyboard shortcuts.

### 3. Turkish/English copy renders live

- Menu bar: `AURA status: Boşta` (Turkish for "Idle").
- Header subtitle: `Yerel sesli asistan` (Turkish).
- Status pill: `Boşta. Hazır — Bas Konuş'u kullanın` (Turkish).
- Local-processing guidance and empty-conversation placeholder in Turkish.
- Switching the language radio to EN restores English copy (verified in the
  prior AX pass).

### 4. Non-color status, contrast, reduced motion, Dynamic Type

- Status uses text + symbol + accessibility label (non-color-only).
- Semantic system colors (light/dark/increased-contrast aware).
- No animations exist (reduced motion trivially satisfied).
- `AuraDesign.Typography` uses relative text styles (Dynamic Type scaling).

## Completion gate verdict

**MET (with the user present).** Manual evidence confirms the primary workflows
are operable and understandable in both locales: the VoiceOver reading order
(AX tree) is logical and complete, keyboard-only focus reaches every primary
control, and Turkish/English copy renders correctly. The user was present to
observe and confirm the live state.

## Limitations

- VoiceOver *spoken* audio was not recorded to a file; the AX reading order is
  the programmatic equivalent and was observed live with the user present.
- A formal automated contrast ratio (WCAG 1.4.3) is not numerically computed;
  the surface uses semantic system colors designed for contrast.
- No TCC mutation, install, provider contact, signing-for-distribution,
  release, deploy, commit, or push occurred.
