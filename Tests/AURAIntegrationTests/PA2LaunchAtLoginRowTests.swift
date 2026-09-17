import Foundation
import SwiftUI
import Testing

@testable import AURA

/// ADR-066 (PA-2 G2-1): the Settings Startup row tells the truth about
/// `SMAppService.Status.requiresApproval` — a notice plus a deep link to the
/// Login Items pane whose anchor was verified on this machine — with EN/TR
/// copy and pinned accessibility identifiers.
@Suite("PA-2 launch-at-login Settings row")
struct PA2LaunchAtLoginRowTests {
  @Test("requiresApproval copy and the Login Items button resolve in EN and TR, and differ")
  func copyResolves() {
    for key in ["settings.launchAtLoginRequiresApproval", "settings.openLoginItems"] {
      for language in AuraUILanguage.allCases {
        #expect(!AuraCopy.text(key, language: language).hasPrefix("settings."), "missing \(key)")
      }
      #expect(
        AuraCopy.text(key, language: .english) != AuraCopy.text(key, language: .turkish),
        "\(key) is not translated")
    }
    #expect(AuraCopy.text("settings.openLoginItems", language: .turkish) == "Giriş Ögeleri'ni Aç")
    #expect(
      AuraCopy.text("settings.launchAtLoginRequiresApproval", language: .turkish)
        .contains("Giriş Ögeleri"))
  }

  @Test("the deep link is the anchor verified in G2-1 and parses as a URL")
  @MainActor
  func deepLinkAnchor() {
    #expect(
      AuraAppModel.loginItemsSettingsURL
        == "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    #expect(URL(string: AuraAppModel.loginItemsSettingsURL) != nil)
  }

  @Test("startup identifiers are distinct, scoped, and unlocalized")
  func identifiers() {
    let ids = [
      AuraAccessibilityID.launchAtLoginToggle,
      AuraAccessibilityID.launchAtLoginRequiresApproval,
      AuraAccessibilityID.launchAtLoginOpenLoginItems,
    ]
    #expect(Set(ids).count == ids.count)
    for id in ids {
      #expect(id.hasPrefix("aura.startup.launchAtLogin."))
      #expect(!id.contains(" "))
    }
  }

  @Test("the Settings view constructs with the approval notice on and off, in both languages")
  @MainActor
  func settingsConstructs() {
    let model = AuraAppModel(startRuntime: false)
    for language in AuraUILanguage.allCases {
      model.productUIState.language = language
      for requiresApproval in [false, true] {
        model.launchAtLoginRequiresApproval = requiresApproval
        _ = AuraSettingsView(model: model, initialCategory: .general).body
      }
    }
    model.bootTask?.cancel()
  }
}
