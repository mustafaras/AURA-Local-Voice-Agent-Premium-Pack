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
}
