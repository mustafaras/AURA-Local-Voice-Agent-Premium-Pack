import Foundation
import SwiftUI
import Testing

@testable import AURA

@Suite("UI-5 Onboarding redesign")
struct UI5OnboardingRedesignTests {
  private static let exactCopy: [(key: String, english: String, turkish: String)] = [
    (
      "onboarding.explain.privacy",
      "Cloud context is disabled by machine policy",
      "Bulut bağlamı makine politikasıyla devre dışı"),
    (
      "onboarding.explain.health",
      "Compatibility and health are shown from the live runtime evidence available to this process.",
      "Uyumluluk ve sağlık göstergeleri bu pencerede gerçek runtime kanıtıyla gösterilir."),
    (
      "onboarding.explain.voicePermissions",
      "Only Microphone and Speech Recognition are requested here. If denied, AURA remains safely restricted.",
      "Yalnızca mikrofon ve Konuşma Tanıma izni istenir. Reddederseniz güvenli kısıtlı mod korunur."),
    (
      "onboarding.explain.voiceTest",
      "Use Push to Talk for one local speech-recognition turn; partial and final transcripts appear in Conversation.",
      "Push to Talk ile tek bir yerel konuşma tanıma turu başlatın; kısmi ve kesin döküm Konuşma sekmesinde görünür."),
    (
      "onboarding.explain.ttsTest",
      "Spoken responses use the configured local TTS pipeline. This setup step does not invent a separate success result.",
      "Sesli yanıt, yapılandırılmış yerel TTS hattından gelir. Ayrı bir sahte başarı sonucu gösterilmez."),
    (
      "onboarding.explain.wakeWord",
      "Wake word is optional; no acoustic model is installed in this configuration, so Push to Talk remains available.",
      "Uyandırma sözcüğü isteğe bağlıdır; mevcut kurulumda akustik model yoktur ve Bas Konuş kullanılabilir."),
    (
      "onboarding.explain.privilegedAccess",
      "Accessibility and Screen Recording are requested only by explicit user action; denied capabilities remain disabled.",
      "Erişilebilirlik ve Ekran Kaydı yalnızca açık kullanıcı eylemiyle istenir; verilmezse yetenekler devre dışı kalır."),
    (
      "onboarding.explain.localModel",
      "Authentication and model availability are unverified",
      "Kimlik doğrulama ve model kullanılabilirliği doğrulanmadı"),
    (
      "onboarding.explain.integrations",
      "Browser, mail, and calendar integrations are optional; no account scope is granted by this step.",
      "Tarayıcı, posta ve takvim entegrasyonları isteğe bağlıdır; bu turda kapsam verilmez."),
    (
      "onboarding.explain.emergencyStop",
      "Emergency stop disables generated input. Test the stop first, then explicitly re-arm it.",
      "Acil durdurma tüm oluşturulan girdileri kapatır. Önce durdurmayı, sonra açıkça yeniden kurmayı deneyin."),
    (
      "onboarding.explain.safeCommand",
      "Use a read-only help or explanation request as the safe first command; side effects are not authorized here.",
      "Güvenli başlangıç komutu olarak yalnızca açıklama/yardım isteği kullanın; yan etkili işlem yetkilendirilmez."),
    (
      "onboarding.explain.launchAtLogin",
      "Launch at login belongs to R11; this step does not change that setting.",
      "Girişte başlatma R11 kapsamındadır; bu adım ayarı değiştirmez."),
    (
      "onboarding.explain.complete",
      "Setup is complete.",
      "Kurulum tamamlandı."),
    (
      "onboarding.primary.voicePermissions",
      "Request permissions",
      "İzinleri iste"),
    (
      "onboarding.primary.voiceTest",
      "Continue to test",
      "Teste geç"),
    (
      "onboarding.primary.emergencyStop",
      "Stop / re-arm",
      "Durdur / yeniden kur"),
    (
      "onboarding.primary.complete",
      "Close",
      "Kapat"),
    ("onboarding.stepCounter", "Step %d of %d", "%d / %d adım"),
    (
      "onboarding.stepAccessibilityLabel",
      "Setup step %d of %d",
      "Kurulum adımı %d / %d"),
    ("onboarding.optionalChip", "Optional", "İsteğe bağlı"),
    ("onboarding.iris", "Iris instrument", "Iris enstrümanı"),
  ]

  @Test("the segmented indicator constructs all 13 positions")
  @MainActor
  func stepIndicatorConstructsAllPositions() {
    let optionalSteps = Set(
      AuraOnboardingStage.allCases.filter(\.isOptional).map(\.rawValue))
    #expect(AuraStepIndicator.totalStepCount == 13)
    #expect(AuraStepIndicator.totalStepCount == AuraOnboardingStage.allCases.count)
    #expect(optionalSteps == [5, 6, 7, 8, 11])

    for step in 0..<AuraStepIndicator.totalStepCount {
      let indicator = AuraStepIndicator(
        currentStep: step,
        optionalSteps: optionalSteps,
        accessibilityLabel: "Setup step \(step + 1) of 13")
      _ = indicator.body
    }

    let designSource = try? sourceFile("Sources/AURA/AuraDesign.swift")
    #expect(designSource?.contains("isAccessibilitySize") == true)
    #expect(designSource?.contains("aura.onboarding.stepIndicator") == true)
    #expect(designSource?.contains("accessibilityHidden(true)") == true)
    #expect(designSource?.contains("AuraDesign.Typography") == true)
  }

  @Test("onboarding copy is exact in both languages and no inline ternaries remain")
  func onboardingCopyContract() throws {
    let source = try onboardingSource()
    #expect(!source.contains("language == .turkish"))
    #expect(!source.contains("ProgressView"))

    for entry in Self.exactCopy {
      #expect(AuraCopy.text(entry.key, language: .english) == entry.english)
      #expect(AuraCopy.text(entry.key, language: .turkish) == entry.turkish)
      #expect(entry.english != entry.turkish)
      #expect(source.contains(entry.key))
    }
  }

  @Test("onboarding presentation constructs every stage in both languages")
  @MainActor
  func onboardingConstructsEveryStage() {
    let model = AuraAppModel(startRuntime: false)
    for language in AuraUILanguage.allCases {
      model.productUIState.language = language
      for stage in AuraOnboardingStage.allCases {
        model.productUIState.onboarding.stage = stage
        _ = AuraOnboardingView(model: model).body
      }
    }
    model.bootTask?.cancel()
  }

  @Test("Iris entry uses the existing Orb and remains still under Reduce Motion")
  @MainActor
  func irisMotionContract() throws {
    let source = try onboardingSource()
    #expect(source.contains("AuraOrb("))
    #expect(source.contains("onboardingHeroOrbScale"))
    #expect(source.contains("onboardingEntryOrbScale"))
    #expect(source.contains("AuraDesign.Motion.motion(AuraDesign.Motion.emergent)"))
    #expect(source.contains("@Environment(\\.accessibilityReduceMotion)"))
    #expect(source.contains("accessibilityLabel(orbAccessibilityLabel)"))

    #expect(
      AuraOnboardingView.onboardingOrbScale(appeared: false, reduceMotion: true)
        == AuraDesign.Measure.onboardingHeroOrbScale)
    #expect(
      AuraOnboardingView.onboardingOrbScale(appeared: false, reduceMotion: false)
        == AuraDesign.Measure.onboardingEntryOrbScale)
    #expect(
      AuraOnboardingView.onboardingOrbScale(appeared: true, reduceMotion: false)
        == AuraDesign.Measure.onboardingHeroOrbScale)

    let orbSource = try sourceFile("Sources/AURA/AuraOrb.swift")
    #expect(orbSource.contains("@Environment(\\.accessibilityReduceMotion)"))
    #expect(orbSource.contains("stillReadout"))
  }

  @Test("the frozen R9 stage-machine test file remains UI-5 untouched")
  func stageMachineFileRemainsUntouched() throws {
    let source = try sourceFile("Tests/AURAIntegrationTests/R9ProductUIStateTests.swift")
    #expect(source.contains("tab, language, confirmation, and onboarding actions reduce deterministically"))
    #expect(source.contains("localization covers every product tab and onboarding stage"))
    #expect(!source.contains("UI5OnboardingRedesignTests"))
    #expect(!source.contains("AuraStepIndicator"))
  }

  private func onboardingSource() throws -> String {
    let source = try sourceFile("Sources/AURA/AuraMenuView.swift")
    let start = try #require(source.range(of: "struct AuraOnboardingView"))
    let end = try #require(source.range(of: "enum AuraSettingsCategory"))
    return String(source[start.lowerBound..<end.lowerBound])
  }

  private func sourceFile(_ relativePath: String) throws -> String {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return try String(
      contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
  }
}
