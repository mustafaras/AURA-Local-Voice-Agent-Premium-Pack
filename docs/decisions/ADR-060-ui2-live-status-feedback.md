# ADR-060: UI-2 Live Status Feedback — Motion Tokens, Listening Pulse, TTS Equalizer, Emergency Badge, Confirmation Entrance

- Status: Accepted
- Date: 2026-09-13
- Owners: UI track (UI-2)
- Supersedes: none
- Superseded by: —

## Context

UI-1 shipped the conversation experience with zero motion: status changes
were instant swaps, the listening level only drove the Orb (not the status
pill), the app never subscribed to TTS events directly (speaking state
reached it only indirectly through `ConversationStateEvent`), and the
emergency-stop state had no persistent indicator in the main window header
at all (only a bare, un-themed label in the menu bar panel). The motion
vocabulary (`AuraDesign.Motion`) and its Reduce-Motion gate already existed
from UI-0 (G0-3/G0-5) but were unused outside the G1-4 auto-scroll
affordance. UI-2's mission: wire real events into visible feedback without
inventing a second copy of any already-shipped, already-tested surface.

## Decision

1. **Status pill motion (G2-1).** `AuraStatusPill` gained three
   `.animation(_, value: status)` sites, split by the vocabulary's own rule
   (only springs for geometry, only eases for colour): `Motion.smooth` on
   the leading dot's fill and the glass tint (colour), `Motion.standard` +
   `.id(status)` + `.transition(.opacity + .scale)` on the title/detail text
   block (geometry — the identity-swap crossfade). The header identity mark
   was deliberately left untouched: its own comment records an
   already-shipped decision that the mark's colour stays stable while the
   pill carries status, and 03-live-status-feedback.md's proposal to
   re-tint it was not adopted.

2. **Listening pulse (G2-2).** `AuraStatusPill.listeningPulseScale(status:
   inputLevel:)` — a `nonisolated`, pure function (0.9…1.15×, clamped,
   `1.0` outside `.listening` or with a `nil` level) — applied via a bare
   `.scaleEffect`, never wrapped in an `.animation(value: inputLevel)`. Both
   real call sites (header, menu bar panel) now pass `model.inputLevel`.
   03-live-status-feedback.md's proposal to reuse a component named
   `AuraLevelMeter` "inline under the status pill" in the menu bar panel was
   not adopted — no such component exists anywhere in the codebase; UI-1
   built the Orb instead. Introducing a new menu-bar-panel Orb instance was
   treated as out of G2-2's concrete scope (a transform-only pulse on the
   existing dot).

3. **TTS-driven speaking state (G2-3).** `AuraAppModel.isSpeakingResponse`
   (new `@Published Bool`) is set only by two new bus subscriptions —
   `TTSStartedEvent.self` → true, `TTSStoppedEvent.self` → false, for every
   stop reason — completely independent of `applyConversationState`'s
   existing `status`/`statusDetail` ownership (zero lines changed there). A
   new `AuraEqualizer` (three fixed-height bars, `accessibilityHidden`)
   renders beside the pill in both chrome locations, appearing/disappearing
   as a one-shot transition (never a continuously looping "fake audio"
   animation — there is no real per-sample TTS level to animate
   continuously). 03 §4.3's "stop-reason honesty" (routing a TTS failure
   into the error UI) was not implemented: that behavior lives in
   `Conversation_TTS.swift`/`Conversation_State.swift` (`Sources/AuraAgent`,
   outside UI-2's hard boundary), and `onSpeechFinished()` already
   transitions unconditionally to idle after any stop reason — reconciling
   that is a `Conversation`-FSM decision, recorded here as a residual
   decision point, not silently dropped. The Orb's existing
   `isSpeakingResponse: model.status == .speaking` argument
   (`AuraMenuView_Content.swift`, UI-1/G1-6) was **not** swapped to the new
   model property — doing so risks a regression to an already-shipped,
   already-tested surface for a timing guarantee (status vs. TTS-event
   ordering) this gate never required proving.

4. **Emergency badge (G2-4).** New `AuraEmergencyBadge` (symbol + amber
   `Palette.cautious` + real text — never colour alone) added to the header
   (previously had no emergency indicator at all) and restyled into the
   menu bar panel (previously a bare `.orange`-tinted label). Appears via
   `.transition` + a single `.animation(Motion.emergent, value:
   emergencyStopActive)` — one pulse, then static; Reduce Motion resolves
   to no pulse at all. The emergency **control** (the stop/rearm toggle,
   `AuraMenuView_Tabs.swift`, F-005-tested) is a completely separate,
   untouched surface — confirmed by reading it, not by assumption. 03
   §4.4's "the main window header disc switches to the same treatment" was
   not implemented, for the same reason as decision 1: it would reverse an
   already-shipped, deliberate identity-stability decision; the new badge
   already achieves the actual goal (unmistakable in every surface) as a
   second, distinct element.

5. **Confirmation card entrance (G2-5).** `.transition(.opacity +
   .scale(0.97))` + `.animation(Motion.emergent, value: requestID)` added
   **only** at the conversation-tab call site
   (`AuraMenuView_Content.swift`). `AuraConfirmationCard`'s own body
   (`AuraMenuView.swift`) — including the Deny-before-Allow button order —
   was not touched at all. The **same component's second call site**, inside
   `AuraSettingsView`'s `ScrollViewReader`/`Form`, was deliberately left
   untouched: that surface carries a live-verified, evidence-tracked
   fail-closed fix (`EV-SP-030-20260831-R11-LIVE-GATE-02`) for a real
   shipped bug (a confirmation scrolled off-screen, expiring unanswered),
   and that evidence record documents a **still-open** blocker in the same
   code path. Motion-token choice (`emergent`, not `standard` as
   11-motion-system.md §4's choreography table row says) was cross-checked
   three ways: the token's own doc-comment has named confirmation cards as
   an `emergent` use case since UI-0; `UI-2.prompt.md`'s G2-5 procedure
   says so explicitly; only the §4 table row disagrees — flagged as stale.

## Alternatives considered

- **Retrofitting the Orb and the Settings-tab confirmation card to match
  every background-doc aspiration exactly**: rejected — both surfaces are
  already-shipped, already-tested, and in one case (`AuraSettingsView`)
  carry a documented, still-open, security-relevant fragility. Visual
  consistency for a background doc's proposal does not outweigh regression
  risk to a surface a live gate once found broken.
- **A new `AuraLevelMeter`/menu-bar Orb for G2-2**: rejected — invents a
  component 03 assumed existed; the concrete gate text only asked for a
  transform on the existing dot.
- **Routing TTS failures into the error UI from `setSpeakingResponse`
  (G2-3)**: rejected — `status`/`statusDetail` already have one owner
  (`applyConversationState`); a second writer racing the same field from a
  different event stream is the kind of defect this project's own
  "one choreography owner" rule exists to prevent.

## Security and privacy impact

None of the five gates touch policy evaluation, confirmation resolution
logic, the emergency-stop mechanism itself, or any data persistence path —
every change is additive chrome (`.animation`/`.transition`/new pure
view structs) reading already-published, already-honest state
(`inputLevel`, `status`, a new `isSpeakingResponse` sourced only from real
TTS events). The full fail-closed and emergency-control test sets ran
unedited and green throughout (see Validation evidence).

## Operational impact

Two new bus subscriptions (`TTSStartedEvent`/`TTSStoppedEvent`), no new
polling, no new timers beyond SwiftUI's own transition/animation engine
(all Reduce-Motion-gated to `nil`, i.e. instant, when the accessibility
setting is on). No new subsystem, no configuration surface, no migration.

## Migration

None. Every change is additive and independently revertible: the
`isSpeakingResponse` property/subscriptions can be removed without
touching `applyConversationState`; each view's `.animation`/`.transition`
modifiers can be reverted per call site without touching the components
they wrap.

## Validation evidence

- `./scripts/aura-test.sh` full 22-bundle loop ×2 back-to-back at the
  G2-6 checkpoint: exit 0, 22/22 PASSED, 0 failed bundles both runs
  (session-scratchpad logs, not repo-tracked).
- `AURAIntegrationTests`: 167 (UI-1 baseline) → 176 tests / 28 suites (9
  new tests across G2-2..G2-5, one new suite `UI2LiveStatusFeedbackTests`).
- Per-gate evidence in full: `ui-improvement-plan/ledger/PHASE_LEDGER.md`
  SEQ-0033 (phase opened) through SEQ-0039 (G2-5), including SEQ-0038, an
  owner-requested "tam ve kusursuz" re-verification pass (fresh clean-build
  test run, line-by-line source re-read) that found no discrepancies.
- Fail-closed/emergency-control regression check: the full suite surfaced
  the three `ConfirmationSheetFailClosedTests` cases, `"window close
  dismisses..."`, `"emergency stop cancels..."`,
  `confirmationExpiryDenies()`, `confirmationChallengeExpiryEnforced()`,
  `"Emergency stop at the act/confirmation stage..."` (×2), and the F-005
  `EmergencyControlLocalizationTests` suite — all green, all unedited.
- a11y IDs: `Sources/AURA/AuraAccessibilityIdentifiers.swift` has zero
  diff since the UI-1 closure commit (`f24ebfb`) — G2-1..G2-5 introduced
  no new interactive/addressable controls, so no new identifiers were
  required by the contract.
- Live driver leg: fresh signed acceptance bundle
  (`BUILD_DIR=/tmp/aura-g26-accept`, `AURA Stable Local Signing`,
  `codesign --verify --deep --strict` → OK), launched via direct exec.
  Baseline AX-tree text dump of the main window showed no
  "Emergency"/"Acil" text. `key code 53 using {command down, shift down}`
  (the real emergency shortcut) sent via System Events; the follow-up dump
  showed the status pill updated to "Durduruldu..." and — the new G2-4
  surface — **"Acil durdurma etkin"** now present in the header, exactly
  where 03 §4.4 asked for it and where no indicator existed before. The
  rearm/removal half was not separately live-driven (the rearm button
  carries no accessibility identifier to click non-disruptively); it rests
  on SwiftUI's symmetric `.transition` guarantee plus the already-green,
  unedited `resetEmergencyStop()` model-level tests. App quit cleanly
  afterward (`pgrep` confirms no process running).

## Consequences

UI-3 inherits a chrome layer where every status-driven visual now animates
through the shared token vocabulary, with two explicit, honestly-recorded
residual decision points left for a future phase or owner call: (1) TTS
failure stop-reason routing into the error UI (a `Conversation`-FSM-layer
change, not a UI-2 chrome change), and (2) whether the Orb's
`isSpeakingResponse` source should ever be swapped from the status-derived
proxy to the new TTS-event-sourced model property. Neither blocks UI-3.
