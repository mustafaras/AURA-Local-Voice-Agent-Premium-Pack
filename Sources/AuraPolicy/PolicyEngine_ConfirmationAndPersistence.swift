import AuraCore
import AuraStore
import CryptoKit
import Foundation

struct PolicyChallengeHashInput {
  let requestID: UUID
  let nonce: String
  let capability: Capability
  let targetSummary: String
  let planHash: String
  let expiresAt: Date
}

extension PolicyEngine {
  // MARK: - Confirmation logic

  func confirmationRequired(for request: PolicyEvaluationRequest, grant: Grant) -> Bool {
    switch grant.confirmationRequirement {
    case .none:
      return false
    case .oncePerSession:
      let key = sessionCapabilityKey(for: request.capability, sessionID: request.sessionID)
      return !confirmedSessionCapabilities.contains(key)
    case .always:
      return true
    case .forRiskTier(let tier):
      return request.capability.riskTier.rawValue >= tier.rawValue
    case .when(let pattern):
      return patternsSatisfied(request: request, patterns: [pattern])
    }
  }

  func defaultConfirmationRequired(for request: PolicyEvaluationRequest) -> Bool {
    return request.capability.riskTier.rawValue >= configuration.defaultConfirmationTier.rawValue
  }

  func sessionCapabilityKey(for capability: Capability, sessionID: UUID) -> String {
    "\(sessionID.uuidString).\(capability.identifier)"
  }

  // MARK: - Challenge generation

  func makeChallenge(
    for request: PolicyEvaluationRequest,
    grant: Grant?,
    auditID: UUID
  ) -> PolicyConfirmationChallenge {
    let nonce = randomNonce()
    let issuedAt = Date()
    let expiresAt = issuedAt.addingTimeInterval(configuration.confirmationExpirySeconds)
    let targetSummary = summarize(request.target)
    let planHash = PolicyPlanHasher.hash(request)
    let expectedHash = challengeHash(
      PolicyChallengeHashInput(
        requestID: request.id,
        nonce: nonce,
        capability: request.capability,
        targetSummary: targetSummary,
        planHash: planHash,
        expiresAt: expiresAt
      )
    )
    return PolicyConfirmationChallenge(
      requestID: request.id,
      sessionID: request.sessionID,
      nonce: nonce,
      issuedAt: issuedAt,
      requestedAction: request.capability,
      targetSummary: targetSummary,
      riskTier: request.capability.riskTier,
      expiresAt: expiresAt,
      expectedHash: expectedHash,
      planHash: planHash,
      turnContext: request.turnContext
    )
  }

  func randomNonce() -> String {
    let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
    return bytes.map { String(format: "%02x", $0) }.joined()
  }

  func challengeHash(_ input: PolicyChallengeHashInput) -> String {
    let canonical = [
      input.requestID.uuidString,
      input.nonce,
      input.capability.identifier,
      input.targetSummary,
      input.planHash,
      ISO8601DateFormatter().string(from: input.expiresAt),
    ].joined(separator: "|")
    let digest = SHA256.hash(data: Data(canonical.utf8))
    return digest.compactMap { String(format: "%02x", $0) }.joined()
  }

  // MARK: - Target summarization

  func summarize(_ target: PolicyTarget) -> String {
    var parts: [String] = []
    if let appID = target.appID { parts.append("app:\(appID)") }
    if let filePath = target.filePath { parts.append("file:\(filePath)") }
    if let directoryPath = target.directoryPath { parts.append("dir:\(directoryPath)") }
    if let command = target.command { parts.append("cmd:\(command)") }
    if !target.arguments.isEmpty { parts.append("args:\(target.arguments.count)") }
    if !target.environmentKeys.isEmpty { parts.append("env:\(target.environmentKeys.count)") }
    if let host = target.networkHost { parts.append("host:\(host)") }
    if let port = target.networkPort { parts.append("port:\(port)") }
    return parts.isEmpty ? "any" : parts.joined(separator: ";")
  }

  // MARK: - Persistence

  func persistGrants() async throws(AuraError) {
    guard let store else { return }
    do {
      let data = try jsonEncoder.encode(grants)
      guard let json = String(data: data, encoding: .utf8) else {
        throw AuraError.serializationError("Failed to encode grants as UTF-8")
      }
      try await store.setValue(json, forKey: configuration.grantStoreKey)
    } catch let error as AuraError {
      throw error
    } catch {
      throw AuraError.storeError("Failed to persist grants: \(error.localizedDescription)")
    }
  }

  func persistDenyRules() async throws(AuraError) {
    guard let store else { return }
    do {
      let data = try jsonEncoder.encode(denyRules)
      guard let json = String(data: data, encoding: .utf8) else {
        throw AuraError.serializationError("Failed to encode deny rules as UTF-8")
      }
      try await store.setValue(json, forKey: configuration.denyRuleStoreKey)
    } catch let error as AuraError {
      throw error
    } catch {
      throw AuraError.storeError("Failed to persist deny rules: \(error.localizedDescription)")
    }
  }

  func loadFromStore() async throws(AuraError) {
    guard let store else { return }
    if let grantsJSON = try await store.value(forKey: configuration.grantStoreKey),
      let data = grantsJSON.data(using: .utf8)
    {
      do {
        self.grants = try jsonDecoder.decode([Grant].self, from: data)
      } catch {
        throw AuraError.storeError(
          "Failed to decode persisted grants: \(error.localizedDescription)")
      }
    }
    if let denyRulesJSON = try await store.value(forKey: configuration.denyRuleStoreKey),
      let data = denyRulesJSON.data(using: .utf8)
    {
      do {
        self.denyRules = try jsonDecoder.decode([DenyRule].self, from: data)
      } catch {
        throw AuraError.storeError(
          "Failed to decode persisted deny rules: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Event emission

  func emitEvaluationRequested(_ request: PolicyEvaluationRequest, auditID: UUID) async {
    let payload = PolicyEvaluationRequestedEvent(
      requestID: request.id,
      capabilityIdentifier: request.capability.identifier,
      targetSummary: summarize(request.target),
      riskTier: request.capability.riskTier,
      actor: request.actor
    )
    let envelope = EventEnvelope(
      correlationID: request.correlationID,
      causationID: request.causationID,
      actor: request.actor,
      sensitivity: sensitivityFor(request.capability.riskTier),
      payload: payload
    )
    await eventBus.emit(envelope)
  }

  func emitDecision(
    _ request: PolicyEvaluationRequest,
    decision: PolicyDecision,
    targetSummary: String,
    auditID: UUID
  ) async {
    let decisionString: String
    let reason: String
    switch decision {
    case .allow:
      decisionString = "allow"
      reason = ""
    case .deny(let denyReason, _):
      decisionString = "deny"
      reason = denyReason
    case .confirm:
      decisionString = "confirm"
      reason = "Confirmation required"
    }
    let payload = PolicyDecisionEvent(
      auditID: auditID,
      requestID: request.id,
      decision: decisionString,
      reason: reason,
      capabilityIdentifier: request.capability.identifier,
      targetSummary: targetSummary
    )
    let envelope = EventEnvelope(
      correlationID: request.correlationID,
      causationID: request.causationID,
      actor: .policy,
      sensitivity: sensitivityFor(request.capability.riskTier),
      payload: payload
    )
    await eventBus.emit(envelope)
  }

  func emitConfirmationRequested(_ challenge: PolicyConfirmationChallenge, auditID: UUID)
    async
  {
    let payload = PolicyConfirmationRequestedEvent(challenge: challenge, auditID: auditID)
    let envelope = EventEnvelope(
      correlationID: challenge.requestID,
      causationID: challenge.requestID,
      actor: .policy,
      sensitivity: sensitivityFor(challenge.riskTier),
      payload: payload
    )
    await eventBus.emit(envelope)
  }

  func emitConfirmationResponse(
    _ response: PolicyConfirmationResponse, verified: Bool, auditID: UUID
  ) async {
    let payload = PolicyConfirmationRespondedEvent(
      requestID: response.requestID,
      accepted: response.accepted,
      verified: verified,
      auditID: auditID
    )
    let envelope = EventEnvelope(
      correlationID: response.requestID,
      causationID: response.requestID,
      actor: .policy,
      sensitivity: .sensitive,
      payload: payload
    )
    await eventBus.emit(envelope)
  }

  func emitRuleMutation(
    _ mutation: String,
    ruleID: UUID,
    capability: Capability?,
    actor: ActorID
  ) async {
    let payload = PolicyRuleMutationEvent(
      mutation: mutation,
      ruleID: ruleID,
      capabilityIdentifier: capability?.identifier,
      actor: actor
    )
    let envelope = EventEnvelope(
      correlationID: ruleID,
      causationID: ruleID,
      actor: actor,
      sensitivity: .sensitive,
      payload: payload
    )
    await eventBus.emit(envelope)
  }

  func sensitivityFor(_ riskTier: PermissionRiskTier) -> SensitivityLevel {
    switch riskTier {
    case .observation: return .internalLevel
    case .reversible: return .sensitive
    case .mutation: return .sensitive
    case .destructive: return .secret
    case .network: return .sensitive
    }
  }
}

// MARK: - Pattern helpers

extension String {
  func matchesGlob(_ pattern: String) -> Bool {
    let predicate = NSPredicate(format: "SELF LIKE[c] %@", pattern)
    return predicate.evaluate(with: self)
  }

  func matchesRegex(_ pattern: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(location: 0, length: self.utf16.count)
    return regex.firstMatch(in: self, options: [], range: range) != nil
  }
}
