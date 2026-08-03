import AuraCore
import AuraStore
import Foundation
import Testing

@testable import AuraPolicy

// MARK: - Helpers

actor Capture {
  var emitted: [any EventPayload] = []

  func capture(_ payload: any EventPayload) {
    emitted.append(payload)
  }

  func clear() {
    emitted.removeAll()
  }

  func payloads<T: EventPayload>(ofType: T.Type) -> [T] {
    emitted.compactMap { $0 as? T }
  }
}

func makeStore() async throws -> AuraStore {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  let path = dir.appendingPathComponent("test.sqlite").path
  return try await AuraStore(path: path)
}

func makeEngine(store: AuraStore? = nil, capture: Capture = Capture()) async throws(AuraError) -> (
  PolicyEngine, Capture
) {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraPolicyTests", category: "bus"))
  await bus.subscribe(PolicyEvaluationRequestedEvent.self) {
    (envelope: EventEnvelope<PolicyEvaluationRequestedEvent>) async in
    await capture.capture(envelope.payload)
  }
  await bus.subscribe(PolicyDecisionEvent.self) {
    (envelope: EventEnvelope<PolicyDecisionEvent>) async in await capture.capture(envelope.payload)
  }
  await bus.subscribe(PolicyConfirmationRequestedEvent.self) {
    (envelope: EventEnvelope<PolicyConfirmationRequestedEvent>) async in
    await capture.capture(envelope.payload)
  }
  await bus.subscribe(PolicyConfirmationRespondedEvent.self) {
    (envelope: EventEnvelope<PolicyConfirmationRespondedEvent>) async in
    await capture.capture(envelope.payload)
  }
  await bus.subscribe(PolicyRuleMutationEvent.self) {
    (envelope: EventEnvelope<PolicyRuleMutationEvent>) async in
    await capture.capture(envelope.payload)
  }
  let config = PolicyConfiguration(
    defaultConfirmationTier: .mutation,
    confirmationExpirySeconds: 60,
    allowByDefaultTiers: [.observation],
    denyByDefaultTiers: [.reversible, .mutation, .destructive]
  )
  return (try await PolicyEngine(configuration: config, eventBus: bus, store: store), capture)
}

func request(
  capability: Capability,
  actor: ActorID = .user,
  target: PolicyTarget = .empty,
  arguments: [String] = [],
  environment: [String: String] = [:],
  sessionID: UUID = UUID()
) -> PolicyEvaluationRequest {
  PolicyEvaluationRequest(
    capability: capability,
    actor: actor,
    target: target,
    arguments: arguments,
    environment: environment,
    sessionID: sessionID,
    correlationID: UUID(),
    causationID: UUID()
  )
}

// MARK: - Tests

@Test
func policyEngineAllowsObservationByDefault() async throws {
  let (engine, capture) = try await makeEngine()
  let req = request(capability: .screenReadText)
  let decision = await engine.evaluate(req)
  guard case .allow = decision else {
    Issue.record("Expected allow, got \(decision)")
    return
  }
  #expect(await capture.payloads(ofType: PolicyDecisionEvent.self).last?.decision == "allow")
}

@Test
func policyEngineDeniesDestructiveByDefault() async throws {
  let (engine, capture) = try await makeEngine()
  let req = request(capability: .fileDelete)
  let decision = await engine.evaluate(req)
  guard case .deny = decision else {
    Issue.record("Expected deny decision, got \(decision)")
    return
  }
  #expect(await capture.payloads(ofType: PolicyDecisionEvent.self).last?.decision == "deny")
}

@Test
func denyRuleOverridesAllowByDefault() async throws {
  let store = try await makeStore()
  let (engine, _) = try await makeEngine(store: store)
  let rule = DenyRule(capability: .fileRead, patterns: [.any], reason: "file read denied")
  try await engine.upsertDenyRule(rule)
  let req = request(capability: .fileRead)
  let decision = await engine.evaluate(req)
  guard case .deny(let reason, _) = decision else {
    Issue.record("Expected deny, got \(decision)")
    return
  }
  #expect(reason == "file read denied")
}

@Test
func grantAllowsMissingDefault() async throws {
  let (engine, _) = try await makeEngine()
  let grant = Grant(
    capability: .fileWrite,
    patterns: [.any],
    confirmationRequirement: .none
  )
  try await engine.issueGrant(grant)
  let req = request(capability: .fileWrite)
  let decision = await engine.evaluate(req)
  guard case .allow(_, let grantID) = decision else {
    Issue.record("Expected allow, got \(decision)")
    return
  }
  #expect(grantID == grant.id)
}

@Test
func scopeMismatchDenies() async throws {
  let (engine, _) = try await makeEngine()
  let grant = Grant(
    capability: .appActivate,
    patterns: [.appID("com.example.allowed")],
    confirmationRequirement: .none
  )
  try await engine.issueGrant(grant)
  let req = request(capability: .appActivate, target: PolicyTarget(appID: "com.example.denied"))
  let decision = await engine.evaluate(req)
  guard case .deny = decision else {
    Issue.record("Expected deny for scope mismatch, got \(decision)")
    return
  }
}

@Test
func argumentDenyRuleDenies() async throws {
  let (engine, _) = try await makeEngine()
  let rule = DenyRule(
    capability: .shellExec,
    patterns: [.argument(allowed: ["ls", "pwd"])],
    reason: "unauthorized argument"
  )
  try await engine.upsertDenyRule(rule)
  let req = request(capability: .shellExec, arguments: ["rm", "-rf", "/"])
  let decision = await engine.evaluate(req)
  guard case .deny = decision else {
    Issue.record("Expected deny for argument mismatch, got \(decision)")
    return
  }
}

@Test
func environmentDenyRuleDenies() async throws {
  let (engine, _) = try await makeEngine()
  let rule = DenyRule(
    capability: .shellExec,
    patterns: [.environment(keys: ["PATH", "HOME"])],
    reason: "unauthorized environment variable"
  )
  try await engine.upsertDenyRule(rule)
  let req = request(capability: .shellExec, environment: ["PATH": "/bin", "SECRET": "x"])
  let decision = await engine.evaluate(req)
  guard case .deny = decision else {
    Issue.record("Expected deny for environment mismatch, got \(decision)")
    return
  }
}

@Test
func expiredGrantDoesNotAuthorize() async throws {
  let (engine, _) = try await makeEngine()
  let grant = Grant(
    capability: .fileWrite,
    patterns: [.any],
    confirmationRequirement: .none,
    expiresAt: Date(timeIntervalSinceNow: -1)
  )
  try await engine.issueGrant(grant)
  let req = request(capability: .fileWrite)
  let decision = await engine.evaluate(req)
  guard case .deny = decision else {
    Issue.record("Expected deny for expired grant, got \(decision)")
    return
  }
}

@Test
func alwaysConfirmationIssuesChallenge() async throws {
  let (engine, capture) = try await makeEngine()
  let grant = Grant(
    capability: .appActivate,
    patterns: [.any],
    confirmationRequirement: .always
  )
  try await engine.issueGrant(grant)
  let req = request(capability: .appActivate)
  let decision = await engine.evaluate(req)
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("Expected confirm, got \(decision)")
    return
  }
  #expect(challenge.requestedAction == .appActivate)
  #expect(await capture.payloads(ofType: PolicyConfirmationRequestedEvent.self).count == 1)
}

@Test
func confirmedPolicyRequestHasOneTimeExecutionAndVerificationLifecycle() async throws {
  let (engine, _) = try await makeEngine()
  let sessionID = UUID()
  let context = TurnContext(
    sessionID: sessionID,
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let grant = Grant(
    capability: .appTerminate,
    patterns: [.any],
    confirmationRequirement: .always)
  try await engine.issueGrant(grant)
  let request = PolicyEvaluationRequest(
    capability: .appTerminate,
    actor: .user,
    target: PolicyTarget(appID: "com.apple.Safari"),
    sessionID: sessionID,
    correlationID: context.correlationID,
    causationID: context.causationID,
    turnContext: context)
  let decision = await engine.evaluate(request)
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("Expected confirmation challenge")
    return
  }

  let response = PolicyConfirmationResponse(
    requestID: challenge.requestID,
    nonce: challenge.nonce,
    responseHash: challenge.expectedHash,
    accepted: true)
  guard case .allow = await engine.submitConfirmation(response) else {
    Issue.record("Expected confirmed policy request to allow")
    return
  }

  #expect(await engine.beginAuthorizedExecution(context: context))
  #expect(
    await engine.completeAuthorizedExecution(
      context: context,
      verified: true,
      summary: "Safari is no longer running"))
  #expect(await engine.beginAuthorizedExecution(context: context) == false)
}

@Test
func changedPlanCannotReuseConfirmationApproval() async throws {
  let (engine, _) = try await makeEngine()
  let grant = Grant(
    capability: .shellExec,
    patterns: [.any],
    confirmationRequirement: .always)
  try await engine.issueGrant(grant)
  let context = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let originalTarget = PolicyTarget(command: "/bin/echo", arguments: ["one"])
  let request = PolicyEvaluationRequest(
    capability: .shellExec,
    actor: .user,
    target: originalTarget,
    sessionID: context.sessionID,
    correlationID: context.correlationID,
    causationID: context.causationID,
    turnContext: context)
  let decision = await engine.evaluate(request)
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("Expected confirmation challenge")
    return
  }
  guard case .allow = await engine.submitConfirmation(
    PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: challenge.nonce,
      responseHash: challenge.expectedHash,
      accepted: true))
  else {
    Issue.record("Expected confirmation approval")
    return
  }

  let changedPlanHash = PolicyPlanHasher.hash(
    capability: .shellExec,
    actor: .user,
    target: PolicyTarget(command: "/bin/echo", arguments: ["two"]))
  #expect(await engine.beginAuthorizedExecution(context: context, planHash: changedPlanHash) == false)

  let originalPlanHash = PolicyPlanHasher.hash(
    capability: .shellExec,
    actor: .user,
    target: originalTarget)
  #expect(await engine.beginAuthorizedExecution(context: context, planHash: originalPlanHash))
  #expect(
    await engine.completeAuthorizedExecution(
      context: context, verified: true, summary: "echo completed"))
}

@Test
func perSessionConfirmationOnlyPromptsOnce() async throws {
  let (engine, _) = try await makeEngine()
  let grant = Grant(
    capability: .appActivate,
    patterns: [.any],
    confirmationRequirement: .oncePerSession
  )
  try await engine.issueGrant(grant)
  let sessionID = UUID()
  let req1 = request(capability: .appActivate, sessionID: sessionID)
  let decision1 = await engine.evaluate(req1)
  guard case .confirm(let challenge, _) = decision1 else {
    Issue.record("Expected confirm for first request")
    return
  }
  let response = PolicyConfirmationResponse(
    requestID: challenge.requestID,
    nonce: challenge.nonce,
    responseHash: challenge.expectedHash,
    accepted: true
  )
  let result = await engine.submitConfirmation(response)
  guard case .allow = result else {
    Issue.record("Expected allow after confirmation")
    return
  }
  let req2 = request(
    capability: .appActivate, arguments: [], environment: [:], sessionID: sessionID)
  let decision2 = await engine.evaluate(req2)
  guard case .allow = decision2 else {
    Issue.record(
      "Expected allow on second request after per-session confirmation; got \(decision2)")
    return
  }
}

@Test
func confirmationTamperIsDenied() async throws {
  let (engine, _) = try await makeEngine()
  let grant = Grant(
    capability: .fileWrite,
    patterns: [.any],
    confirmationRequirement: .always
  )
  try await engine.issueGrant(grant)
  let req = request(capability: .fileWrite)
  let decision = await engine.evaluate(req)
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("Expected confirm")
    return
  }
  let response = PolicyConfirmationResponse(
    requestID: challenge.requestID,
    nonce: challenge.nonce,
    responseHash: "deadbeef",
    accepted: true
  )
  let result = await engine.submitConfirmation(response)
  guard case .deny(let reason, _) = result else {
    Issue.record("Expected deny for tampered response")
    return
  }
  #expect(reason.contains("hash mismatch"))
}

@Test
func confirmationExpiryDenies() async throws {
  let store = try await makeStore()
  let (engine, _) = try await makeEngine(store: store)
  let grant = Grant(
    capability: .fileWrite,
    patterns: [.any],
    confirmationRequirement: .always
  )
  try await engine.issueGrant(grant)
  let req = request(capability: .fileWrite)
  let decision = await engine.evaluate(req)
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("Expected confirm")
    return
  }
  let expiredChallenge = PolicyConfirmationChallenge(
    requestID: challenge.requestID,
    sessionID: challenge.sessionID,
    nonce: challenge.nonce,
    issuedAt: challenge.issuedAt,
    requestedAction: challenge.requestedAction,
    targetSummary: challenge.targetSummary,
    riskTier: challenge.riskTier,
    expiresAt: Date(timeIntervalSinceNow: -1),
    expectedHash: challenge.expectedHash
  )
  let mutatedEngine = engine
  await mutatedEngine.injectPendingConfirmation(expiredChallenge)
  let response = PolicyConfirmationResponse(
    requestID: expiredChallenge.requestID,
    nonce: expiredChallenge.nonce,
    responseHash: expiredChallenge.expectedHash,
    accepted: true
  )
  let result = await mutatedEngine.submitConfirmation(response)
  guard case .deny(let reason, _) = result else {
    Issue.record("Expected deny for expired confirmation; got \(result)")
    return
  }
  #expect(reason.contains("expired"))
}

@Test
func destructiveTierRequiresConfirmationByDefault() async throws {
  let (engine, _) = try await makeEngine()
  let req = request(capability: .networkRequest)
  let decision = await engine.evaluate(req)
  // Default config denies destructive tiers. Grant or config override would be needed to confirm.
  guard case .deny = decision else {
    Issue.record("Expected deny for destructive default tier; got \(decision)")
    return
  }
}

@Test
func revokeGrantRemovesAuthorization() async throws {
  let (engine, _) = try await makeEngine()
  let grant = Grant(
    capability: .fileWrite,
    patterns: [.any],
    confirmationRequirement: .none
  )
  try await engine.issueGrant(grant)
  try await engine.revokeGrant(id: grant.id)
  let req = request(capability: .fileWrite)
  let decision = await engine.evaluate(req)
  guard case .deny = decision else {
    Issue.record("Expected deny after revoke")
    return
  }
}

@Test
func removeDenyRuleRestoresDefault() async throws {
  let store = try await makeStore()
  let (engine, _) = try await makeEngine(store: store)
  let rule = DenyRule(capability: .fileRead, patterns: [.any], reason: "denied")
  try await engine.upsertDenyRule(rule)
  try await engine.removeDenyRule(id: rule.id)
  let req = request(capability: .fileRead)
  let decision = await engine.evaluate(req)
  guard case .allow = decision else {
    Issue.record("Expected allow after deny rule removal")
    return
  }
}

@Test
func grantsPersistAcrossReloads() async throws {
  let store = try await makeStore()
  let (engine1, _) = try await makeEngine(store: store)
  let grant = Grant(
    capability: .fileWrite,
    patterns: [.any],
    confirmationRequirement: .none
  )
  try await engine1.issueGrant(grant)

  let engine2 = try await PolicyEngine(
    configuration: PolicyConfiguration(
      defaultConfirmationTier: .mutation,
      confirmationExpirySeconds: 60,
      allowByDefaultTiers: [.observation],
      denyByDefaultTiers: [.reversible, .mutation, .destructive]
    ),
    eventBus: AuraEventBus(logger: AuraLogger(subsystem: "AuraPolicyTests", category: "bus")),
    store: store
  )
  let req = request(capability: .fileWrite)
  let decision = await engine2.evaluate(req)
  guard case .allow(_, let grantID) = decision else {
    Issue.record("Expected allow after reload")
    return
  }
  #expect(grantID == grant.id)
}

@Test
func setConfigurationValidates() async throws {
  let (engine, _) = try await makeEngine()
  var badConfig = PolicyConfiguration()
  badConfig.confirmationExpirySeconds = 0
  await #expect(throws: AuraError.self) {
    try await engine.setConfiguration(badConfig)
  }
}
