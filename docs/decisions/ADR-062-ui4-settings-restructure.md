# ADR-062: UI-4 Settings Restructure — Category Navigation and Pinned Confirmation

- Status: Accepted — local UI-4 verification complete; awaiting UI-5 approval
- Date: 2026-09-15
- Owners: UI track (UI-4)
- Supersedes: none
- Superseded by: —

## Context

Settings previously rendered as one undifferentiated surface. UI-4 requires
four navigable categories while preserving the existing confirmation card's
placement and fail-closed behavior. The phase also needs a real permission
projection, honest sound scope from ADR-057, and keyboard- and driver-
addressable controls without adding persistence or a second confirmation path.

## Decision

1. **Local category navigation (G4-1).** `AuraSettingsView` owns a local
   `@State` `AuraSettingsCategory` selection for General, Permissions,
   Integrations, and Privacy & Config. The picker is not persisted and does not
   enter `aura.ui.state`.

2. **Pinned confirmation (G4-1/G4-5).** Every category is composed by one
   shared builder that emits the existing `AuraConfirmationCard` first, then
   the selected category's rows. Its anchor, acceptance, denial, Escape, and
   window-close fail-closed behavior remain unchanged. No second confirmation
   path or confirmation behavior change was added.

3. **Real permissions only (G4-2).** The Permissions category projects the
   four existing `PermissionSnapshot` fields through the existing
   `PermissionState` model. Grant actions, System Settings deep links, and
   refresh remain explicit actions; no pending, authorized, unknown, or other
   fabricated state is introduced.

4. **Sound scope (G4-3).** ADR-057 records Sound as adopt-later. UI-4 does
   not render a sound preference row, add a Settings preference, or alter the
   existing default-off scaffold. G4-3 is therefore explicitly N/A under that
   decision.

5. **Owned copy and accessibility (G4-1/G4-4).** Category and permission
   group labels use `AuraCopy` keys with genuine English and Turkish values.
   The native Picker, Form, Buttons, stable accessibility identifiers, and
   existing keyboard shortcuts provide the traversal surface. The existing
   Settings lifecycle hook continues to deny an unanswered confirmation on
   disappearance.

6. **Verification boundary (G4-6/G4-7).** Local completion requires the
   focused construction suite, a fresh build, two consecutive full 22-bundle
   suite passes, the live AppleScript confirmation leg, this ADR, both repo
   state ledgers, and the UI continuity validator. No commit, push, deploy,
   release, archive rewrite, or hosted-CI claim follows from this decision.

## Alternatives considered

- **Persist the selected category:** rejected because Settings position is a
  local navigation concern and persistence would create a new product state.
- **Place the confirmation card in only General:** rejected because every
  category must retain the existing confirmation boundary as its first form
  element.
- **Invent a pending or authorized permission row:** rejected because the
  shipped model exposes only the existing real permission states.
- **Adopt sound in UI-4:** rejected because ADR-057 explicitly defers sound
  adoption; changing that decision belongs to a separate ADR.

## Security and privacy impact

No new remote transport, audio capture, screenshot path, persistence field,
permission state, or policy bypass was added. Existing confirmation behavior
remains the sole mutation boundary, and unanswered confirmations still deny
on Escape, emergency stop, and Settings-window close.

## Operational impact

Settings now exposes four native category controls with stable identifiers.
Category changes are view-local and reset when the Settings view is rebuilt.
The live acceptance bundle is temporary and remains outside
`/Applications/AURA.app`.

## Migration and rollback

No data migration is required. Reverting the Settings section and its focused
construction test restores the prior single-surface presentation; the existing
permission model, confirmation paths, and persisted `aura.ui.state` remain
unchanged.

## Validation evidence

- G4-1: `PHASE_LEDGER.md` SEQ-0054 — four category constructions and card-first
  source/order assertions; focused AURAIntegrationTests 197/33, zero failed.
- G4-2: SEQ-0055 — four real permission fields, no invented states, focused
  AURAIntegrationTests 197/33, zero failed.
- G4-3: SEQ-0056 — ADR-057 adopt-later decision; N/A recorded; copy guard and
  focused suite green.
- G4-4: SEQ-0057 — live arrow traversal in all four categories and unchanged
  fail-closed tests.
- G4-5: SEQ-0058 — temporary signed bundle, four live card-first checks, live
  accept/deny/close cycles, safe reopen, and clean quit.
- G4-6: SEQ-0059 — focused suite, `swift build`, `git diff --check`, full
  `aura-test.sh` runs `/tmp/aura-ui4-g46-run2` and
  `/tmp/aura-ui4-g46-run3` both exit 0 with zero failed bundles; Python
  governance remains 95/96 because the frozen runtime-completion
  `verified_head` predates the UI-3/UI-4 worktree and is not rewritten.
- G4-7: SEQ-0060 — continuity validator and final machine-coherence receipt.

## Consequences and residual risks

The Settings surface is category-navigable, card-first in every category, and
uses only real permission state. Sound remains deliberately deferred. The
temporary live bundle and local test evidence do not establish hosted CI,
Developer ID, notarization, beta/RC, external publication, or release approval.
The archived runtime-completion mismatch remains outside UI-4 and is recorded
without changing the archive.
