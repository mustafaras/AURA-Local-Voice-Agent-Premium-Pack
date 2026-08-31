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

/// F-005 regression (independent review Round 3, 2026-08-30).
///
/// The emergency control stops generated mouse and keyboard input. Before this
/// fix every one of its strings — including both VoiceOver hints — was a bare
/// English literal, so a Turkish-speaking VoiceOver user was read English for the
/// one control where comprehension under stress matters most.
///
/// Identifiers must stay unlocalized (see above); *human-readable* strings must
/// not. These cases pin that distinction for the emergency surface.
struct EmergencyControlLocalizationTests {
  private static let keys = [
    "emergency.group", "emergency.stop", "emergency.stopHint",
    "emergency.rearm", "emergency.rearmHint",
  ]

  @Test("every emergency-control string resolves in both languages")
  func emergencyKeysResolveInBothLanguages() {
    for key in Self.keys {
      let english = AuraCopy.text(key, language: .english)
      let turkish = AuraCopy.text(key, language: .turkish)
      #expect(!english.isEmpty, "missing English copy for \(key)")
      #expect(!turkish.isEmpty, "missing Turkish copy for \(key)")
      // A key that falls through returns its own name; that is the silent
      // failure mode this test exists to catch.
      #expect(english != key, "\(key) fell through to its key in English")
      #expect(turkish != key, "\(key) fell through to its key in Turkish")
    }
  }

  @Test("emergency-control strings actually differ between languages")
  func emergencyStringsAreGenuinelyTranslated() {
    // Every one of these is prose, so an identical pair means the Turkish entry
    // was never written rather than that the translation legitimately matches.
    for key in Self.keys {
      #expect(
        AuraCopy.text(key, language: .english) != AuraCopy.text(key, language: .turkish),
        "\(key) is identical in both languages — Turkish copy is likely missing")
    }
  }

  @Test("both VoiceOver hints for the emergency control are localized")
  func emergencyVoiceOverHintsAreLocalized() {
    for key in ["emergency.stopHint", "emergency.rearmHint"] {
      let turkish = AuraCopy.text(key, language: .turkish)
      #expect(!turkish.isEmpty && turkish != key)
      // The English hints are the strings that shipped unlocalized; a Turkish
      // value equal to either of them means the regression came back.
      #expect(turkish != "Immediately disables generated input")
      #expect(turkish != "Allows generated mouse and keyboard input again")
    }
  }
}

/// F-005 systemic coverage (independent review Round 3 + correction, 2026-08-30).
///
/// The Round 3 finding was that accessibility strings bypassed the language
/// mapping. Its *magnitude* was overstated and corrected; the gap itself was real.
/// These cases pin the strings that were routed through `AuraCopy` so the coverage
/// cannot silently regress the way it did before.
struct AccessibilityCopyCoverageTests {
  private static let keys = [
    "a11y.tracePrefix", "a11y.diagnosticPrefix", "a11y.correctedMemory",
    "a11y.vscodeRead", "a11y.vscodeReadHint", "a11y.memorySearch",
    "a11y.deletionReceipt", "a11y.receiptRecord", "a11y.receiptClass",
    "a11y.receiptReason", "a11y.receiptDeletedAt",
  ]

  @Test("every routed accessibility key resolves in both languages")
  func accessibilityKeysResolve() {
    for key in Self.keys {
      for language in [AuraUILanguage.english, .turkish] {
        let value = AuraCopy.text(key, language: language)
        #expect(!value.isEmpty, "missing copy for \(key) in \(language)")
        // A missing key returns its own name — the silent failure this catches.
        #expect(value != key, "\(key) fell through to its key in \(language)")
      }
    }
  }

  @Test("routed accessibility strings are genuinely translated")
  func accessibilityStringsDifferBetweenLanguages() {
    for key in Self.keys {
      #expect(
        AuraCopy.text(key, language: .english) != AuraCopy.text(key, language: .turkish),
        "\(key) is identical in both languages — Turkish copy is likely missing")
    }
  }

  @Test("the deletion receipt stays fully readable to VoiceOver in Turkish")
  func deletionReceiptRemainsDescriptiveInTurkish() {
    // The receipt exists to prove a deletion happened; a VoiceOver user must get
    // the record, class, reason and time, not a bare label.
    for key in ["a11y.deletionReceipt", "a11y.receiptRecord", "a11y.receiptClass",
                "a11y.receiptReason", "a11y.receiptDeletedAt"] {
      let turkish = AuraCopy.text(key, language: .turkish)
      #expect(!turkish.isEmpty && turkish != key)
    }
  }
}

/// F-005 continuation (2026-08-30): the confirmation card and the memory
/// correction sheet.
///
/// Both structs already held `model`, so `model.productUIState.language` was
/// always reachable; what was missing was the two-line `language`/`copy()`
/// helper every other view in the module defines. The consequence was that the
/// *confirmation card* — the one surface where the user authorizes a real,
/// side-effecting action — was read entirely in English to a Turkish user,
/// including the Deny/Allow choice. That is the same severity class as the
/// emergency control, so it is pinned the same way.
struct ConfirmationAndCorrectionCopyTests {
  /// `confirmation.riskPrefix` is excluded on purpose: "risk" is the ordinary
  /// Turkish word in this register, so an identical pair is correct there and
  /// asserting difference would force a worse translation.
  private static let translatedKeys = [
    "confirmation.title", "confirmation.deny", "confirmation.allowOnce",
    "confirmation.expires", "action.cancel", "memory.saveCorrection",
    "message.degraded", "a11y.statusPrefix",
  ]

  private static let allKeys = translatedKeys + ["confirmation.riskPrefix"]

  @Test("every confirmation and correction key resolves in both languages")
  func keysResolve() {
    for key in Self.allKeys {
      for language in [AuraUILanguage.english, .turkish] {
        let value = AuraCopy.text(key, language: language)
        #expect(!value.isEmpty, "missing copy for \(key) in \(language)")
        // A missing key returns its own name — the silent failure this catches.
        #expect(value != key, "\(key) fell through to its key in \(language)")
      }
    }
  }

  @Test("confirmation and correction strings are genuinely translated")
  func stringsDifferBetweenLanguages() {
    for key in Self.translatedKeys {
      #expect(
        AuraCopy.text(key, language: .english) != AuraCopy.text(key, language: .turkish),
        "\(key) is identical in both languages — Turkish copy is likely missing")
    }
  }

  @Test("the authorization choice is never read in English to a Turkish user")
  func authorizationChoiceIsLocalized() {
    // These are the exact literals that shipped hardcoded in AuraConfirmationCard.
    // A Turkish value equal to one of them means the regression came back.
    let shipped = [
      "confirmation.title": "Confirmation Required",
      "confirmation.deny": "Deny",
      "confirmation.allowOnce": "Allow Once",
    ]
    for (key, englishLiteral) in shipped {
      #expect(AuraCopy.text(key, language: .english) == englishLiteral)
      #expect(
        AuraCopy.text(key, language: .turkish) != englishLiteral,
        "\(key) reverted to the shipped English literal in Turkish")
    }
  }

  @Test("the memory correction sheet is fully localized")
  func correctionSheetIsLocalized() {
    // "Corrected memory statement" and "Save correction" were the two strings
    // the earlier attempt could not reach for want of a `copy()` helper.
    for key in ["a11y.correctedMemory", "memory.saveCorrection", "privacy.correct",
                "action.cancel"] {
      let turkish = AuraCopy.text(key, language: .turkish)
      #expect(!turkish.isEmpty && turkish != key)
    }
    #expect(AuraCopy.text("a11y.correctedMemory", language: .turkish)
      != "Corrected memory statement")
    #expect(AuraCopy.text("memory.saveCorrection", language: .turkish) != "Save correction")
  }
}

/// Repo-wide copy guard (F-005 remediation, 2026-08-30).
///
/// `RISK_REGISTER.md` asked for "a test that fails when an accessibility string
/// has no Turkish counterpart", and noted that one "would currently fail". It no
/// longer does: every string reachable through `AuraCopy` is now translated.
///
/// This drives off `AuraCopy.allKeys` rather than a hand-listed set, because a
/// hand-maintained list is precisely what let the earlier gaps survive — a key
/// could be added to the table and simply never appear in a test.
///
/// What it does **not** prove: that every user-facing literal in `Sources/AURA`
/// goes through the table at all. A literal that never became a key is invisible
/// here. That gap is recorded honestly in `EV-SP-030-20260830-A11Y-COVERAGE-02`.
struct AuraCopyTableGuardTests {
  /// The only two keys allowed to be identical in both languages, each for a
  /// stated linguistic reason rather than a missing translation.
  ///  - `app.name`: "AURA" is a proper noun.
  ///  - `confirmation.riskPrefix`: "risk" is the ordinary Turkish word in this
  ///    register; forcing a difference would produce a worse translation.
  private static let identicalByDesign: Set<String> = ["app.name", "confirmation.riskPrefix"]

  @Test("the copy table is not empty")
  func tableIsPopulated() {
    // Guards against the guard itself passing vacuously if `allKeys` ever breaks.
    #expect(AuraCopy.allKeys.count > 150, "copy table unexpectedly small — is allKeys wired?")
  }

  @Test("every key in the copy table resolves in both languages")
  func everyKeyResolves() {
    for key in AuraCopy.allKeys {
      for language in [AuraUILanguage.english, .turkish] {
        let value = AuraCopy.text(key, language: language)
        #expect(!value.isEmpty, "empty copy for \(key) in \(language)")
        // A missing entry returns the key itself — the silent failure mode.
        #expect(value != key, "\(key) fell through to its key in \(language)")
      }
    }
  }

  @Test("every key is genuinely translated unless identical by design")
  func everyKeyIsTranslated() {
    for key in AuraCopy.allKeys where !Self.identicalByDesign.contains(key) {
      #expect(
        AuraCopy.text(key, language: .english) != AuraCopy.text(key, language: .turkish),
        "\(key) is identical in both languages — add Turkish copy, or allowlist it")
    }
  }

  @Test("the identical-by-design allowlist stays honest")
  func allowlistIsMinimalAndReal() {
    // Every allowlisted key must exist and must actually be identical. An entry
    // that is no longer identical is stale and would hide a future regression.
    for key in Self.identicalByDesign {
      #expect(AuraCopy.allKeys.contains(key), "\(key) is allowlisted but not in the table")
      #expect(
        AuraCopy.text(key, language: .english) == AuraCopy.text(key, language: .turkish),
        "\(key) is allowlisted as identical but differs — remove it from the allowlist")
    }
  }

  @Test("the permission readout is localized end to end")
  func permissionReadoutIsLocalized() {
    // Both halves of `permissionIndicator(name, state)` were hardcoded English
    // until 2026-08-30: the names at seven call sites, and PermissionState.title,
    // which had no language parameter at all.
    for state in [PermissionState.granted, .denied, .notDetermined, .restricted, .unavailable] {
      let english = state.title(for: .english)
      let turkish = state.title(for: .turkish)
      #expect(!english.isEmpty && !turkish.isEmpty)
      #expect(english != turkish, "PermissionState.\(state) is not translated")
    }
    #expect(PermissionState.granted.title(for: .english) == "Granted")
    #expect(PermissionState.granted.title(for: .turkish) != "Granted")
    for key in ["perm.microphone", "perm.speechRecognition", "perm.accessibility",
                "perm.screenRecording", "perm.screenObservation"] {
      #expect(AuraCopy.text(key, language: .turkish) != AuraCopy.text(key, language: .english))
    }
  }
}
