import AuraAutomation
import AuraCore
import AuraIntent
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

// MARK: - Harness

private struct RouterHarness {
  let router: ToolRouter
  let policyEngine: PolicyEngine
  let applicationSpy: ApplicationControllerSpy
  let sessionID: UUID
}

private func makeIntent(
  kind: IntentKind,
  category: IntentSemanticCategory,
  slots: [IntentSlot] = [],
  confidence: Double = 0.9,
  isAmbiguous: Bool = false,
  language: DialogueLanguage = .unknown
) -> TypedIntent {
  TypedIntent(
    turnCorrelationID: UUID(), kind: kind, semanticCategory: category, rawUtterance: "",
    normalizedUtterance: "", slots: slots, classificationConfidence: confidence,
    isAmbiguous: isAmbiguous,
    language: language,
    dialogueAct: isAmbiguous ? .clarify : .execute)
}

private func makeHarness(
  allowByDefaultTiers: Set<PermissionRiskTier> = [.observation, .reversible, .mutation, .destructive],
  grantConfirmationNoneFor: [Capability] = [],
  confirmationPresenter: any IntentConfirmationPresenting = IntentAlwaysDenyConfirmationPresenter(),
  configuration: IntentEngineConfiguration = IntentEngineConfiguration()
) async throws -> RouterHarness {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "router"))
  let policyEngine = try await makeTestPolicyEngine(
    eventBus: bus, allowByDefaultTiers: allowByDefaultTiers,
    grantConfirmationNoneFor: grantConfirmationNoneFor)
  let spy = ApplicationControllerSpy()
  let automation = makeAutomation(spy: spy, eventBus: bus)
  let shell = AuraShell(configuration: ShellConfiguration())
  let store = try await makeTestStore()
  let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
  let (agentRunner, sessionID) = makeAgentBackendTaskRunner(policyEngine: policyEngine, eventBus: bus)
  let capabilityRegistry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: capabilityRegistry)
  let router = ToolRouter(
    policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
    agentTaskRunner: agentRunner, capabilityRegistry: capabilityRegistry,
    confirmationPresenter: confirmationPresenter, eventBus: bus, configuration: configuration)
  return RouterHarness(
    router: router, policyEngine: policyEngine, applicationSpy: spy, sessionID: sessionID)
}

// MARK: - Ambiguity short-circuit

@Test
func routerNeverTouchesPolicyForAmbiguousIntent() async throws {
  // Deny everything by default; if the router incorrectly attempted policy
  // evaluation for an ambiguous intent, this would surface as a policy
  // denial rather than an ambiguity outcome.
  let harness = try await makeHarness(allowByDefaultTiers: [])
  let intent = makeIntent(kind: .unknown, category: .unknown, isAmbiguous: true)
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .ambiguous = outcome else {
    Issue.record("expected ambiguous, got \(outcome)")
    return
  }
}

@Test
func routerClarifiesUnknownTurkishApplicationInTurkish() async throws {
  let harness = try await makeHarness(allowByDefaultTiers: [])
  let intent = makeIntent(
    kind: .unknown,
    category: .unknown,
    slots: [IntentSlot(name: IntentSlotName.unresolvedAppName, value: "bilinmeyen")],
    isAmbiguous: true,
    language: .turkish)
  let outcome = await harness.router.route(
    intent,
    actor: .intent,
    sessionID: harness.sessionID,
    correlationID: UUID(),
    causationID: UUID())
  guard case .ambiguous(let question) = outcome else {
    Issue.record("expected ambiguous, got \(outcome)")
    return
  }
  #expect(question.contains("uygulamasını"))
}

// MARK: - Converse

@Test
func routerHandlesConverseWithoutPolicyEvaluation() async throws {
  let harness = try await makeHarness(allowByDefaultTiers: [])  // deny everything
  let intent = makeIntent(kind: .converse, category: .converse)
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .executed(_, let hasSpokenResponse) = outcome else {
    Issue.record("expected executed, got \(outcome)")
    return
  }
  #expect(hasSpokenResponse)
}

// MARK: - App activate / terminate

@Test
func routerActivatesApplicationWhenGranted() async throws {
  let harness = try await makeHarness(grantConfirmationNoneFor: [.appActivate])
  let intent = makeIntent(
    kind: .appActivate, category: .appActivate,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.Safari")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .executed = outcome else {
    Issue.record("expected executed, got \(outcome)")
    return
  }
  #expect(harness.applicationSpy.activatedBundleIdentifiers == ["com.apple.Safari"])
}

@Test
func routerDeniesAppActivateWithNoGrantOrAllowedTier() async throws {
  let harness = try await makeHarness(allowByDefaultTiers: [.observation])
  let intent = makeIntent(
    kind: .appActivate, category: .appActivate,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.Safari")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .blockedByPolicy = outcome else {
    Issue.record("expected blockedByPolicy, got \(outcome)")
    return
  }
  #expect(harness.applicationSpy.activatedBundleIdentifiers.isEmpty)
}

@Test
func routerTerminatesApplicationWhenGranted() async throws {
  let harness = try await makeHarness(grantConfirmationNoneFor: [.appTerminate])
  let intent = makeIntent(
    kind: .appTerminate, category: .appTerminate,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.mail")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .executed = outcome else {
    Issue.record("expected executed, got \(outcome)")
    return
  }
  #expect(harness.applicationSpy.quitBundleIdentifiers == ["com.apple.mail"])
}

@Test
func routerConfirmationDeniedBlocksAppTerminate() async throws {
  // No grant seeded, but allow the .mutation tier by default so evaluate()
  // reaches the default-confirmation-tier check and returns `.confirm`
  // rather than an outright deny — proving the confirmation-denied path
  // distinctly from the plain policy-denied path above.
  let harness = try await makeHarness(
    allowByDefaultTiers: [.observation, .reversible, .mutation, .destructive],
    confirmationPresenter: IntentAlwaysDenyConfirmationPresenter())
  let intent = makeIntent(
    kind: .appTerminate, category: .appTerminate,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.mail")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .blockedPendingConfirmationDenied = outcome else {
    Issue.record("expected blockedPendingConfirmationDenied, got \(outcome)")
    return
  }
  #expect(harness.applicationSpy.quitBundleIdentifiers.isEmpty)
}

@Test
func routerFailsGracefullyWhenAutomationThrows() async throws {
  let harness = try await makeHarness(grantConfirmationNoneFor: [.appActivate])
  harness.applicationSpy.shouldFail = true
  let intent = makeIntent(
    kind: .appActivate, category: .appActivate,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.Safari")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .failed = outcome else {
    Issue.record("expected failed, got \(outcome)")
    return
  }
}

// MARK: - Shell execute

@Test
func routerExecutesNonDestructiveShellCommand() async throws {
  let harness = try await makeHarness(grantConfirmationNoneFor: [.shellExec])
  let intent = makeIntent(
    kind: .shellExecute, category: .shellExecute,
    slots: [
      IntentSlot(name: IntentSlotName.executable, value: "/bin/echo"),
      IntentSlot(name: IntentSlotName.arguments, value: "hello"),
    ])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .executed = outcome else {
    Issue.record("expected executed, got \(outcome)")
    return
  }
}

@Test
func routerBlocksDestructiveShellPatternEvenWithPermissiveGrant() async throws {
  // Deliberately seed a .none-confirmation grant for BOTH the plain and
  // destructive shell capabilities — this proves the mandatory-confirmation
  // guard is non-bypassable by grant configuration, mirroring
  // ComputerUseControlLoop's "even a permissive grant" test precedent.
  let harness = try await makeHarness(
    grantConfirmationNoneFor: [.shellExec, .shellExecDestructive])
  let intent = makeIntent(
    kind: .shellExecute, category: .shellExecute,
    slots: [
      IntentSlot(name: IntentSlotName.executable, value: "/bin/rm"),
      IntentSlot(name: IntentSlotName.arguments, value: "-rf /"),
    ])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .blockedPendingConfirmationDenied = outcome else {
    Issue.record("expected blockedPendingConfirmationDenied, got \(outcome)")
    return
  }
}

@Test
func routerDestructiveShellIsNeverSilentlyExecutedEvenWithFullyPermissiveTiers() async throws {
  // `makeHarness()`'s default `allowByDefaultTiers` includes `.destructive`
  // itself — the most permissive tier configuration possible — with no
  // grant seeded at all. Even here, `.shellExecDestructive`'s risk tier
  // (`.destructive`) meets `defaultConfirmationTier` (`.mutation`), so
  // `PolicyEngine` still routes it to `.confirm`, and the production-
  // default `IntentAlwaysDenyConfirmationPresenter` refuses it. Proves a
  // permissive default-tier policy config alone can never let a
  // destructive shell command through unconfirmed.
  let harness = try await makeHarness()  // no grants seeded at all
  let intent = makeIntent(
    kind: .shellExecute, category: .shellExecute,
    slots: [
      IntentSlot(name: IntentSlotName.executable, value: "/bin/dd"),
      IntentSlot(name: IntentSlotName.arguments, value: "of=/dev/disk0"),
    ])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .blockedPendingConfirmationDenied = outcome else {
    Issue.record("expected blockedPendingConfirmationDenied, got \(outcome)")
    return
  }
}

// MARK: - Coding agent run

@Test
func routerAcknowledgesCodingAgentRunPromptlyWithoutEvaluatingPolicyItself() async throws {
  // Deny everything by default at the router level — the coding-agent path
  // must never call PolicyEngine.evaluate itself (the wrapped CLI adapter
  // does its own internal check when the background task actually runs).
  let harness = try await makeHarness(allowByDefaultTiers: [])
  let intent = makeIntent(
    kind: .codingAgentRun, category: .codingAgentRun,
    slots: [
      IntentSlot(name: IntentSlotName.backend, value: "codex"),
      IntentSlot(name: IntentSlotName.objective, value: "fix the failing test"),
    ])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .acknowledgedAsync = outcome else {
    Issue.record("expected acknowledgedAsync, got \(outcome)")
    return
  }
}

@Test
func routerRejectsUnsupportedCodingAgentBackend() async throws {
  let harness = try await makeHarness()
  let intent = makeIntent(
    kind: .codingAgentRun, category: .codingAgentRun,
    slots: [
      IntentSlot(name: IntentSlotName.backend, value: "gemini"),
      IntentSlot(name: IntentSlotName.objective, value: "fix the failing test"),
    ])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .failed = outcome else {
    Issue.record("expected failed, got \(outcome)")
    return
  }
}
