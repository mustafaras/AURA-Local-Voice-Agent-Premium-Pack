# EV-SP-021-20260825-ACCESSIBILITY-LOCALIZATION-01

- **Evidence ID:** `EV-SP-021-20260825-ACCESSIBILITY-LOCALIZATION-01`
- **Prompt / gap:** SP-021 / OPEN-10 / R9
- **Timestamp:** 2026-08-25T12:40:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == 1d9f42c16ced7def33b29917ee0df67a984d1476`; working tree `dirty_expected` (SP-021 source/test/record edits uncommitted)
- **Class:** Live accessibility-tree inspection + deterministic localization tests + source fixes for TR status/capability localization
- **Environment:** `build-app-bundle.sh` / `codesign-adhoc.sh` signed app launched via `open --env` with isolated `CFFIXED_USER_HOME`; macOS 27 / Apple Silicon / Swift 6.4

## What was done

### 1. Deterministic localization + accessibility tests
- `AURAIntegrationTests` bundle (incl. `R9ProductUIStateTests` and
  `AuraAccessibilityIdentifierTests`) passes **86/86**.
- Added `R9ProductUIStateTests.statusPillLocalizesToTurkish` covering:
  `AuraAppStatus.title(for:)` differs EN/TR; `displayStatusDetail` maps the
  known English internal status detail to Turkish; unknown detail falls through.
- `python3 scripts/validate_second_pass_program.py` **PASSED**.

### 2. Accessibility identifiers added (stable, non-localized)
New `AuraAccessibilityID` constants in `AuraAccessibilityIdentifiers.swift`:
- `onboardingPrimary`, `onboardingSkip`, `onboardingClose`
- `languageSwitch`, `settingsButton`, `onboardingButton`
Wired into `AuraOnboardingView` (`AuraMenuView.swift`) and the header controls
(`AuraMenuView_Content.swift`). These let the acceptance driver and a screen
reader address onboarding and header controls position-independently.

### 3. Turkish status-pill localization (bug found live)
Live inspection in the launched app (switch language radio to TR) showed the
status pill still read English: `Idle. Ready — use Push to Talk`. Root cause:
`AuraAppStatus.title` was `rawValue.capitalized` (English-only) and
`statusDetail` was stored in English with no locale mapping.
Fixed:
- `AuraAppStatus.title(for:)` now returns localized titles (EN/TR).
- `AuraAppModel.displayStatusDetail` maps known English internal status details
  to Turkish when `productUIState.language == .turkish`.
- `AuraMenuView_Content`, `AuraMenuBarPanel`, and `AURA.swift` use
  `status.title(for:)` and `displayStatusDetail`.
- `AuraAppModel_Runtime.swift` uses `status.title(for: .english)` as the stable
  internal key (the display mapping handles Turkish).

### 4. Turkish capability-detail localization (bug found live)
Live inspection of the Capabilities tab in Turkish showed the row detail still
read `Ready` (English) and the no-evidence fallback read English. Fixed
`AuraAppModel_ProductState.swift` to use `AuraCopy.text("capabilities.ready",
...)` / `AuraCopy.text("capabilities.noEvidence", ...)`; added the
`capabilities.noEvidence` TR key.

## Live observations (accessibility tree)

In the launched app (AX tree via `System Events` / `aura-drive.applescript`):
- Header controls reachable by identifier: `aura.header.language` (AXRadioGroup),
  `aura.header.settings`, `aura.header.onboarding` (AXButton).
- Six section pills reachable: `aura.tab.conversation|tasks|capabilities|models|
  privacy|recovery` (AXButton), each carrying its localized name.
- Composer reachable on the Conversation tab: `aura.composer.input` (AXTextField),
  `aura.composer.submit` / `aura.composer.pushToTalk` (AXButton).
- **Turkish live:** switching the language radio to TR changed the header
  subtitle to `Yerel sesli asistan`, the conversation copy to
  `Konuşmanız burada görünecek.` / `Yerel işleme. Bulut bağlamı makine
  politikasıyla devre dışı`, and tab/capability titles to Turkish. The menu bar
  status label rendered `AURA status: Boşta` (Turkish). The **status pill detail
  remained English** until the fix in item 3.
- **Capabilities tab TR:** capability titles localized (e.g. `Kabuk Komutu
  Çalıştır`, `Yetenek Sağlığı`), but row `detail` strings (e.g. `Ready`, and the
  disabled-reason prose) were English until the fix in item 4. Disabled-reason
  prose (e.g. `VS Code bridge not authenticated: ...`, `Contacts reading is
  turned off ...`) is produced by subsystem availability enums in English and is
  **not yet localized** — tracked as a residual.

## Completion gate verdict

**NOT MET — SP-021 stays `in_progress`.** This evidence proves:
- all six tabs + header + composer + onboarding controls expose stable,
  non-localized accessibility identifiers (AX-driven reachability);
- Turkish localization now applies to the status pill title+detail and the
  capability ready/no-evidence detail;
- the app launches and renders both locales through the real accessibility tree.

It does NOT prove the **manual, user-present** acceptance required by the prompt:
- VoiceOver *spoken* reading order and confirmation-focus containment/expiry
  (needs a live VoiceOver session);
- keyboard-only full-navigation and Dynamic Type / scaled reflow / reduced
  motion / contrast with a human evaluator;
- the disabled-reason capability prose is not yet localized.

These are the prompt's explicit manual gates and cannot be closed by an
automated tree scan. **SP-021 is `in_progress`; SP-022 must not start.**

## Limitations

- Accessibility inspection used the AX tree only; no VoiceOver speech was
  listened to.
- The window did not open in the final `live3` relaunch (menu-bar extra panel
  and Window menu both reported 0 windows), so the last relaunch's tree could
  not be re-inspected; the observations above were captured on `live2`.
- No TCC mutation, install, provider contact, signing-for-distribution,
  release, deploy, commit, or push occurred.
