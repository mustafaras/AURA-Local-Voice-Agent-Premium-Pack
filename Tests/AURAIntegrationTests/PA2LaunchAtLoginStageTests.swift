import Foundation
import SwiftUI
import Testing

@testable import AURA

/// ADR-066 (PA-2 G2-2): the onboarding `launchAtLogin` stage is informational
/// — statement copy from `03-launch-at-login-always-on.md` §3.2, a live
/// status row, and the Login Items link in the approval state. The stage
/// machine (UI-5 / ADR-063) is behavior-frozen: order, optionality, and
/// persistence are asserted unchanged here and by the R9 / UI-5 tests.
@Suite("PA-2 launch-at-login onboarding stage")
struct PA2LaunchAtLoginStageTests {
  @Test("§3.2 statement copy in EN and TR")
  func statementCopy() {
    #expect(
      AuraCopy.text("onboarding.explain.launchAtLogin", language: .english)
        == "AURA starts automatically when you log in. You can turn this off in Settings.")
    #expect(
      AuraCopy.text("onboarding.explain.launchAtLogin", language: .turkish)
        == "AURA giriş yaptığınızda otomatik başlar. Ayarlar'dan kapatabilirsiniz.")
    for key in [
      "onboarding.launchAtLogin.on", "onboarding.launchAtLogin.off",
      "onboarding.launchAtLogin.awaitingApproval",
    ] {
      for language in AuraUILanguage.allCases {
        #expect(!AuraCopy.text(key, language: language).hasPrefix("onboarding."), "missing \(key)")
      }
      #expect(AuraCopy.text(key, language: .english) != AuraCopy.text(key, language: .turkish))
    }
    #expect(AuraCopy.text("onboarding.launchAtLogin.awaitingApproval", language: .turkish) == "Onay bekliyor")
  }

  @Test("stage machine unchanged: launchAtLogin stays last, optional, and in the same order")
  func stageMachineUnchanged() {
    #expect(AuraOnboardingStage.launchAtLogin.isOptional)
    let stages = AuraOnboardingStage.allCases
    #expect(stages.last == .complete)
    #expect(stages.firstIndex(of: .launchAtLogin) == stages.count - 2)
    #expect(stages.firstIndex(of: .safeCommand)! < stages.firstIndex(of: .launchAtLogin)!)
  }

  @Test("stage identifiers are distinct, scoped, and unlocalized")
  func identifiers() {
    let ids = [
      AuraAccessibilityID.onboardingLaunchAtLoginStatus,
      AuraAccessibilityID.onboardingLaunchAtLoginOpenLoginItems,
    ]
    #expect(Set(ids).count == ids.count)
    for id in ids {
      #expect(id.hasPrefix("aura.onboarding.launchAtLogin."))
      #expect(!id.contains(" "))
    }
    #expect(!Set(ids).contains(AuraAccessibilityID.launchAtLoginOpenLoginItems))
  }

  @Test("the launchAtLogin stage constructs with the status row in every state and language")
  @MainActor
  func stageConstructsWithStatusRow() {
    let model = AuraAppModel(startRuntime: false)
    model.productUIState.onboarding.stage = .launchAtLogin
    for language in AuraUILanguage.allCases {
      model.productUIState.language = language
      for (enabled, approval) in [(true, false), (false, false), (false, true)] {
        model.launchAtLoginEnabled = enabled
        model.launchAtLoginRequiresApproval = approval
        _ = AuraOnboardingView(model: model).body
      }
    }
    model.bootTask?.cancel()
  }
}
