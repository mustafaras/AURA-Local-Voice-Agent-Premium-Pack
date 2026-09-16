import Foundation
import SwiftUI
import Testing

@testable import AURA

/// ADR-065 §3 (PA-1 G1-3): six-field permission snapshot, the single consent
/// pass presentation on the `privilegedAccess` stage, the two new indicator
/// rows, EN/TR copy, and pinned accessibility identifiers. The onboarding
/// stage machine itself is behavior-frozen (UI-5 / ADR-063) and is not
/// exercised here beyond constructing the view for the stage.
@Suite("PA-1 single consent pass")
struct PA1ConsentPassTests {
  private static func snapshot(_ state: PermissionState) -> PermissionSnapshot {
    PermissionSnapshot(
      microphone: state, speechRecognition: state, accessibility: state,
      screenRecording: state, calendar: state, contacts: state)
  }

  @Test("the snapshot covers exactly the six permissions, in request order")
  func sixKindsInOrder() {
    #expect(
      PermissionKind.allCases == [
        .microphone, .speechRecognition, .accessibility, .screenRecording, .calendar, .contacts,
      ])
    let all = Self.snapshot(.granted)
    for kind in PermissionKind.allCases {
      #expect(all.state(for: kind) == .granted)
    }
  }

  @Test("allGranted is true only when every one of the six is granted")
  func allGrantedRequiresAllSix() {
    #expect(Self.snapshot(.granted).allGranted)
    for kind in PermissionKind.allCases {
      var one = Self.snapshot(.granted)
      switch kind {
      case .microphone: one.microphone = .denied
      case .speechRecognition: one.speechRecognition = .notDetermined
      case .accessibility: one.accessibility = .denied
      case .screenRecording: one.screenRecording = .restricted
      case .calendar: one.calendar = .denied
      case .contacts: one.contacts = .notDetermined
      }
      #expect(!one.allGranted, "\(kind) missing must not read as all granted")
    }
  }

  @Test("undetermined lists what macOS will still prompt for")
  func undeterminedListsNotDetermined() {
    var s = Self.snapshot(.granted)
    s.calendar = .notDetermined
    s.contacts = .denied
    #expect(s.undetermined == [.calendar])
  }

  @Test("the pre-PA-1 four-field snapshot still constructs; the new fields default to not requested")
  func legacyInitDefaults() {
    let s = PermissionSnapshot(
      microphone: .granted, speechRecognition: .granted, accessibility: .granted,
      screenRecording: .granted)
    #expect(s.calendar == .notDetermined)
    #expect(s.contacts == .notDetermined)
    #expect(s.speechReady)
    #expect(!s.allGranted)
  }

  @Test("every permission kind has EN and TR copy and a Privacy anchor")
  func copyAndAnchors() {
    for kind in PermissionKind.allCases {
      for language in AuraUILanguage.allCases {
        let text = AuraCopy.text(kind.copyKey, language: language)
        #expect(!text.isEmpty && !text.hasPrefix("perm."), "missing copy \(kind.copyKey) \(language)")
      }
      #expect(!kind.settingsAnchor.isEmpty)
    }
    #expect(AuraCopy.text("perm.calendar", language: .turkish) == "Takvimler")
    #expect(AuraCopy.text("perm.contacts", language: .turkish) == "Kişiler")
    #expect(AuraCopy.text("perm.onePass", language: .turkish) == "Bir kez verilir; yeniden sorulmaz.")
    for key in ["onboarding.privilegedAccess.incomplete", "onboarding.explain.privilegedAccess"] {
      for language in AuraUILanguage.allCases {
        #expect(!AuraCopy.text(key, language: language).hasPrefix("onboarding."), "missing \(key)")
      }
    }
    #expect(
      AuraCopy.text("onboarding.explain.privilegedAccess", language: .turkish)
        .contains("Bir kez verilir; yeniden sorulmaz."))
  }

  @Test("consent-pass identifiers are distinct, unlocalized, and derived from the kind")
  func identifiers() {
    var seen = Set<String>()
    for kind in PermissionKind.allCases {
      let row = AuraAccessibilityID.onboardingPermissionRow(kind.rawValue)
      let settings = AuraAccessibilityID.onboardingPermissionSettings(kind.rawValue)
      #expect(row == "aura.onboarding.perm.\(kind.rawValue)")
      #expect(settings == row + ".settings")
      #expect(seen.insert(row).inserted)
      #expect(seen.insert(settings).inserted)
    }
    for id in [
      AuraAccessibilityID.calendarGrant, AuraAccessibilityID.calendarSettings,
      AuraAccessibilityID.contactsGrant, AuraAccessibilityID.contactsSettings,
    ] {
      #expect(seen.insert(id).inserted)
      #expect(id.hasPrefix("aura.perm."))
    }
  }

  @Test("the privilegedAccess stage constructs with the six rows in every state and language")
  @MainActor
  func stageConstructsWithRows() {
    let model = AuraAppModel(startRuntime: false)
    model.productUIState.onboarding.stage = .privilegedAccess
    for language in AuraUILanguage.allCases {
      model.productUIState.language = language
      for state in [PermissionState.granted, .denied, .notDetermined, .restricted, .unavailable] {
        model.permissions = Self.snapshot(state)
        _ = AuraOnboardingView(model: model).body
      }
    }
    model.bootTask?.cancel()
  }

  @Test("the Privacy and Recovery tabs construct with the two new rows")
  @MainActor
  func tabsConstruct() {
    let model = AuraAppModel(startRuntime: false)
    model.permissions = Self.snapshot(.denied)
    for language in AuraUILanguage.allCases {
      model.productUIState.language = language
      // The tabs are composed of SwiftUI primitives, so they are constructed
      // (which evaluates every row and copy key) rather than `.body`-called.
      _ = AuraMenuView(model: model).privacyTab
      _ = AuraMenuView(model: model).recoveryTab
    }
    model.bootTask?.cancel()
  }
}
