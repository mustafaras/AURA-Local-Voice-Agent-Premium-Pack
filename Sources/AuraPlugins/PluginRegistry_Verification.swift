import AuraCore
import AuraPolicy
import AuraStore
import Foundation

struct PluginPolicyContext {
  let actor: ActorID
  let sessionID: UUID
  let correlationID: UUID
  let causationID: UUID
}

struct PluginAuditContext {
  let actor: ActorID
  let correlationID: UUID
}

struct PluginAuditInput {
  let pluginID: String
  let version: String
  let action: String
  let outcome: String
  let detail: String
}

extension PluginRegistry {
  func requireRecord(_ pluginID: String) throws(AuraError) -> PluginRecord {
    guard let record = records[pluginID] else {
      throw AuraError.pluginError("no plugin registered with id \(pluginID)")
    }
    return record
  }

  func verify(
    _ manifest: PluginManifest,
    bundleData: Data,
    actor: ActorID,
    correlationID: UUID
  ) async throws(AuraError) {
    let result = verifier.verify(manifest: manifest, bundleData: bundleData)
    await emitVerification(manifest: manifest, result: describe(result))
    try await audit(
      PluginAuditInput(
        pluginID: manifest.id,
        version: manifest.version,
        action: "verify",
        outcome: describe(result),
        detail: ""
      ),
      context: PluginAuditContext(actor: actor, correlationID: correlationID)
    )
    guard result.isVerified else {
      throw AuraError.pluginError("plugin verification failed: \(describe(result))")
    }
  }

  func issueGrants(for manifest: PluginManifest) async throws(AuraError) -> [UUID] {
    try manifest.validate()
    var ids: [UUID] = []
    do {
      for capability in manifest.capabilities {
        let grant = Grant(
          capability: capability,
          patterns: manifest.requiredPermissions,
          confirmationRequirement: .forRiskTier(.mutation),
          expiresAt: Date().addingTimeInterval(TimeInterval(manifest.grantLifetimeSeconds)),
          issuer: .system,
          subjectActor: .plugin,
          purpose: "plugin:\(manifest.id):\(manifest.version)")
        try await policyEngine.issueGrant(grant)
        ids.append(grant.id)
      }
    } catch {
      await revoke(ids)
      throw error
    }
    return ids
  }

  func revoke(_ ids: [UUID]) async {
    for id in ids { try? await policyEngine.revokeGrant(id: id) }
  }

  func verifyCurrentArtifact(_ record: PluginRecord) async throws(AuraError) {
    guard let artifactStore else { return }
    guard let path = record.artifactRelativePath else {
      throw AuraError.pluginError("plugin runtime artifact is unavailable")
    }
    let artifact = try await artifactStore.verifiedArtifact(
      relativePath: path, expectedSHA256Hex: record.manifest.contentHashSHA256Hex)
    guard let data = try? Data(contentsOf: artifact),
      verifier.verify(manifest: record.manifest, bundleData: data).isVerified
    else {
      throw AuraError.pluginError("plugin manifest or artifact re-verification failed")
    }
  }

  func requirePolicyAllow(
    _ capability: Capability,
    pluginID: String,
    context: PluginPolicyContext
  ) async throws(AuraError) {
    let decision = await policyEngine.evaluate(
      PolicyEvaluationRequest(
        capability: capability,
        actor: context.actor,
        target: PolicyTarget(appID: pluginID),
        sessionID: context.sessionID,
        correlationID: context.correlationID,
        causationID: context.causationID))
    guard case .allow = decision else {
      throw AuraError.pluginError("plugin \(capability.action) for \(pluginID) denied by policy")
    }
  }

  func persistAndAudit(
    _ record: PluginRecord,
    action: String,
    actor: ActorID,
    detail: String = "",
    correlationID: UUID
  ) async throws(AuraError) {
    try await persist()
    try await audit(
      PluginAuditInput(
        pluginID: record.id,
        version: record.manifest.version,
        action: action,
        outcome: "success",
        detail: detail
      ),
      context: PluginAuditContext(actor: actor, correlationID: correlationID)
    )
  }

  func audit(
    _ input: PluginAuditInput,
    context: PluginAuditContext
  ) async throws(AuraError) {
    guard let store else { return }
    try await store.appendPluginAudit(
      PluginAuditRecord(
        pluginID: input.pluginID,
        version: input.version,
        action: input.action,
        actor: context.actor,
        outcome: input.outcome,
        detail: input.detail,
        correlationID: context.correlationID))
  }

  func persist() async throws(AuraError) {
    guard let store else { return }
    let values = records.values.sorted { $0.manifest.id < $1.manifest.id }
    do {
      let data = try jsonEncoder.encode(values)
      guard let json = String(data: data, encoding: .utf8) else {
        throw AuraError.serializationError("failed to encode plugin registry as UTF-8")
      }
      try await store.setValue(json, forKey: configuration.registryStoreKey)
    } catch let error as AuraError {
      throw error
    } catch {
      throw AuraError.storeError("failed to persist plugin registry: \(error.localizedDescription)")
    }
  }

  func loadFromStore() async throws(AuraError) {
    guard let store,
      let json = try await store.value(forKey: configuration.registryStoreKey),
      let data = json.data(using: .utf8)
    else { return }
    do {
      let values = try jsonDecoder.decode([PluginRecord].self, from: data)
      records = Dictionary(uniqueKeysWithValues: values.map { ($0.manifest.id, $0) })
    } catch {
      throw AuraError.storeError("failed to decode persisted plugin registry")
    }
  }

  func describe(_ result: PluginVerificationResult) -> String {
    switch result {
    case .verified: return "verified"
    case .manifestInvalid(let detail): return "manifestInvalid: \(detail)"
    case .hashMismatch: return "hashMismatch"
    case .untrustedVendor: return "untrustedVendor"
    case .signatureInvalid: return "signatureInvalid"
    }
  }

  func emitVerification(manifest: PluginManifest, result: String) async {
    guard let eventBus else { return }
    await eventBus.emit(
      EventEnvelope(
        correlationID: UUID(),
        causationID: UUID(),
        actor: .system,
        sensitivity: .sensitive,
        payload: PluginVerificationEvent(
          pluginID: manifest.id,
          version: manifest.version,
          result: result,
          vendorName: manifest.vendorName)))
  }

  func emitLifecycle(
    pluginID: String,
    transition: String,
    resultingState: PluginLifecycleState,
    reason: String
  ) async {
    guard let eventBus else { return }
    await eventBus.emit(
      EventEnvelope(
        correlationID: UUID(),
        causationID: UUID(),
        actor: .system,
        sensitivity: .sensitive,
        payload: PluginLifecycleEvent(
          pluginID: pluginID,
          transition: transition,
          resultingState: resultingState.rawValue,
          reason: reason)))
  }

  static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let left = lhs.split(separator: "-", maxSplits: 1)[0].split(separator: ".").compactMap {
      Int(String($0))
    }
    let right = rhs.split(separator: "-", maxSplits: 1)[0].split(separator: ".").compactMap {
      Int(String($0))
    }
    for index in 0..<min(left.count, right.count) {
      if left[index] < right[index] { return .orderedAscending }
      if left[index] > right[index] { return .orderedDescending }
    }
    return .orderedSame
  }

  static func capabilitySummary(_ manifest: PluginManifest) -> String {
    "capabilities=" + manifest.capabilities.map(\.identifier).sorted().joined(separator: ",")
  }
}
