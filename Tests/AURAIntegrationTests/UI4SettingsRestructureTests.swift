import AuraCore
import Foundation
import Testing

@testable import AURA

@Suite("UI-4 Settings restructure")
struct UI4SettingsRestructureTests {
  @Test("category picker has four stable, localized categories")
  func categoryContract() {
    #expect(
      AuraSettingsCategory.allCases.map(\.rawValue)
        == ["general", "permissions", "integrations", "privacyConfig"])

    for category in AuraSettingsCategory.allCases {
      #expect(AuraCopy.text(category.copyKey, language: .english) != category.copyKey)
      #expect(AuraCopy.text(category.copyKey, language: .turkish) != category.copyKey)
      #expect(!AuraCopy.text(category.copyKey, language: .turkish).isEmpty)
    }
  }

  @Test("category selection is local state and sound remains ADR-gated")
  func categoryStateAndSoundScope() throws {
    let source = try settingsSource()

    #expect(source.contains("@State private var selectedCategory: AuraSettingsCategory"))
    #expect(source.contains("State(initialValue: initialCategory)"))
    #expect(!source.contains("@AppStorage"))
    #expect(!source.contains("selectedCategory" + " = model.productUIState"))
    #expect(!source.contains("settings.soundFeedback"))
    #expect(!source.contains("soundFeedbackEnabled"))
  }

  @Test("every category constructs with the confirmation card first")
  @MainActor
  func cardFirstConstruction() {
    let model = AuraAppModel(startRuntime: false)
    model.pendingConfirmation = challenge()

    for category in AuraSettingsCategory.allCases {
      let settings = AuraSettingsView(model: model, initialCategory: category)
      _ = settings.body
    }
  }

  @Test("the shared card precedes each of the four category branches")
  func cardFirstSourceContract() throws {
    let source = try settingsSource()
    let cardPosition = try #require(source.range(of: "if let challenge = model.pendingConfirmation"))
    let switchPosition = try #require(source.range(of: "switch category"))
    #expect(cardPosition.lowerBound < switchPosition.lowerBound)

    for category in AuraSettingsCategory.allCases {
      let branchPosition = try #require(
        source.range(
          of: "case .\(category.rawValue):",
          range: switchPosition.lowerBound..<source.endIndex))
      #expect(cardPosition.lowerBound < branchPosition.lowerBound)
    }
  }

  @Test("permission summary and actions use only the real snapshot fields")
  func permissionGroupingContract() throws {
    let source = try settingsSource()

    for field in ["microphone", "speechRecognition", "accessibility", "screenRecording"] {
      #expect(source.contains("model.permissions.\(field)"))
    }
    #expect(source.contains("settings.permissions.status"))
    #expect(source.contains("settings.permissions.grant"))
    #expect(source.contains("settings.permissions.systemSettings"))
    #expect(!source.contains("case .pending"))
    #expect(!source.contains("case .authorized"))
    #expect(!source.contains("case .unknown"))
  }

  @Test("existing fail-closed tests remain source-untouched")
  func failClosedTestsRemainUnchanged() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let tests = [
      "Tests/AURAIntegrationTests/ConfirmationSheetFailClosedTests.swift",
      "Tests/AURAIntegrationTests/RuntimeUIRemediationTests.swift",
    ]
    for path in tests {
      let url = repositoryRoot.appendingPathComponent(path)
      let source = try String(contentsOf: url, encoding: .utf8)
      #expect(!source.contains("UI4SettingsRestructureTests"))
      #expect(!source.contains("AuraSettingsCategory"))
    }
  }

  private func settingsSource() throws -> String {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/AURA/AuraMenuView.swift")
    return try String(contentsOf: sourceURL, encoding: .utf8)
  }

  private func challenge() -> PolicyConfirmationChallenge {
    let now = Date()
    return PolicyConfirmationChallenge(
      requestID: UUID(),
      sessionID: UUID(),
      nonce: "ui4-test-nonce",
      issuedAt: now,
      requestedAction: .lifecycleLaunchAtLogin,
      targetSummary: "AURA login item",
      riskTier: .mutation,
      expiresAt: now.addingTimeInterval(60),
      expectedHash: "ui4-test-hash")
  }
}
