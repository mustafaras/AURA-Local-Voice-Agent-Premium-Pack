import AuraCore
import Foundation
import Testing

// MARK: - Residual risk: live-caller and red-team documentation

// The residual-risk registry lives in code so that red-team categories
// referenced by ADR-033 cannot silently drift from the operational documents.
// It is intentionally lightweight: categories, owners, mitigation one-liners,
// default actions, and links to playbooks.

/// Verifies that the documented residual-risk registry contains the
/// categories referenced by ADR-033 and does not silently disappear.
@Test
func residualRiskRegistryContainsExpectedCategories() {
  let registry = ResidualRiskRegistry.current
  let expected: [ResidualRiskCategory] = [
    .promptInjection,
    .toolSpoofing,
    .policyBypass,
    .memoryPoisoning,
    .pluginSupplyChain,
    .configurationTampering,
    .structuredOutputViolation,
    .liveCallerManipulation,
    .unknownFailureMode,
  ]
  for category in expected {
    let entry = registry[category]
    #expect(entry != nil, "residual risk registry must document \(category)")
  }
}

@Test
func liveCallerRiskRequiresExplicitEscalation() {
  let registry = ResidualRiskRegistry.current
  let entry = registry[.liveCallerManipulation]
  #expect(entry?.requiresEscalation == true)
  #expect(entry?.mitigation.contains("human loop") == true)
}

@Test
func everyResidualRiskHasOwner() {
  let registry = ResidualRiskRegistry.current
  for entry in registry.allEntries {
    #expect(!entry.owner.isEmpty, "risk \(entry.category) must have an owner")
  }
}

@Test
func unknownFailureModeHasFailClosedDefault() {
  let registry = ResidualRiskRegistry.current
  let entry = registry[.unknownFailureMode]
  #expect(entry?.defaultAction == .deny)
}

/// Verifies that the adversarial incident response playbooks are linked
/// from the registry so that red-team findings route to the correct runbook.
@Test
func adversarialIncidentResponsePlaybooksReferenced() {
  let registry = ResidualRiskRegistry.current
  let injection = registry[.promptInjection]
  #expect(injection?.playbookID == "ADVR-001")
  let supplyChain = registry[.pluginSupplyChain]
  #expect(supplyChain?.playbookID == "ADVR-003")
}
