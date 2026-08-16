import AuraCore
import AuraStore
import CryptoKit
import Foundation

extension PolicyEngine {
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
    if let denyRule = matchingDenyRule(for: request) {
      return await recordDecision(
        request,
        decision: .deny(reason: denyRule.reason, auditID: auditID),
        targetSummary: targetSummary,
        auditID: auditID)
    }
    if let grant = matchingGrant(for: request) {
      if confirmationRequired(for: request, grant: grant) {
        return await confirmationDecision(
          request: request, grant: grant, targetSummary: targetSummary, auditID: auditID)
      }
      return await recordDecision(
        request,
        decision: .allow(auditID: auditID, grantID: grant.id),
        targetSummary: targetSummary,
        auditID: auditID)
    }
    if request.actor == .plugin {
      return await recordDecision(
        request,
        decision: .deny(reason: "Plugin actor has no matching active grant", auditID: auditID),
        targetSummary: targetSummary,
        auditID: auditID)
    }
    if configuration.denyByDefaultTiers.contains(request.capability.riskTier) {
      return await recordDecision(
        request,
        decision: .deny(
          reason: "No matching grant and tier \(request.capability.riskTier) is denied by default",
          auditID: auditID),
        targetSummary: targetSummary,
        auditID: auditID)
    }
    if defaultConfirmationRequired(for: request) {
      return await confirmationDecision(
        request: request, grant: nil, targetSummary: targetSummary, auditID: auditID)
    }
    return await recordDecision(
      request,
      decision: .allow(auditID: auditID, grantID: nil),
      targetSummary: targetSummary,
      auditID: auditID)
  }

  private func confirmationDecision(
    request: PolicyEvaluationRequest,
    grant: Grant?,
    targetSummary: String,
    auditID: UUID
  ) async -> PolicyDecision {
    let challenge = makeChallenge(for: request, grant: grant, auditID: auditID)
    pendingConfirmations[request.id] = challenge
    await confirmationTransactions.propose(challenge: challenge, sideEffects: [targetSummary])
    let decision = PolicyDecision.confirm(challenge: challenge, auditID: auditID)
    await emitConfirmationRequested(challenge, auditID: auditID)
    return await recordDecision(
      request, decision: decision, targetSummary: targetSummary, auditID: auditID)
  }

  private func recordDecision(
    _ request: PolicyEvaluationRequest,
    decision: PolicyDecision,
    targetSummary: String,
    auditID: UUID
  ) async -> PolicyDecision {
    await emitDecision(request, decision: decision, targetSummary: targetSummary, auditID: auditID)
    return decision
  }

  /// Submit a confirmation response and, if accepted and verified, return an
  /// allow decision for the original request.
  public func submitConfirmation(_ response: PolicyConfirmationResponse) async -> PolicyDecision {
    let auditID = UUID()
    guard let challenge = pendingConfirmations[response.requestID] else {
      return await missingConfirmationDecision(response, auditID: auditID)
    }

    let now = Date()
    guard now < challenge.expiresAt else {
      return await expiredConfirmationDecision(response, auditID: auditID)
    }

    let verified =
      response.nonce == challenge.nonce
      && response.responseHash == challenge.expectedHash
      && response.requestID == challenge.requestID

    await emitConfirmationResponse(response, verified: verified, auditID: auditID)

    guard verified && response.accepted else {
      return await rejectedConfirmationDecision(
        response,
        auditID: auditID,
        reason: response.accepted ? "response hash mismatch" : "user declined",
        message: response.accepted
          ? "Confirmation response hash mismatch" : "User declined confirmation")
    }

    do {
      _ = try await confirmationTransactions.authorize(response)
    } catch {
      pendingConfirmations.removeValue(forKey: response.requestID)
      let decision: PolicyDecision = .deny(
        reason: "Confirmation transaction rejected: \(error)",
        auditID: auditID)
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

  private func missingConfirmationDecision(
    _ response: PolicyConfirmationResponse,
    auditID: UUID
  ) async -> PolicyDecision {
    let decision: PolicyDecision = .deny(
      reason: "No pending confirmation for request \(response.requestID)",
      auditID: auditID)
    await emitConfirmationResponse(response, verified: false, auditID: auditID)
    return decision
  }

  private func expiredConfirmationDecision(
    _ response: PolicyConfirmationResponse,
    auditID: UUID
  ) async -> PolicyDecision {
    pendingConfirmations.removeValue(forKey: response.requestID)
    _ = try? await confirmationTransactions.cancel(
      requestID: response.requestID, reason: "expired")
    let decision: PolicyDecision = .deny(reason: "Confirmation challenge expired", auditID: auditID)
    await emitConfirmationResponse(response, verified: false, auditID: auditID)
    return decision
  }

  private func rejectedConfirmationDecision(
    _ response: PolicyConfirmationResponse,
    auditID: UUID,
    reason: String,
    message: String
  ) async -> PolicyDecision {
    pendingConfirmations.removeValue(forKey: response.requestID)
    _ = try? await confirmationTransactions.cancel(requestID: response.requestID, reason: reason)
    return .deny(reason: message, auditID: auditID)
  }

  public func beginAuthorizedExecution(
    context: TurnContext,
    planHash: String? = nil
  ) async -> Bool {
    (try? await confirmationTransactions.beginLatestExecution(
      context: context, planHash: planHash)) != nil
  }

  public func completeAuthorizedExecution(
    context: TurnContext,
    verified: Bool,
    summary: String
  ) async -> Bool {
    (try? await confirmationTransactions.completeLatestExecution(
      context: context, verified: verified, summary: summary)) != nil
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

  /// Replace the seeded default grant set, instead of appending to it.
  ///
  /// `issueGrant` de-duplicates by `id` and `Grant` mints a fresh `UUID` per
  /// construction, so seeding in a loop added a complete new copy of the
  /// default set on every launch. A live SP-006 follow-up run found **895**
  /// persisted grants on a developer machine, 30 of them pre-scoping `.any`
  /// grants for the filesystem/URL capabilities. Since `matchingGrant` returns
  /// the *first* grant that matches, those legacy grants kept authorizing the
  /// very paths the newly scoped grants were written to refuse — target
  /// scoping was therefore effective only on a store that had never run the
  /// older build, which is the worst kind of security fix: correct in tests,
  /// inert in the field.
  ///
  /// This removes, in order: every grant already carrying `marker`, and every
  /// *legacy* grant that matches the pre-marker seed signature — no purpose,
  /// `patterns == [.any]`, and a capability the incoming set governs. It then
  /// installs `desired` and persists once. Grants outside that signature are
  /// left untouched, so a narrower or purposeful grant issued by any other
  /// path survives.
  ///
  /// Returns the number of grants pruned, so a caller can log a migration that
  /// actually removed standing authority rather than assume it did nothing.
  @discardableResult
  public func reconcileSeededGrants(
    _ desired: [Grant],
    marker: String
  ) async throws(AuraError) -> Int {
    let governed = Set(desired.map(\.capability))
    // Shape of a desired grant: capability + patterns + confirmation. An
    // existing grant with an identical shape is redundant with the one about
    // to be installed — it cannot authorize anything the new one does not — so
    // it is pruned regardless of purpose. Without this, a grant written by an
    // intermediate build (already scoped, not yet marked) would survive as a
    // permanent duplicate that nothing ever cleans up.
    func isRedundantWithDesired(_ existing: Grant) -> Bool {
      desired.contains {
        $0.capability == existing.capability
          && $0.patterns == existing.patterns
          && $0.confirmationRequirement == existing.confirmationRequirement
      }
    }
    let before = grants.count
    grants.removeAll { existing in
      if existing.purpose == marker { return true }
      let isLegacySeedShape =
        existing.purpose.isEmpty
        && existing.patterns == [.any]
        && governed.contains(existing.capability)
      if isLegacySeedShape { return true }
      return isRedundantWithDesired(existing)
    }
    let pruned = before - grants.count
    grants.append(contentsOf: desired)
    try await persistGrants()
    for grant in desired {
      await emitRuleMutation(
        "reconcileSeededGrant", ruleID: grant.id, capability: grant.capability,
        actor: grant.issuer)
    }
    return pruned
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

  func matchingDenyRule(for request: PolicyEvaluationRequest) -> DenyRule? {
    denyRules.first { rule in
      guard rule.actor == nil || rule.actor == request.actor else { return false }
      guard rule.capability == nil || rule.capability == request.capability else { return false }
      return patternsSatisfied(request: request, patterns: rule.patterns)
    }
  }

  func matchingGrant(for request: PolicyEvaluationRequest) -> Grant? {
    let now = Date()
    return grants.first { grant in
      guard grant.capability == request.capability else { return false }
      guard grant.subjectActor == nil || grant.subjectActor == request.actor else { return false }
      if let expiresAt = grant.expiresAt, now >= expiresAt { return false }
      return patternsSatisfied(request: request, patterns: grant.patterns)
    }
  }

  func patternsSatisfied(request: PolicyEvaluationRequest, patterns: [ResourcePattern])
    -> Bool
  {
    for pattern in patterns where !patternSatisfied(request: request, pattern: pattern) {
      return false
    }
    return true
  }

  private func patternSatisfied(
    request: PolicyEvaluationRequest,
    pattern: ResourcePattern
  ) -> Bool {
    switch pattern {
    case .any: return true
    case .appID(let appID): return request.target.appID == appID
    case .filePath(let glob): return filePathSatisfied(request: request, glob: glob)
    case .directory(let directory, let recursive):
      return directorySatisfied(request: request, directory: directory, recursive: recursive)
    case .command(let regex): return commandSatisfied(request: request, regex: regex)
    case .argument(let allowed): return Set(request.target.arguments).isSubset(of: allowed)
    case .environment(let keys): return Set(request.environment.keys).isSubset(of: keys)
    case .network(let host, port: let portRange):
      return networkSatisfied(request: request, host: host, portRange: portRange)
    case .urlScheme(let allowed):
      return urlSchemeSatisfied(request: request, allowed: allowed)
    }
  }

  /// Fails closed on a missing scheme: a target that carries no URL scheme is
  /// not a URL open, so a scheme-scoped grant must not authorize it.
  private func urlSchemeSatisfied(
    request: PolicyEvaluationRequest,
    allowed: [String]
  ) -> Bool {
    guard let scheme = request.target.urlScheme?.lowercased(), !scheme.isEmpty else {
      return false
    }
    return allowed.contains { $0.lowercased() == scheme }
  }

  private func filePathSatisfied(request: PolicyEvaluationRequest, glob: String) -> Bool {
    guard let filePath = request.target.filePath else { return false }
    return filePath.matchesGlob(glob)
  }

  private func directorySatisfied(
    request: PolicyEvaluationRequest,
    directory: String,
    recursive: Bool
  ) -> Bool {
    guard let targetPath = request.target.filePath ?? request.target.directoryPath else {
      return false
    }
    let prefix = (directory as NSString).appendingPathComponent("")
    guard targetPath.hasPrefix(prefix) || targetPath == directory else { return false }
    guard !recursive else { return true }
    let remainder = String(targetPath.dropFirst(prefix.count))
    return !remainder.contains("/")
  }

  private func commandSatisfied(request: PolicyEvaluationRequest, regex: String) -> Bool {
    guard let command = request.target.command else { return false }
    return command.matchesRegex(regex)
  }

  private func networkSatisfied(
    request: PolicyEvaluationRequest,
    host: String,
    portRange: ClosedRange<Int>
  ) -> Bool {
    guard let requestHost = request.target.networkHost,
      requestHost.matchesGlob(host)
    else { return false }
    guard let requestPort = request.target.networkPort else { return true }
    return portRange.contains(requestPort)
  }

}
