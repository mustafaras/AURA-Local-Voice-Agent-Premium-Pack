import Foundation
import Testing

@testable import AuraCore

/// ADR-065 §2 (PA-1 G1-2): the Keychain namespace is derived from the code
/// identity — the production service name only for the stable identity,
/// `<name>.dev` for everything else.
@Suite("AppConfiguration.effectiveServiceName (ADR-065)")
struct ServiceNameDerivationTests {
  @Test("stable identity keeps the configured production service name")
  func stableKeepsProductionName() {
    #expect(AppConfiguration.effectiveServiceName("AuraCore", isStableIdentity: true) == "AuraCore")
    #expect(
      AppConfiguration(serviceName: "ai.aura.local.agent")
        .effectiveServiceName(isStableIdentity: true) == "ai.aura.local.agent")
  }

  @Test("any non-stable identity is routed to the .dev namespace")
  func nonStableGetsDevSuffix() {
    #expect(
      AppConfiguration.effectiveServiceName("AuraCore", isStableIdentity: false) == "AuraCore.dev")
    #expect(
      AppConfiguration(serviceName: "com.aura.safari-bridge")
        .effectiveServiceName(isStableIdentity: false) == "com.aura.safari-bridge.dev")
  }

  @Test("the two namespaces never collide")
  func namespacesDisjoint() {
    for name in ["AuraCore", "com.aura.safari-bridge", "com.aura.vscode-bridge"] {
      let production = AppConfiguration.effectiveServiceName(name, isStableIdentity: true)
      let development = AppConfiguration.effectiveServiceName(name, isStableIdentity: false)
      #expect(production != development)
      #expect(development.hasSuffix(AppConfiguration.developmentNamespaceSuffix))
      #expect(!production.hasSuffix(AppConfiguration.developmentNamespaceSuffix))
    }
  }

  @Test("derivation is pure: same inputs, same output")
  func derivationIsPure() {
    let a = AppConfiguration.effectiveServiceName("X", isStableIdentity: false)
    let b = AppConfiguration.effectiveServiceName("X", isStableIdentity: false)
    #expect(a == b)
  }
}
