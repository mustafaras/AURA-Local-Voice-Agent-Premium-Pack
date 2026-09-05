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

  // Conversation composer + language switch. The language switch is the one
  // control that must stay reachable regardless of which tab is selected, so
  // it gets a stable identifier too.
  static let languageSwitch = "aura.header.language"
  static let settingsButton = "aura.header.settings"
  static let onboardingButton = "aura.header.onboarding"
}
