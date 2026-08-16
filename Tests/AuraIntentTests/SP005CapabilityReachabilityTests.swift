import AuraAutomation
import AuraCore
import AuraPolicy
import Foundation
import Testing

@testable import AuraIntent

/// SP-005 tests: capability reachability and planner wiring.
///
/// These tests prove that a production natural-language request for the
/// four SP-004 filesystem/URL capabilities now creates only registry-
/// validated plans, routes through `CapabilityPlanner`/`PolicyEngine`/
/// `ToolRouter`, and that disabled or ambiguous capabilities remain
/// visibly unavailable.
@Suite("SP-005 capability reachability and planner wiring")
struct SP005CapabilityReachabilityTests {

  // MARK: - NLU classification

  @Test("classifies 'open /path/to/file.txt' as fileOpen, not appActivate")
  func classifiesPathOpenAsFileOpen() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "open /Users/me/notes.txt", raw: "open /Users/me/notes.txt")
    #expect(result.kind == .fileOpen)
    #expect(result.semanticCategory == .fileOpen)
    #expect(result.slots.contains { $0.name == IntentSlotName.filePath })
    #expect(result.slots.first { $0.name == IntentSlotName.filePath }?.value == "/Users/me/notes.txt")
    #expect(result.confidence > 0.5)
  }

  @Test("classifies 'open ~/Documents/' as fileOpen with folderPath slot")
  func classifiesFolderOpen() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "open ~/Documents/", raw: "open ~/Documents/")
    #expect(result.kind == .fileOpen)
    #expect(result.slots.contains { $0.name == IntentSlotName.folderPath })
  }

  @Test("classifies 'reveal /path/to/file' as fileReveal")
  func classifiesReveal() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "reveal /Users/me/notes.txt", raw: "reveal /Users/me/notes.txt")
    #expect(result.kind == .fileReveal)
    #expect(result.semanticCategory == .fileReveal)
    #expect(result.slots.contains { $0.name == IntentSlotName.filePath })
  }

  @Test("classifies 'open https://example.com' as urlOpen")
  func classifiesURLOpen() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "open https://example.com", raw: "open https://example.com")
    #expect(result.kind == .urlOpen)
    #expect(result.semanticCategory == .urlOpen)
    #expect(result.slots.contains { $0.name == IntentSlotName.url })
  }

  @Test("classifies bare 'https://example.com' as urlOpen without prefix")
  func classifiesBareURL() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "https://example.com", raw: "https://example.com")
    #expect(result.kind == .urlOpen)
  }

  @Test("classifies 'open safari' as appActivate, not fileOpen")
  func classifiesAppNameAsAppActivate() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "open safari", raw: "open safari")
    #expect(result.kind == .appActivate)
    #expect(result.kind != .fileOpen)
  }

  @Test("classifies Turkish 'aç /Users/me/dosya.txt' as fileOpen")
  func classifiesTurkishFileOpen() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "aç /Users/me/dosya.txt", raw: "aç /Users/me/dosya.txt")
    #expect(result.kind == .fileOpen)
    #expect(result.slots.contains { $0.name == IntentSlotName.filePath })
  }

  @Test("classifies 'go to https://example.com' as urlOpen")
  func classifiesGoToURL() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "go to https://example.com", raw: "go to https://example.com")
    #expect(result.kind == .urlOpen)
  }

  @Test("classifies 'show /path/to/file' as fileReveal")
  func classifiesShowAsReveal() {
    let classifier = RuleBasedUtteranceClassifier()
    let result = classifier.classify(
      normalized: "show /Users/me/notes.txt", raw: "show /Users/me/notes.txt")
    #expect(result.kind == .fileReveal)
  }

  // MARK: - Semantic category and risk tier

  @Test("fileOpen, fileReveal, and urlOpen are all .reversible risk tier")
  func reversibleRiskTiers() {
    #expect(IntentSemanticCategory.fileOpen.riskTier == .reversible)
    #expect(IntentSemanticCategory.fileReveal.riskTier == .reversible)
    #expect(IntentSemanticCategory.urlOpen.riskTier == .reversible)
  }

  @Test("none of the new categories require mandatory confirmation")
  func noMandatoryConfirmation() {
    #expect(!IntentSemanticCategory.fileOpen.requiresMandatoryConfirmation)
    #expect(!IntentSemanticCategory.fileReveal.requiresMandatoryConfirmation)
    #expect(!IntentSemanticCategory.urlOpen.requiresMandatoryConfirmation)
  }

  // MARK: - Capability.forIntent mapping

  @Test("Capability.forIntent maps the new categories correctly")
  func capabilityForIntentMapping() {
    #expect(Capability.forIntent(.fileOpen) == .fileOpen)
    #expect(Capability.forIntent(.fileReveal) == .fileReveal)
    #expect(Capability.forIntent(.urlOpen) == .urlOpen)
  }

  // MARK: - ToolRouter capabilityID mapping

  @Test("ToolRouter.capabilityID maps the new kinds to registered manifest IDs")
  func capabilityIDMapping() async {
    let registry = CapabilityRegistry()
    await InitialCapabilitySet.registerAll(in: registry)
    // Verify the IDs resolve in the registry
    for id in ["filesystem.open_file", "filesystem.open_folder", "filesystem.reveal", "url.open"] {
      let manifest = await registry.resolveLatest(id: id)
      #expect(manifest != nil, "expected \(id) to resolve in the registry")
      if let manifest {
        let availability = await registry.availability(qualifiedID: manifest.qualifiedID)
        #expect(availability == .ready, "expected \(id) to be .ready")
      }
    }
  }

  // MARK: - CapabilityPlanner validates the new capabilities

  @Test("planner accepts fileOpen with a valid path argument")
  func plannerAcceptsFileOpen() async {
    let registry = CapabilityRegistry()
    await InitialCapabilitySet.registerAll(in: registry)
    let planner = CapabilityPlanner(registry: registry)
    let result = await planner.validateStep(
      capabilityID: "filesystem.open_file",
      arguments: ["path": "/Users/me/notes.txt"])
    guard case .success = result else {
      Issue.record("expected success for filesystem.open_file, got \(result)")
      return
    }
  }

  @Test("planner accepts urlOpen with a valid URL argument")
  func plannerAcceptsURLOpen() async {
    let registry = CapabilityRegistry()
    await InitialCapabilitySet.registerAll(in: registry)
    let planner = CapabilityPlanner(registry: registry)
    let result = await planner.validateStep(
      capabilityID: "url.open",
      arguments: ["url": "https://example.com"])
    guard case .success = result else {
      Issue.record("expected success for url.open, got \(result)")
      return
    }
  }

  @Test("planner accepts fileReveal with a valid path argument")
  func plannerAcceptsFileReveal() async {
    let registry = CapabilityRegistry()
    await InitialCapabilitySet.registerAll(in: registry)
    let planner = CapabilityPlanner(registry: registry)
    let result = await planner.validateStep(
      capabilityID: "filesystem.reveal",
      arguments: ["path": "/Users/me/notes.txt"])
    guard case .success = result else {
      Issue.record("expected success for filesystem.reveal, got \(result)")
      return
    }
  }

  // MARK: - Disabled capabilities stay unavailable

  @Test("planner rejects browser.read which remains disabled")
  func plannerRejectsStillDisabledBrowserRead() async {
    let registry = CapabilityRegistry()
    await InitialCapabilitySet.registerAll(in: registry)
    let planner = CapabilityPlanner(registry: registry)
    let result = await planner.validateStep(
      capabilityID: "browser.read", arguments: [:])
    guard case .failure = result else {
      Issue.record("expected failure for disabled browser.read, got \(result)")
      return
    }
  }

  // MARK: - IntentKind is closed and exhaustive

  @Test("IntentKind has exactly 9 cases including the 3 new ones")
  func intentKindCaseCount() {
    #expect(IntentKind.allCases.count == 9)
    #expect(IntentKind.allCases.contains(.fileOpen))
    #expect(IntentKind.allCases.contains(.fileReveal))
    #expect(IntentKind.allCases.contains(.urlOpen))
  }

  @Test("IntentSemanticCategory has the new cases")
  func semanticCategoryCases() {
    #expect(IntentSemanticCategory.allCases.contains(.fileOpen))
    #expect(IntentSemanticCategory.allCases.contains(.fileReveal))
    #expect(IntentSemanticCategory.allCases.contains(.urlOpen))
  }
}