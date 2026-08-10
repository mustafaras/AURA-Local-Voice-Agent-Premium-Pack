import AuraCore
import AuraIntent
import AuraPolicy
import Foundation
import Testing

// MARK: - Attack taxonomy: tool spoofing and out-of-schema tool calls

@Test
func routerRejectsUnknownToolIntent() async throws {
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
func routerRejectsOutOfSchemaBundleSlotOnShellExecute() async throws {
  // A shellExecute intent with a bundle-identifier slot is structurally
  // inconsistent; the router must not treat it as a valid app activation.
  let harness = try await makeRouterHarness(grantConfirmationNoneFor: [.shellExec])
  let intent = makeAdversarialIntent(
    kind: .shellExecute,
    category: .shellExecute,
    slots: [
      IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.Safari"),
      IntentSlot(name: IntentSlotName.executable, value: "/bin/echo"),
    ])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  // The shell path ignores the bundle slot; it still executes echo with no args.
  guard case .executed = outcome else {
    Issue.record("shell path should execute echo; got \(outcome)")
    return
  }
  #expect(harness.applicationSpy.activatedBundleIdentifiers.isEmpty)
}

@Test
func routerDoesNotActivateAppFromConverseIntent() async throws {
  let harness = try await makeRouterHarness(grantConfirmationNoneFor: [.appActivate])
  let intent = makeAdversarialIntent(
    kind: .converse,
    category: .converse,
    slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.Safari")])
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .executed(_, let hasSpokenResponse) = outcome else {
    Issue.record("converse intent should produce spoken response; got \(outcome)")
    return
  }
  #expect(hasSpokenResponse)
  #expect(harness.applicationSpy.activatedBundleIdentifiers.isEmpty)
}

@Test
func routerRejectsDestructiveShellIntentWithoutConfirmation() async throws {
  let harness = try await makeRouterHarness(
    grantConfirmationNoneFor: [.shellExec])
  let intent = makeAdversarialIntent(
    kind: .shellExecute,
    category: .shellDestructive,
    slots: [
      IntentSlot(name: IntentSlotName.executable, value: "/bin/rm"),
      IntentSlot(name: IntentSlotName.arguments, value: "-rf /"),
    ],
    confidence: 0.99)
  let outcome = await harness.router.route(
    intent, actor: .intent, sessionID: harness.sessionID, correlationID: UUID(),
    causationID: UUID())
  guard case .blockedPendingConfirmationDenied = outcome else {
    Issue.record(
      "destructive shell intent without explicit confirmation must be blocked; got \(outcome)")
    return
  }
}

@Test
func routerRejectsLowConfidenceIntentAsAmbiguous() async throws {
  let harness = try await makeRouterHarness()
  let intent = makeAdversarialIntent(
    kind: .shellExecute,
    category: .shellExecute,
    slots: [
      IntentSlot(name: IntentSlotName.executable, value: "/bin/echo"),
      IntentSlot(name: IntentSlotName.arguments, value: "hello"),
    ],
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
