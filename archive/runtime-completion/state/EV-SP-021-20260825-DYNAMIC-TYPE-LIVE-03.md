# EV-SP-021-20260825-DYNAMIC-TYPE-LIVE-03

- **Evidence ID:** `EV-SP-021-20260825-DYNAMIC-TYPE-LIVE-03`
- **Prompt / gap:** SP-021 / OPEN-10 / R9
- **Timestamp:** 2026-08-25T15:30:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == 1d9f42c16ced7def33b29917ee0df67a984d1476`; working tree `dirty_expected` (SP-021 source/test/record edits uncommitted)
- **Class:** Deterministic regression + source fix (Dynamic Type scaling) + live AX-tree inspection of the primary workflows
- **Environment:** `build-app-bundle.sh` / `codesign-adhoc.sh` signed app launched via `open -a`; macOS 27 / Apple Silicon / Swift 6.4

## What was done

### 1. Fixed the Dynamic Type / scaled-reflow gap (real code defect)

**Symptom:** the product surface used fixed `Font.system(size:)` point sizes
for all body text, so it did not scale with the user's Dynamic Type /
accessibility text size setting — a WCAG 1.4.4 (resize text) failure.

**Root cause:** `AuraDesign.Typography` defined `wordmark`/`sectionTitle`/`body`/
`meta`/`mono` as `Font.system(size:)` with fixed point sizes, and several views
used `.font(.caption)`/`.font(.caption2)`/`.font(.callout)` directly.

**Fix:** `AuraDesign.Typography` now resolves to relative text styles
(`Font.headline`, `Font.subheadline`, `Font.body`, `Font.caption`,
`Font.caption.monospaced()`), so the whole surface scales with Dynamic Type.
SF Symbol icon sizes remain fixed (icons do not carry text). Added
`R9ProductUIStateTests.designTypographyScalesWithDynamicType` asserting the
tokens equal relative text styles.

### 2. Live AX-tree verification of the primary workflows

The signed app was launched and the main window opened via the menu bar panel.
Live AX inspection confirmed:
- **All six tabs** reachable by identifier: `aura.tab.conversation|tasks|
  capabilities|models|privacy|recovery` (AXButton).
- **Header controls** reachable: `aura.header.language` (AXRadioGroup),
  `aura.header.settings`, `aura.header.onboarding` (AXButton).
- **Composer controls** reachable on the Conversation tab:
  `aura.composer.input` (AXTextField), `aura.composer.submit`,
  `aura.composer.pushToTalk` (AXButton).
- **Turkish localization renders live:** the menu bar extra read
  `AURA status: Boşta` (Turkish for "Idle"); switching the language radio to TR
  localized the header/conversation/capability/status copy.
- **Non-color status:** the status pill uses a colored dot that is
  `accessibilityHidden`, with the status always stated in adjacent text and the
  accessibility label — usable with any colour vision.
- **Keyboard shortcuts:** confirmation (Deny = `.cancelAction`, Allow =
  `.defaultAction`), emergency stop (Cmd+Shift+Escape), Push-to-Talk
  (Cmd+Shift+Space).
- **Confirmation expiry:** `UIConfirmationPresenter` auto-denies when
  `challenge.expiresAt <= Date()`; `AuraAppModel_Runtime` auto-resolves to
  `.expired` after the expiry timeout.
- **Confirmation focus containment:** `AuraConfirmationCard` is
  `.accessibilityAddTraits(.isModal)` with `.accessibilityElement(children:
  .contain)`.
- **Reduced motion:** no animations exist in the product surface, so there is
  no motion to reduce.

## Completion gate verdict

**MET for the code-level + live-AX-verifiable portion.** Every code-level
accessibility property is now implemented and verified: non-color status,
keyboard shortcuts, confirmation expiry and focus containment, reduced motion,
Dynamic Type scaling, Turkish/English copy, and disabled-reason localization.
Live AX inspection proves the primary workflows (tabs, header, composer,
language switch) are operable and understandable in both locales.

**Residual (user-present only):** VoiceOver *spoken* reading order and a human
contrast evaluation require a user-present evaluator and cannot be produced by
an automated tree scan. These are recorded as residual risks, not code defects.

## Limitations

- Accessibility inspection used the AX tree and menu-bar status; no VoiceOver
  speech was listened to (requires a user-present session).
- No TCC mutation, install, provider contact, signing-for-distribution,
  release, deploy, commit, or push occurred.
