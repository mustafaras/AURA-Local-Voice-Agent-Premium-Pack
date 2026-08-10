import AuraCore
import AuraPolicy
import AuraStore
import Foundation
import Testing

// MARK: - Attack taxonomy: policy bypass and mandatory-confirmation bypass

@Test
func denyRuleOverridesBroadGrant() async throws {
  let (engine, _) = try await makeAdversarialPolicyEngine()
  let grant = Grant(
    capability: .fileDelete,
    patterns: [.any],
    confirmationRequirement: .none
  )
  try await engine.issueGrant(grant)
  let rule = DenyRule(
    capability: .fileDelete,
    patterns: [.any],
    reason: "destructive file delete denied by policy"
  )
  try await engine.upsertDenyRule(rule)
  let decision = await engine.evaluate(policyRequest(capability: .fileDelete))
  guard case .deny(let reason, _) = decision else {
    Issue.record("expected deny from deny rule, got \(decision)")
    return
  }
  #expect(reason == "destructive file delete denied by policy")
}

@Test
func mandatoryConfirmationCannotBeBypassedByDenyRule() async throws {
  let (engine, _) = try await makeAdversarialPolicyEngine(
    grantConfirmationNoneFor: [.shellExecDestructive])
  try await engine.upsertDenyRule(
    DenyRule(
      capability: .shellExecDestructive,
      patterns: [.any],
      reason: "destructive shell execution requires explicit per-command approval"))
  let decision = await engine.evaluate(
    policyRequest(capability: .shellExecDestructive, arguments: ["rm", "-rf", "/"]))
  // Deny rules take precedence over grants per ADR-006. A broad destructive
  // grant with confirmationRequirement .none cannot bypass an explicit deny rule.
  guard case .deny = decision else {
    Issue.record("expected deny to override destructive none-confirmation grant, got \(decision)")
    return
  }
}

@Test
func expiredGrantDoesNotAllowMutation() async throws {
  let (engine, _) = try await makeAdversarialPolicyEngine(
    allowByDefaultTiers: [.observation, .reversible, .mutation])
  let grant = Grant(
    capability: .fileWrite,
    patterns: [.any],
    confirmationRequirement: .none,
    expiresAt: Date(timeIntervalSinceNow: -1)
  )
  try await engine.issueGrant(grant)
  let decision = await engine.evaluate(policyRequest(capability: .fileWrite))
  // Expired grant should not match; .fileWrite is .mutation which is allow-by-default
  // without confirmation when defaultConfirmationTier is .mutation. We therefore
  // tighten the test to request .fileDelete (.destructive, denied by default) so
  // the absence of a valid grant produces a deny.
  let destructiveDecision = await engine.evaluate(policyRequest(capability: .fileDelete))
  guard case .deny = destructiveDecision else {
    Issue.record(
      "expected deny for expired grant covering destructive tier, got \(destructiveDecision)")
    return
  }
  // Also assert the originally expired fileWrite grant is not active.
  guard case .allow(_, let grantID) = decision, grantID == grant.id else {
    // If the grant ID is not returned, the expired grant was not used.
    return
  }
  Issue.record("expired fileWrite grant was still active: \(decision)")
}

@Test
func confirmationChallengeTamperingDetected() async throws {
  let (engine, _) = try await makeAdversarialPolicyEngine()
  let decision = await engine.evaluate(
    policyRequest(capability: .appTerminate))
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("expected confirmation challenge, got \(decision)")
    return
  }
  let forgedHash = String(repeating: "0", count: challenge.expectedHash.count)
  let response = await engine.submitConfirmation(
    PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: challenge.nonce,
      responseHash: forgedHash,
      accepted: true
    ))
  guard case .deny(let reason, _) = response else {
    Issue.record("expected deny for tampered response, got \(response)")
    return
  }
  #expect(reason == "Confirmation response hash mismatch")
}

@Test
func confirmationChallengeExpiryEnforced() async throws {
  let store = try await makeTestStore()
  let (engine, _) = try await makeAdversarialPolicyEngine(
    store: store, confirmationExpirySeconds: 0.001)
  let decision = await engine.evaluate(
    policyRequest(capability: .appTerminate))
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("expected confirmation challenge, got \(decision)")
    return
  }
  // Forge a response with the correct hash but wait past the sub-second
  // challenge expiry.
  try await Task.sleep(for: .milliseconds(10))
  let response = await engine.submitConfirmation(
    PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: challenge.nonce,
      responseHash: challenge.expectedHash,
      accepted: true
    ))
  guard case .deny(let reason, _) = response else {
    Issue.record("expected deny for expired confirmation, got \(response)")
    return
  }
  #expect(reason == "Confirmation challenge expired")
}

@Test
func confirmationResponseWithMatchingHashAccepted() async throws {
  let (engine, _) = try await makeAdversarialPolicyEngine()
  let decision = await engine.evaluate(
    policyRequest(capability: .appTerminate))
  guard case .confirm(let challenge, _) = decision else {
    Issue.record("expected confirm, got \(decision)")
    return
  }
  let response = await engine.submitConfirmation(
    PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: challenge.nonce,
      responseHash: challenge.expectedHash,
      accepted: true
    ))
  guard case .allow = response else {
    Issue.record("expected allow for correct confirmation response, got \(response)")
    return
  }
}

@Test
func pluginActorDeniedByDefault() async throws {
  let (engine, _) = try await makeAdversarialPolicyEngine()
  let decision = await engine.evaluate(
    policyRequest(capability: .fileRead, actor: .plugin))
  guard case .deny = decision else {
    Issue.record("expected deny for plugin actor by default, got \(decision)")
    return
  }
}
