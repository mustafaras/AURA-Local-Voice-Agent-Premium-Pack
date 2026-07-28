import AuraCore
import AuraPolicy
import AuraStore
import Foundation

public enum PluginLifecycleState: String, Codable, Sendable, Equatable, CaseIterable {
  case installed
  case enabled
  case disabled
  case quarantined
  case uninstalled
}

public struct PluginVersionSnapshot: Codable, Sendable, Equatable {
  public let manifest: PluginManifest
  public let artifactRelativePath: String?
  public let installedAt: Date

  public init(manifest: PluginManifest, artifactRelativePath: String?, installedAt: Date) {
    self.manifest = manifest
    self.artifactRelativePath = artifactRelativePath
    self.installedAt = installedAt
  }
}

public struct PluginRecord: Codable, Sendable, Equatable, Identifiable {
  public var id: String { manifest.id }
  public var manifest: PluginManifest
  public var state: PluginLifecycleState
  public let installedAt: Date
  public var grantIDs: [UUID]
  public var artifactRelativePath: String?
  public var retainedVersions: [PluginVersionSnapshot]

  public init(
    manifest: PluginManifest,
    state: PluginLifecycleState,
    installedAt: Date,
    grantIDs: [UUID],
    artifactRelativePath: String? = nil,
    retainedVersions: [PluginVersionSnapshot] = []
  ) {
    self.manifest = manifest
    self.state = state
    self.installedAt = installedAt
    self.grantIDs = grantIDs
    self.artifactRelativePath = artifactRelativePath
    self.retainedVersions = retainedVersions
  }

  private enum CodingKeys: String, CodingKey {
    case manifest, state, installedAt, grantIDs, artifactRelativePath, retainedVersions
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    manifest = try container.decode(PluginManifest.self, forKey: .manifest)
    state = try container.decode(PluginLifecycleState.self, forKey: .state)
    installedAt = try container.decode(Date.self, forKey: .installedAt)
    grantIDs = try container.decodeIfPresent([UUID].self, forKey: .grantIDs) ?? []
    artifactRelativePath =
      try container.decodeIfPresent(String.self, forKey: .artifactRelativePath)
    retainedVersions =
      try container.decodeIfPresent([PluginVersionSnapshot].self, forKey: .retainedVersions) ?? []
  }
}

/// Verified plugin lifecycle, artifact, grant, audit, and runtime coordinator.
public actor PluginRegistry {
  private var records: [String: PluginRecord]
  private let verifier: PluginVerifier
  private let policyEngine: PolicyEngine
  private let store: AuraStore?
  private let eventBus: AuraEventBus?
  private let artifactStore: PluginArtifactStore?
  private let runtimeHost: (any PluginRuntimeHosting)?
  private let configuration: PluginConfiguration
  private let jsonEncoder: JSONEncoder
  private let jsonDecoder: JSONDecoder

  public init(
    verifier: PluginVerifier,
    policyEngine: PolicyEngine,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil,
    artifactStore: PluginArtifactStore? = nil,
    runtimeHost: (any PluginRuntimeHosting)? = nil,
    configuration: PluginConfiguration = PluginConfiguration()
  ) async throws(AuraError) {
    self.verifier = verifier
    self.policyEngine = policyEngine
    self.store = store
    self.eventBus = eventBus
    self.artifactStore = artifactStore
    self.runtimeHost = runtimeHost
    self.configuration = configuration
    self.records = [:]
    self.jsonEncoder = JSONEncoder()
    self.jsonEncoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder.outputFormatting = .sortedKeys
    self.jsonDecoder = JSONDecoder()
    self.jsonDecoder.dateDecodingStrategy = .iso8601
    try await loadFromStore()
  }

  @discardableResult
  public func install(
    manifest: PluginManifest,
    bundleData: Data,
    actor: ActorID = .user,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) -> PluginLifecycleState {
    if let existing = records[manifest.id], existing.state != .uninstalled {
      throw AuraError.pluginError("plugin \(manifest.id) is already installed")
    }
    try await requirePolicyAllow(
      .pluginInstall, pluginID: manifest.id, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    try await verify(manifest, bundleData: bundleData, actor: actor, correlationID: correlationID)

    let artifactPath = try await artifactStore?.install(manifest: manifest, payload: bundleData)
    var grantIDs: [UUID] = []
    do {
      grantIDs = try await issueGrants(for: manifest)
      let now = Date()
      let snapshot = PluginVersionSnapshot(
        manifest: manifest, artifactRelativePath: artifactPath, installedAt: now)
      records[manifest.id] = PluginRecord(
        manifest: manifest,
        state: .installed,
        installedAt: now,
        grantIDs: grantIDs,
        artifactRelativePath: artifactPath,
        retainedVersions: [snapshot])
      try await persist()
      try await audit(
        pluginID: manifest.id, version: manifest.version, action: "install", actor: actor,
        outcome: "success", detail: Self.capabilitySummary(manifest), correlationID: correlationID)
    } catch {
      records.removeValue(forKey: manifest.id)
      try? await persist()
      await revoke(grantIDs)
      if let artifactStore { try? await artifactStore.removeAll(pluginID: manifest.id) }
      throw error
    }
    await emitLifecycle(
      pluginID: manifest.id, transition: "install", resultingState: .installed, reason: "")
    return .installed
  }

  public func enable(
    pluginID: String,
    actor: ActorID = .user,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) {
    var record = try requireRecord(pluginID)
    guard record.state != .quarantined, record.state != .uninstalled else {
      throw AuraError.pluginError(
        "plugin \(pluginID) cannot be enabled from \(record.state.rawValue)")
    }
    try await requirePolicyAllow(
      .pluginEnable, pluginID: pluginID, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    try await verifyCurrentArtifact(record)
    let oldRecord = record
    record.state = .enabled
    records[pluginID] = record
    do {
      try await persistAndAudit(
        record, action: "enable", actor: actor, correlationID: correlationID)
    } catch {
      records[pluginID] = oldRecord
      try? await persist()
      throw error
    }
    await emitLifecycle(
      pluginID: pluginID, transition: "enable", resultingState: .enabled, reason: "")
  }

  public func disable(
    pluginID: String,
    actor: ActorID = .user,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) {
    var record = try requireRecord(pluginID)
    guard record.state != .uninstalled else {
      throw AuraError.pluginError("plugin \(pluginID) is uninstalled")
    }
    try await requirePolicyAllow(
      .pluginDisable, pluginID: pluginID, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    record.state = .disabled
    records[pluginID] = record
    try await persistAndAudit(record, action: "disable", actor: actor, correlationID: correlationID)
    await emitLifecycle(
      pluginID: pluginID, transition: "disable", resultingState: .disabled, reason: "")
  }

  public func quarantine(
    pluginID: String,
    reason: String,
    actor: ActorID = .system,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) {
    var record = try requireRecord(pluginID)
    guard record.state != .uninstalled else {
      throw AuraError.pluginError("plugin \(pluginID) is uninstalled")
    }
    try await requirePolicyAllow(
      .pluginQuarantine, pluginID: pluginID, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    await revoke(record.grantIDs)
    record.grantIDs = []
    record.state = .quarantined
    records[pluginID] = record
    try await persistAndAudit(
      record, action: "quarantine", actor: actor, detail: reason, correlationID: correlationID)
    await emitLifecycle(
      pluginID: pluginID, transition: "quarantine", resultingState: .quarantined, reason: reason)
  }

  public func uninstall(
    pluginID: String,
    actor: ActorID = .user,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) {
    var record = try requireRecord(pluginID)
    guard record.state != .uninstalled else { return }
    try await requirePolicyAllow(
      .pluginUninstall, pluginID: pluginID, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    await revoke(record.grantIDs)
    if let artifactStore {
      try await artifactStore.removeAll(pluginID: pluginID)
    }
    record.state = .uninstalled
    record.grantIDs = []
    record.artifactRelativePath = nil
    records[pluginID] = record
    try await persistAndAudit(
      record, action: "uninstall", actor: actor,
      detail: "capabilitiesRevoked=\(record.manifest.capabilities.count)",
      correlationID: correlationID)
    await emitLifecycle(
      pluginID: pluginID, transition: "uninstall", resultingState: .uninstalled, reason: "")
  }

  public func update(
    pluginID: String,
    manifest: PluginManifest,
    bundleData: Data,
    actor: ActorID = .user,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) {
    var record = try requireRecord(pluginID)
    guard record.state != .quarantined, record.state != .uninstalled,
      manifest.id == pluginID,
      manifest.vendorName == record.manifest.vendorName,
      manifest.vendorKeyID == record.manifest.vendorKeyID,
      Self.compareVersions(manifest.version, record.manifest.version) == .orderedDescending
    else {
      throw AuraError.pluginError("plugin update identity or version transition is invalid")
    }
    try await requirePolicyAllow(
      .pluginUpdate, pluginID: pluginID, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    try await verify(manifest, bundleData: bundleData, actor: actor, correlationID: correlationID)
    guard let artifactStore else {
      throw AuraError.pluginError("versioned artifact store is required for plugin update")
    }
    let newPath = try await artifactStore.install(manifest: manifest, payload: bundleData)
    let newGrants: [UUID]
    do {
      newGrants = try await issueGrants(for: manifest)
    } catch {
      try? await artifactStore.removeVersion(pluginID: pluginID, version: manifest.version)
      throw error
    }
    let oldRecord = record
    record.manifest = manifest
    record.grantIDs = newGrants
    record.artifactRelativePath = newPath
    record.state = .disabled
    record.retainedVersions.append(
      PluginVersionSnapshot(
        manifest: manifest, artifactRelativePath: newPath, installedAt: Date()))
    records[pluginID] = record
    do {
      try await persistAndAudit(
        record, action: "update", actor: actor,
        detail: Self.capabilitySummary(manifest), correlationID: correlationID)
    } catch {
      records[pluginID] = oldRecord
      try? await persist()
      await revoke(newGrants)
      try? await artifactStore.removeVersion(pluginID: pluginID, version: manifest.version)
      throw error
    }
    await revoke(oldRecord.grantIDs)
    await emitLifecycle(
      pluginID: pluginID, transition: "update", resultingState: .disabled, reason: "")
  }

  public func rollback(
    pluginID: String,
    toVersion version: String,
    actor: ActorID = .user,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) {
    var record = try requireRecord(pluginID)
    guard record.state != .quarantined, record.state != .uninstalled,
      let snapshot = record.retainedVersions.last(where: { $0.manifest.version == version }),
      let path = snapshot.artifactRelativePath,
      let artifactStore
    else {
      throw AuraError.pluginError("verified rollback version is unavailable")
    }
    try await requirePolicyAllow(
      .pluginRollback, pluginID: pluginID, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    let rollbackArtifact = try await artifactStore.verifiedArtifact(
      relativePath: path, expectedSHA256Hex: snapshot.manifest.contentHashSHA256Hex)
    guard let rollbackData = try? Data(contentsOf: rollbackArtifact),
      verifier.verify(manifest: snapshot.manifest, bundleData: rollbackData).isVerified
    else {
      throw AuraError.pluginError("rollback manifest signature is no longer valid")
    }
    let grants = try await issueGrants(for: snapshot.manifest)
    let oldRecord = record
    record.manifest = snapshot.manifest
    record.artifactRelativePath = path
    record.grantIDs = grants
    record.state = .disabled
    records[pluginID] = record
    do {
      try await persistAndAudit(
        record, action: "rollback", actor: actor, detail: version, correlationID: correlationID)
    } catch {
      records[pluginID] = oldRecord
      try? await persist()
      await revoke(grants)
      throw error
    }
    await revoke(oldRecord.grantIDs)
    await emitLifecycle(
      pluginID: pluginID, transition: "rollback", resultingState: .disabled, reason: version)
  }

  public func execute(
    pluginID: String,
    capability: Capability,
    target: PolicyTarget,
    payload: Data,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) -> Data {
    let record = try requireRecord(pluginID)
    guard record.state == .enabled else {
      throw AuraError.pluginError("plugin \(pluginID) is not enabled")
    }
    guard record.manifest.capabilities.contains(capability) else {
      throw AuraError.pluginError("plugin attempted undeclared capability escalation")
    }
    guard PluginRuntimeAllowlist.allows(target, manifest: record.manifest) else {
      throw AuraError.pluginError("plugin target exceeds manifest allowlists")
    }
    guard let artifactStore, let path = record.artifactRelativePath, let runtimeHost else {
      throw AuraError.pluginError("verified isolated plugin runtime is unavailable")
    }
    let artifact = try await artifactStore.verifiedArtifact(
      relativePath: path, expectedSHA256Hex: record.manifest.contentHashSHA256Hex)
    guard let artifactData = try? Data(contentsOf: artifact),
      verifier.verify(manifest: record.manifest, bundleData: artifactData).isVerified
    else {
      throw AuraError.pluginError("plugin manifest or artifact re-verification failed")
    }
    let decision = await policyEngine.evaluate(
      PolicyEvaluationRequest(
        capability: capability,
        actor: .plugin,
        target: target,
        sessionID: sessionID,
        correlationID: correlationID,
        causationID: causationID))
    guard case .allow = decision else {
      throw AuraError.pluginError("plugin execution denied by policy")
    }
    let request = PluginRuntimeRequest(
      pluginID: pluginID,
      pluginVersion: record.manifest.version,
      capability: capability,
      target: target,
      payload: payload)
    let response = try await runtimeHost.execute(
      manifest: record.manifest, artifactURL: artifact, request: request)
    guard response.protocolVersion == PluginRuntimeRequest.protocolVersion,
      response.nonce == request.nonce,
      response.sandboxAttested
    else {
      throw AuraError.pluginError("plugin runtime attestation failed")
    }
    try await audit(
      pluginID: pluginID,
      version: record.manifest.version,
      action: "execute:\(capability.identifier)",
      actor: .plugin,
      outcome: "success",
      correlationID: correlationID)
    return response.output
  }

  public func record(forPluginID pluginID: String) -> PluginRecord? { records[pluginID] }
  public func allRecords() -> [PluginRecord] {
    records.values.sorted { $0.manifest.id < $1.manifest.id }
  }
  public func isActionable(pluginID: String) -> Bool { records[pluginID]?.state == .enabled }

  private func requireRecord(_ pluginID: String) throws(AuraError) -> PluginRecord {
    guard let record = records[pluginID] else {
      throw AuraError.pluginError("no plugin registered with id \(pluginID)")
    }
    return record
  }

  private func verify(
    _ manifest: PluginManifest,
    bundleData: Data,
    actor: ActorID,
    correlationID: UUID
  ) async throws(AuraError) {
    let result = verifier.verify(manifest: manifest, bundleData: bundleData)
    await emitVerification(manifest: manifest, result: describe(result))
    try await audit(
      pluginID: manifest.id,
      version: manifest.version,
      action: "verify",
      actor: actor,
      outcome: describe(result),
      correlationID: correlationID)
    guard result.isVerified else {
      throw AuraError.pluginError("plugin verification failed: \(describe(result))")
    }
  }

  private func issueGrants(for manifest: PluginManifest) async throws(AuraError) -> [UUID] {
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

  private func revoke(_ ids: [UUID]) async {
    for id in ids { try? await policyEngine.revokeGrant(id: id) }
  }

  private func verifyCurrentArtifact(_ record: PluginRecord) async throws(AuraError) {
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

  private func requirePolicyAllow(
    _ capability: Capability,
    pluginID: String,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async throws(AuraError) {
    let decision = await policyEngine.evaluate(
      PolicyEvaluationRequest(
        capability: capability,
        actor: actor,
        target: PolicyTarget(appID: pluginID),
        sessionID: sessionID,
        correlationID: correlationID,
        causationID: causationID))
    guard case .allow = decision else {
      throw AuraError.pluginError("plugin \(capability.action) for \(pluginID) denied by policy")
    }
  }

  private func persistAndAudit(
    _ record: PluginRecord,
    action: String,
    actor: ActorID,
    detail: String = "",
    correlationID: UUID
  ) async throws(AuraError) {
    try await persist()
    try await audit(
      pluginID: record.id,
      version: record.manifest.version,
      action: action,
      actor: actor,
      outcome: "success",
      detail: detail,
      correlationID: correlationID)
  }

  private func audit(
    pluginID: String,
    version: String,
    action: String,
    actor: ActorID,
    outcome: String,
    detail: String = "",
    correlationID: UUID
  ) async throws(AuraError) {
    guard let store else { return }
    try await store.appendPluginAudit(
      PluginAuditRecord(
        pluginID: pluginID,
        version: version,
        action: action,
        actor: actor,
        outcome: outcome,
        detail: detail,
        correlationID: correlationID))
  }

  private func persist() async throws(AuraError) {
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

  private func loadFromStore() async throws(AuraError) {
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

  private func describe(_ result: PluginVerificationResult) -> String {
    switch result {
    case .verified: return "verified"
    case .manifestInvalid(let detail): return "manifestInvalid: \(detail)"
    case .hashMismatch: return "hashMismatch"
    case .untrustedVendor: return "untrustedVendor"
    case .signatureInvalid: return "signatureInvalid"
    }
  }

  private func emitVerification(manifest: PluginManifest, result: String) async {
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

  private func emitLifecycle(
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

  private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
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

  private static func capabilitySummary(_ manifest: PluginManifest) -> String {
    "capabilities=" + manifest.capabilities.map(\.identifier).sorted().joined(separator: ",")
  }
}
