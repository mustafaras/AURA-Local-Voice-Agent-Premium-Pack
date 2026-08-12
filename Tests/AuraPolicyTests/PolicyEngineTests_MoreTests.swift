import AuraCore
import AuraStore
import Foundation
import Testing

@testable import AuraPolicy

@Test
func changedPlanCannotReuseConfirmationApproval() async throws {
  guard let scenario = try await makeAuthorizedShellScenario() else { return }

  let changedPlanHash = PolicyPlanHasher.hash(
    capability: .shellExec,
    actor: .user,
    target: PolicyTarget(command: "/bin/echo", arguments: ["two"]))
  #expect(
    await scenario.engine.beginAuthorizedExecution(
      context: scenario.context, planHash: changedPlanHash) == false)

  let originalPlanHash = PolicyPlanHasher.hash(
    capability: .shellExec,
    actor: .user,
    target: scenario.originalTarget)
  #expect(
    await scenario.engine.beginAuthorizedExecution(
      context: scenario.context, planHash: originalPlanHash))
  #expect(
    await scenario.engine.completeAuthorizedExecution(
      context: scenario.context, verified: true, summary: "echo completed"))
}

private struct AuthorizedShellScenario {
  let engine: PolicyEngine
  let context: TurnContext
  let originalTarget: PolicyTarget
}

private func makeAuthorizedShellScenario() async throws -> AuthorizedShellScenario? {
  let (engine, _) = try await makeEngine()
  try await engine.issueGrant(
    Grant(capability: .shellExec, patterns: [.any], confirmationRequirement: .always))
  let context = TurnContext(
    sessionID: UUID(), activationSource: .text, actor: .user,
    authority: .userUtterance, sensitivity: .sensitive)
  let originalTarget = PolicyTarget(command: "/bin/echo", arguments: ["one"])
  let request = PolicyEvaluationRequest(
    capability: .shellExec, actor: .user, target: originalTarget,
    sessionID: context.sessionID, correlationID: context.correlationID,
    causationID: context.causationID, turnContext: context)
  let decision = await engine.evaluate(request)
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("Expected confirmation challenge")
    return nil
  }
  let response = PolicyConfirmationResponse(
    requestID: challenge.requestID, nonce: challenge.nonce,
    responseHash: challenge.expectedHash, accepted: true)
  guard case .allow = await engine.submitConfirmation(response) else {
    Issue.record("Expected confirmation approval")
    return nil
  }
  return AuthorizedShellScenario(
    engine: engine, context: context, originalTarget: originalTarget)
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
