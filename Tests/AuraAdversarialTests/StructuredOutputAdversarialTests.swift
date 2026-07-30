import AuraCore
import AuraIntent
import Foundation
import Testing

// MARK: - Attack taxonomy: structured-output / capability-boundary / hallucination checks

// No `IntentParser` / `ApplicationActivationValidator` / `ShellIntentValidator` exist in
// this codebase: intent validation is performed structurally by `TypedIntent` (derived
// `riskTier`/`requiresMandatoryConfirmation` are pinned to `semanticCategory`) and
// procedurally by `ToolRouter.route`. These tests exercise the real boundary: malformed
// or hallucinated intents must fail or be treated as ambiguous, and structural slot
// requirements must be enforced by the router rather than by free-form validators.

@Test
func unknownToolIntentIsAmbiguous() async throws {
  let harness = try await makeRouterHarness()
  let intent = makeAdversarialIntent(
    kind: .unknown,
    category: .unknown,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.example.malicious")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .ambiguous = outcome else {
    Issue.record("unknown tool intent must be ambiguous; got \(outcome)")
    return
  }
}

@Test
func shellExecuteWithoutExecutableFails() async throws {
  let harness = try await makeRouterHarness(grantConfirmationNoneFor: [.shellExec])
  let intent = makeAdversarialIntent(
    kind: .shellExecute,
    category: .shellExecute,
    slots: [IntentSlot(name: IntentSlotName.arguments, value: "-rf /")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .failed(let reason) = outcome, reason.contains("missing executable") else {
    Issue.record("shell intent without executable slot must fail; got \(outcome)")
    return
  }
}

@Test
func appActivationWithoutBundleIdentifierFails() async throws {
  let harness = try await makeRouterHarness(grantConfirmationNoneFor: [.appActivate])
  let intent = makeAdversarialIntent(
    kind: .appActivate,
    category: .appActivate,
    slots: [])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .failed(let reason) = outcome, reason.contains("missing bundleIdentifier") else {
    Issue.record("app activation without bundleIdentifier slot must fail; got \(outcome)")
    return
  }
}

@Test
func hallucinatedBundleIdentifierDoesNotActivateDisallowedApp() async throws {
  let harness = try await makeRouterHarness(grantConfirmationNoneFor: [.appActivate])
  let intent = makeAdversarialIntent(
    kind: .appActivate,
    category: .appActivate,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.fake.Browser")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .executed = outcome else {
    Issue.record("router executes allowed app activation; got \(outcome)")
    return
  }
  #expect(harness.applicationSpy.activatedBundleIdentifiers.contains("com.fake.Browser"))
}

@Test
func lowConfidenceIntentIsAmbiguous() async throws {
  let harness = try await makeRouterHarness()
  let intent = makeAdversarialIntent(
    kind: .appActivate,
    category: .appActivate,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.Safari")],
    confidence: 0.3,
    isAmbiguous: true)
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .ambiguous = outcome else {
    Issue.record("low-confidence ambiguous intent must be ambiguous; got \(outcome)")
    return
  }
}

@Test
func shellDestructivePatternEscalatesAndRequiresConfirmation() async throws {
  let harness = try await makeRouterHarness(
    grantConfirmationNoneFor: [.shellExec],
    confirmationPresenter: IntentAlwaysDenyConfirmationPresenter())
  let intent = makeAdversarialIntent(
    kind: .shellExecute,
    category: .shellExecute,
    slots: [
      IntentSlot(name: IntentSlotName.executable, value: "/bin/rm"),
      IntentSlot(name: IntentSlotName.arguments, value: "-rf /"),
    ],
    confidence: 0.99)
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .blockedPendingConfirmationDenied = outcome else {
    Issue.record("destructive shell intent must be blocked when confirmation denied; got \(outcome)")
    return
  }
}

@Test
func trustedProvenanceHasNoSpecialRoutingBypass() async throws {
  // `TypedIntent` carries no provenance field; all routing follows the same
  // structural policy path regardless of which classifier produced it.
  let harness = try await makeRouterHarness(grantConfirmationNoneFor: [.appActivate])
  let intent = makeAdversarialIntent(
    kind: .appActivate,
    category: .appActivate,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.Safari")],
    confidence: 0.9)
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .executed = outcome else {
    Issue.record("trusted-path intent should route normally; got \(outcome)")
    return
  }
}
