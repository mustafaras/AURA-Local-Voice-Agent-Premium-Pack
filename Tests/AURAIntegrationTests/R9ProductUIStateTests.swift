import AuraCore
import Foundation
import Testing

@testable import AURA

@Suite("R9 product UI state")
struct R9ProductUIStateTests {
  @Test("tab, language, confirmation, and onboarding actions reduce deterministically")
  func reducerCoversProductState() {
    var state = AuraProductUIState()

    state.reduce(.selectTab(.privacy))
    state.reduce(.setLanguage(.turkish))
    state.reduce(.showConfirmation)
    state.reduce(.beginOnboarding)

    #expect(state.selectedTab == .privacy)
    #expect(state.language == .turkish)
    #expect(state.confirmationNeedsFocus)
    #expect(state.onboarding.isPresented)
    #expect(state.onboarding.stage == .privacy)

    state.reduce(.advanceOnboarding)
    #expect(state.onboarding.stage == .health)
    state.onboarding.stage = .wakeWord
    state.reduce(.skipOptionalOnboardingStep)
    #expect(state.onboarding.stage == .privilegedAccess)

    state.reduce(.hideConfirmation)
    state.reduce(.closeOnboarding)
    #expect(!state.confirmationNeedsFocus)
    #expect(!state.onboarding.isPresented)
  }

  @Test("localization covers every product tab and onboarding stage")
  func localizationHasNoMissingProductCopy() {
    for tab in AuraProductTab.allCases {
      #expect(AuraCopy.text(tab.copyKey, language: .english) != tab.copyKey)
      #expect(AuraCopy.text(tab.copyKey, language: .turkish) != tab.copyKey)
    }
    for stage in AuraOnboardingStage.allCases {
      #expect(AuraCopy.text(stage.copyKey, language: .english) != stage.copyKey)
      #expect(AuraCopy.text(stage.copyKey, language: .turkish) != stage.copyKey)
    }
  }

  @Test("non-audit memory export document remains Codable")
  func memoryExportDocumentRoundTrips() throws {
    let record = MemoryRecord(
      memoryClass: .userPreference,
      subject: "language",
      statement: "Türkçe",
      provenance: .userStated,
      confidence: 1,
      sensitivity: .internalLevel,
      retention: .indefinite,
      purpose: "user preference")
    let document = AuraMemoryExportDocument(
      generatedAt: Date(timeIntervalSince1970: 1), records: [record], conflicts: [])
    let data = try JSONEncoder().encode(document)
    let decoded = try JSONDecoder().decode(AuraMemoryExportDocument.self, from: data)

    #expect(decoded.records == [record])
    #expect(decoded.conflicts.isEmpty)
  }
}
