import AuraIntent
import Foundation
import Testing

@testable import AURA

/// The acceptance driver addresses AURA's controls by accessibility
/// identifier. These cases pin the two properties that make that safe: the
/// identifiers are unique, and they are not localized.
///
/// Both were violated before SP-011. The section pills exposed no accessible
/// name at all, so the live matrix was driven as "button 3 of group 2 of
/// group 1" — an address that silently selects the wrong control when a row
/// appears rather than failing.
struct AuraAccessibilityIdentifierTests {
  @Test("every section pill has a distinct identifier")
  func tabIdentifiersAreDistinct() {
    let ids = AuraProductTab.allCases.map { AuraAccessibilityID.tab($0.rawValue) }
    #expect(Set(ids).count == AuraProductTab.allCases.count)
    #expect(ids.allSatisfy { $0.hasPrefix("aura.tab.") })
  }

  /// A label follows the interface language; an identifier must not. If
  /// someone passes `copy(...)` into `accessibilityIdentifier`, the driver
  /// breaks the moment the user switches to Turkish — and it breaks by
  /// clicking nothing rather than by reporting a mismatch.
  @Test("identifiers never carry localized text")
  func identifiersAreNotLocalized() {
    for tab in AuraProductTab.allCases {
      let identifier = AuraAccessibilityID.tab(tab.rawValue)
      for language in AuraUILanguage.allCases {
        let localized = AuraCopy.text(tab.copyKey, language: language)
        #expect(identifier != localized)
        #expect(!identifier.contains(localized))
      }
    }
    for language in AuraUILanguage.allCases {
      #expect(
        AuraAccessibilityID.composerInput
          != AuraCopy.text("conversation.input", language: language))
      #expect(
        AuraAccessibilityID.composerSubmit
          != AuraCopy.text("conversation.submit", language: language))
    }
  }

  @Test("composer identifiers are distinct")
  func composerIdentifiersAreDistinct() {
    let ids = [
      AuraAccessibilityID.composerInput,
      AuraAccessibilityID.composerSubmit,
      AuraAccessibilityID.composerPushToTalk,
    ]
    #expect(Set(ids).count == ids.count)
  }

  /// Integration controls are addressed by capability ID rather than by row
  /// position or title, so the address survives retitling, translation, and
  /// rows appearing or disappearing as availability changes.
  @Test("integration identifiers are derived from the capability ID")
  func integrationIdentifiersAreScopedByCapability() {
    let capabilities = [
      InitialCapabilitySet.browserRead.id,
      InitialCapabilitySet.mailRead.id,
      InitialCapabilitySet.calendarRead.id,
      InitialCapabilitySet.contactsLookup.id,
    ]
    var seen: Set<String> = []
    for capability in capabilities {
      let controls = [
        AuraAccessibilityID.integrationState(capability),
        AuraAccessibilityID.integrationConnect(capability),
        AuraAccessibilityID.integrationGrant(capability),
        AuraAccessibilityID.integrationRevoke(capability),
      ]
      for control in controls {
        #expect(control.contains(capability))
        #expect(seen.insert(control).inserted)
      }
    }
  }
}
