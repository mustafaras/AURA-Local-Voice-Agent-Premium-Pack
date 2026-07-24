import AuraCore
import AuraStore
import CryptoKit
import Foundation

/// Actor-isolated policy engine that authorizes every action before execution.
///
/// The engine evaluates requests against deny rules first, then scoped grants,
/// and finally falls back to the configured default tier matrix. It issues
/// tamper-evident confirmation challenges, records audit events on the typed
/// event bus, and persists grants and deny rules through `AuraStore`.
public actor PolicyEngine {
  private var configuration: PolicyConfiguration
  private var grants: [Grant]
  private var denyRules: [DenyRule]
  private var pendingConfirmations: [UUID: PolicyConfirmationChallenge]
  private var confirmedSessionCapabilities: Set<String>
  private let eventBus: AuraEventBus
  private let store: AuraStore?
  private let jsonEncoder: JSONEncoder
  private let jsonDecoder: JSONDecoder

  /// Initialize a new policy engine.
  ///
  /// - Parameters:
  ///   - configuration: Validated policy configuration.
  ///   - eventBus: Event bus used for audit events.
  ///   - store: Optional persistent store for grants and deny rules.
  public init(
    configuration: PolicyConfiguration,
    eventBus: AuraEventBus,
    store: AuraStore? = nil
  ) async throws(AuraError) {
    self.configuration = configuration
    self.grants = []
    self.denyRules = []
    self.pendingConfirmations = [:]
    self.confirmedSessionCapabilities = []
    self.eventBus = eventBus
    self.store = store
    self.jsonEncoder = JSONEncoder()
    self.jsonEncoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder.outputFormatting = .sortedKeys
    self.jsonDecoder = JSONDecoder()
    self.jsonDecoder.dateDecodingStrategy = .iso8601
    try await loadFromStore()
  }

  // MARK: - Public evaluation API

  /// Evaluate a request and return a policy decision.
  ///
  /// The result may be `.allow`, `.deny`, or `.confirm`. For `.confirm`, the
  /// caller must later submit a matching `PolicyConfirmationResponse` via
  /// `submitConfirmation(_:)`.
  public func evaluate(_ request: PolicyEvaluationRequest) async -> PolicyDecision {
    let auditID = UUID()
    await emitEvaluationRequested(request, auditID: auditID)

    let targetSummary = summarize(request.target)

    // 1. Deny rules take precedence.
    if let denyRule = matchingDenyRule(for: request) {
      let decision: PolicyDecision = .deny(
        reason: denyRule.reason,
        auditID: auditID
      )
      await emitDecision(
        request, decision: decision, targetSummary: targetSummary, auditID: auditID)
      return decision
    }

    // 2. Find a matching grant.
    if let grant = matchingGrant(for: request) {
      let requiresConfirmation = confirmationRequired(for: request, grant: grant)
      if requiresConfirmation {
        let challenge = makeChallenge(for: request, grant: grant, auditID: auditID)
        pendingConfirmations[request.id] = challenge
        let decision: PolicyDecision = .confirm(challenge: challenge, auditID: auditID)
        await emitConfirmationRequested(challenge, auditID: auditID)
        await emitDecision(
          request, decision: decision, targetSummary: targetSummary, auditID: auditID)
        return decision
      }
      let decision: PolicyDecision = .allow(auditID: auditID, grantID: grant.id)
      await emitDecision(
        request, decision: decision, targetSummary: targetSummary, auditID: auditID)
      return decision
    }

    // 3. Fall back to default tier matrix.
    if configuration.denyByDefaultTiers.contains(request.capability.riskTier) {
      let decision: PolicyDecision = .deny(
        reason: "No matching grant and tier \(request.capability.riskTier) is denied by default",
        auditID: auditID
      )
      await emitDecision(
        request, decision: decision, targetSummary: targetSummary, auditID: auditID)
      return decision
    }

    let requiresConfirmation = defaultConfirmationRequired(for: request)
    if requiresConfirmation {
      let challenge = makeChallenge(for: request, grant: nil, auditID: auditID)
      pendingConfirmations[request.id] = challenge
      let decision: PolicyDecision = .confirm(challenge: challenge, auditID: auditID)
      await emitConfirmationRequested(challenge, auditID: auditID)
      await emitDecision(
        request, decision: decision, targetSummary: targetSummary, auditID: auditID)
      return decision
    }

    let decision: PolicyDecision = .allow(auditID: auditID, grantID: nil)
    await emitDecision(request, decision: decision, targetSummary: targetSummary, auditID: auditID)
    return decision
  }

  /// Submit a confirmation response and, if accepted and verified, return an
  /// allow decision for the original request.
  public func submitConfirmation(_ response: PolicyConfirmationResponse) async -> PolicyDecision {
    let auditID = UUID()
    guard let challenge = pendingConfirmations[response.requestID] else {
      let decision: PolicyDecision = .deny(
        reason: "No pending confirmation for request \(response.requestID)",
        auditID: auditID
      )
      await emitConfirmationResponse(response, verified: false, auditID: auditID)
      return decision
    }

    let now = Date()
    guard now < challenge.expiresAt else {
      pendingConfirmations.removeValue(forKey: response.requestID)
      let decision: PolicyDecision = .deny(
        reason: "Confirmation challenge expired",
        auditID: auditID
      )
      await emitConfirmationResponse(response, verified: false, auditID: auditID)
      return decision
    }

    let verified =
      response.nonce == challenge.nonce
      && response.responseHash == challenge.expectedHash
      && response.requestID == challenge.requestID

    await emitConfirmationResponse(response, verified: verified, auditID: auditID)

    guard verified && response.accepted else {
      pendingConfirmations.removeValue(forKey: response.requestID)
      let decision: PolicyDecision = .deny(
        reason: response.accepted
          ? "Confirmation response hash mismatch" : "User declined confirmation",
        auditID: auditID
      )
      return decision
    }

    // Mark once-per-session confirmations as satisfied using the request's session ID.
    let sessionCapabilityKey = sessionCapabilityKey(
      for: challenge.requestedAction, sessionID: challenge.sessionID)
    confirmedSessionCapabilities.insert(sessionCapabilityKey)

    pendingConfirmations.removeValue(forKey: response.requestID)
    let decision: PolicyDecision = .allow(auditID: auditID, grantID: nil)
    return decision
  }

  // MARK: - Grant and deny-rule management

  /// Issue or replace a grant. Replacing preserves the original ID when one
  /// is provided with the same capability and patterns.
  public func issueGrant(_ grant: Grant) async throws(AuraError) {
    grants.removeAll { $0.id == grant.id }
    grants.append(grant)
    try await persistGrants()
    await emitRuleMutation(
      "issueGrant", ruleID: grant.id, capability: grant.capability, actor: grant.issuer)
  }

  /// Revoke a grant by ID.
  public func revokeGrant(id: UUID) async throws(AuraError) {
    guard let index = grants.firstIndex(where: { $0.id == id }) else {
      throw AuraError.invalidConfiguration("No grant with id \(id)")
    }
    let grant = grants.remove(at: index)
    try await persistGrants()
    await emitRuleMutation(
      "revokeGrant", ruleID: id, capability: grant.capability, actor: grant.issuer)
  }

  /// Add or replace a deny rule.
  public func upsertDenyRule(_ rule: DenyRule) async throws(AuraError) {
    denyRules.removeAll { $0.id == rule.id }
    denyRules.append(rule)
    try await persistDenyRules()
    await emitRuleMutation(
      "upsertDenyRule", ruleID: rule.id, capability: rule.capability, actor: rule.actor ?? .system)
  }

  /// Remove a deny rule by ID.
  public func removeDenyRule(id: UUID) async throws(AuraError) {
    guard let index = denyRules.firstIndex(where: { $0.id == id }) else {
      throw AuraError.invalidConfiguration("No deny rule with id \(id)")
    }
    let rule = denyRules.remove(at: index)
    try await persistDenyRules()
    await emitRuleMutation(
      "removeDenyRule", ruleID: id, capability: rule.capability, actor: rule.actor ?? .system)
  }

  /// Replace the in-memory configuration and validate it.
  public func setConfiguration(_ configuration: PolicyConfiguration) async throws(AuraError) {
    try configuration.validate()
    self.configuration = configuration
  }

  #if DEBUG
    /// Test-only injection of a pending confirmation challenge to exercise
    /// expiry paths deterministically.
    public func injectPendingConfirmation(_ challenge: PolicyConfirmationChallenge) {
      pendingConfirmations[challenge.requestID] = challenge
    }
  #endif

  // MARK: - Internal matching

  private func matchingDenyRule(for request: PolicyEvaluationRequest) -> DenyRule? {
    denyRules.first { rule in
      guard rule.actor == nil || rule.actor == request.actor else { return false }
      guard rule.capability == nil || rule.capability == request.capability else { return false }
      return patternsSatisfied(request: request, patterns: rule.patterns)
    }
  }

  private func matchingGrant(for request: PolicyEvaluationRequest) -> Grant? {
    let now = Date()
    return grants.first { grant in
      guard grant.capability == request.capability else { return false }
      if let expiresAt = grant.expiresAt, now >= expiresAt { return false }
      return patternsSatisfied(request: request, patterns: grant.patterns)
    }
  }

  private func patternsSatisfied(request: PolicyEvaluationRequest, patterns: [ResourcePattern])
    -> Bool
  {
    for pattern in patterns {
      switch pattern {
      case .any:
        continue
      case .appID(let appID):
        guard request.target.appID == appID else { return false }
      case .filePath(let glob):
        guard let filePath = request.target.filePath else { return false }
        guard filePath.matchesGlob(glob) else { return false }
      case .directory(let directory, let recursive):
        guard let targetPath = request.target.filePath ?? request.target.directoryPath else {
          return false
        }
        let prefix = (directory as NSString).appendingPathComponent("")
        guard targetPath.hasPrefix(prefix) || targetPath == directory else { return false }
        if !recursive {
          let remainder = String(targetPath.dropFirst(prefix.count))
          guard !remainder.contains("/") else { return false }
        }
      case .command(let regex):
        guard let command = request.target.command else { return false }
        guard command.matchesRegex(regex) else { return false }
      case .argument(let allowed):
        guard Set(request.target.arguments).isSubset(of: allowed) else { return false }
      case .environment(let keys):
        guard Set(request.environment.keys).isSubset(of: keys) else { return false }
      case .network(let host, port: let portRange):
        guard let requestHost = request.target.networkHost else { return false }
        guard requestHost.matchesGlob(host) else { return false }
        if let requestPort = request.target.networkPort {
          guard portRange.contains(requestPort) else { return false }
        }
      }
    }
    return true
  }

  // MARK: - Confirmation logic

  private func confirmationRequired(for request: PolicyEvaluationRequest, grant: Grant) -> Bool {
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

  private func defaultConfirmationRequired(for request: PolicyEvaluationRequest) -> Bool {
    return request.capability.riskTier.rawValue >= configuration.defaultConfirmationTier.rawValue
  }

  private func sessionCapabilityKey(for capability: Capability, sessionID: UUID) -> String {
    "\(sessionID.uuidString).\(capability.identifier)"
  }

  // MARK: - Challenge generation

  private func makeChallenge(
    for request: PolicyEvaluationRequest,
    grant: Grant?,
    auditID: UUID
  ) -> PolicyConfirmationChallenge {
    let nonce = randomNonce()
    let issuedAt = Date()
    let expiresAt = issuedAt.addingTimeInterval(configuration.confirmationExpirySeconds)
    let targetSummary = summarize(request.target)
    let expectedHash = challengeHash(
      requestID: request.id,
      nonce: nonce,
      capability: request.capability,
      targetSummary: targetSummary,
      expiresAt: expiresAt
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
      expectedHash: expectedHash
    )
  }

  private func randomNonce() -> String {
    let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
    return bytes.map { String(format: "%02x", $0) }.joined()
  }

  private func challengeHash(
    requestID: UUID,
    nonce: String,
    capability: Capability,
    targetSummary: String,
    expiresAt: Date
  ) -> String {
    let canonical = [
      requestID.uuidString,
      nonce,
      capability.identifier,
      targetSummary,
      ISO8601DateFormatter().string(from: expiresAt),
    ].joined(separator: "|")
    let digest = SHA256.hash(data: Data(canonical.utf8))
    return digest.compactMap { String(format: "%02x", $0) }.joined()
  }

  // MARK: - Target summarization

  private func summarize(_ target: PolicyTarget) -> String {
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

  private func persistGrants() async throws(AuraError) {
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

  private func persistDenyRules() async throws(AuraError) {
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

  private func loadFromStore() async throws(AuraError) {
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

  private func emitEvaluationRequested(_ request: PolicyEvaluationRequest, auditID: UUID) async {
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

  private func emitDecision(
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

  private func emitConfirmationRequested(_ challenge: PolicyConfirmationChallenge, auditID: UUID)
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

  private func emitConfirmationResponse(
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

  private func emitRuleMutation(
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

  private func sensitivityFor(_ riskTier: PermissionRiskTier) -> SensitivityLevel {
    switch riskTier {
    case .observation: return .internalLevel
    case .reversible: return .sensitive
    case .mutation: return .sensitive
    case .destructive: return .secret
    }
  }
}

// MARK: - Pattern helpers

extension String {
  fileprivate func matchesGlob(_ pattern: String) -> Bool {
    let predicate = NSPredicate(format: "SELF LIKE[c] %@", pattern)
    return predicate.evaluate(with: self)
  }

  fileprivate func matchesRegex(_ pattern: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(location: 0, length: self.utf16.count)
    return regex.firstMatch(in: self, options: [], range: range) != nil
  }
}
