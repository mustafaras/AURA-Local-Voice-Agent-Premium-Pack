import Foundation

/// Stable accessibility identifiers for the controls a live acceptance run has
/// to reach.
///
/// SP-011's live matrix is driven through the accessibility tree, and every
/// earlier attempt drove it positionally — "button 3 of group 2" — because the
/// tab pills and the composer's buttons exposed no label at all. Positional
/// addressing breaks whenever a row appears or a section is reordered, and it
/// silently clicks the wrong control instead of failing, which is worse.
///
/// Identifiers are deliberately **not** localized. A label answers "what is
/// this?" for a person and must follow the interface language; an identifier
/// answers "which control is this?" for a machine and must not change when the
/// user switches to Turkish.
enum AuraAccessibilityID {
  /// One of the six section pills.
  static func tab(_ rawValue: String) -> String { "aura.tab.\(rawValue)" }

  static let composerInput = "aura.composer.input"
  static let composerSubmit = "aura.composer.submit"
  static let composerPushToTalk = "aura.composer.pushToTalk"

  /// A row in the integrations list, addressed by its capability ID so the
  /// identifier survives retitling and translation.
  static func integrationRow(_ capabilityID: String) -> String {
    "aura.integration.\(capabilityID)"
  }

  static func integrationState(_ capabilityID: String) -> String {
    "\(integrationRow(capabilityID)).state"
  }

  static func integrationConnect(_ capabilityID: String) -> String {
    "\(integrationRow(capabilityID)).connect"
  }

  static func integrationGrant(_ capabilityID: String) -> String {
    "\(integrationRow(capabilityID)).grant"
  }

  static func integrationRevoke(_ capabilityID: String) -> String {
    "\(integrationRow(capabilityID)).revoke"
  }

  static func integrationEnable(_ capabilityID: String) -> String {
    "\(integrationRow(capabilityID)).enable"
  }

  static func integrationSettings(_ capabilityID: String) -> String {
    "\(integrationRow(capabilityID)).settings"
  }

  static func integrationReconnect(_ capabilityID: String) -> String {
    "\(integrationRow(capabilityID)).reconnect"
  }

  // Screen-observation (Screen Recording TCC) row controls on the Privacy
  // tab. The request button raises the real macOS prompt; the settings button
  // deep-links the pane that owns a recorded decision.
  static let screenObservationGrant = "aura.perm.screenObservation.grant"
  static let screenObservationSettings = "aura.perm.screenObservation.settings"

  // Inline mail-account approval controls on the mail integration row.
  static let mailApprovalField = "aura.integration.mail.approvalField"
  static let mailApproveButton = "aura.integration.mail.approveButton"

  // Onboarding is a clean-profile gate: a fresh install must reach every
  // control from the keyboard and be discoverable by VoiceOver without a
  // mouse. Stable identifiers let the acceptance driver and a screen reader
  // address the step progression and skip controls position-independently.
  static let onboardingPrimary = "aura.onboarding.primary"
  static let onboardingSkip = "aura.onboarding.skip"
  static let onboardingClose = "aura.onboarding.close"

  /// ADR-065 §3 (PA-1): one live row per permission in the single consent
  /// pass, plus its System Settings fallback. Addressed by `PermissionKind`
  /// raw value so the identifier survives retitling and translation.
  static func onboardingPermissionRow(_ kind: String) -> String {
    "aura.onboarding.perm.\(kind)"
  }
  static func onboardingPermissionSettings(_ kind: String) -> String {
    "aura.onboarding.perm.\(kind).settings"
  }
  /// Privacy-tab indicator per permission (ADR-065 G1-4 reads these live);
  /// the element's accessibility value is the localized state.
  static func permissionIndicator(_ kind: String) -> String { "aura.perm.indicator.\(kind)" }
  /// Privacy-tab rows for the two permissions ADR-065 added to the snapshot.
  static let calendarGrant = "aura.perm.calendar.grant"
  static let calendarSettings = "aura.perm.calendar.settings"
  static let contactsGrant = "aura.perm.contacts.grant"
  static let contactsSettings = "aura.perm.contacts.settings"

  // Conversation composer + language switch. The language switch is the one
  // control that must stay reachable regardless of which tab is selected, so
  // it gets a stable identifier too.
  static let languageSwitch = "aura.header.language"
  static let settingsButton = "aura.header.settings"
  static let onboardingButton = "aura.header.onboarding"

  // Conversation experience (UI-1). The draft bubble, the thinking
  // placeholder, and the jump-to-latest affordance are all reachable by the
  // live acceptance driver; the Orb carries a readout identifier so a driver
  // leg can assert what state the instrument claims.
  static let conversationDraftBubble = "aura.conversation.draftBubble"
  static let conversationThinking = "aura.conversation.thinking"
  static let conversationJumpToLatest = "aura.conversation.jumpToLatest"
  static let conversationOrb = "aura.conversation.orb"
  /// The transcript scroll area.
  ///
  /// The acceptance driver's `transcript` command addressed this surface
  /// positionally (`scroll area 1 of group 1`) — the exact pattern this file
  /// exists to replace — and broke silently when UI-1 rebuilt the transcript
  /// around a `ScrollViewReader`. A read path is as much an API as a button.
  static let conversationTranscript = "aura.conversation.transcript"

  /// Acceptance-harness-only scaffold (G1-4 completion). Real users never see
  /// this control — it is absent from the view hierarchy in every build
  /// configuration unless `AURA_ACCEPTANCE_TEST_HOOKS=1` is set in the
  /// process environment. It exists because AX-driven scroll-bar manipulation
  /// (`aura-drive.applescript scroll`) sets the AppKit scroller's value
  /// directly and never reaches SwiftUI's own `onScrollGeometryChange`, so no
  /// automated leg could ever leave the bottom the way stick-to-bottom
  /// detects it. A genuine `ScrollViewProxy.scrollTo` call does reach it —
  /// the same call `scrollToLatestIfFollowing` already uses — so this button
  /// performs one, driven the same way any other control here is: `click`.
  static let debugScrollToTop = "aura.debug.conversationScrollToTop"
}
