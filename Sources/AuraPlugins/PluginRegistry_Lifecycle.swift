import AuraCore
import AuraPolicy
import AuraStore
import Foundation

extension PluginRegistry {
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
      .pluginInstall,
      pluginID: manifest.id,
      context: PluginPolicyContext(
        actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID))
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
        PluginAuditInput(
          pluginID: manifest.id,
          version: manifest.version,
          action: "install",
          outcome: "success",
          detail: Self.capabilitySummary(manifest)
        ),
        context: PluginAuditContext(actor: actor, correlationID: correlationID)
      )
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
      .pluginEnable,
      pluginID: pluginID,
      context: PluginPolicyContext(
        actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID))
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
      .pluginDisable,
      pluginID: pluginID,
      context: PluginPolicyContext(
        actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID))
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
      .pluginQuarantine,
      pluginID: pluginID,
      context: PluginPolicyContext(
        actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID))
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
      .pluginUninstall,
      pluginID: pluginID,
      context: PluginPolicyContext(
        actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID))
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
      .pluginUpdate,
      pluginID: pluginID,
      context: PluginPolicyContext(
        actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID))
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
      .pluginRollback,
      pluginID: pluginID,
      context: PluginPolicyContext(
        actor: actor, sessionID: sessionID, correlationID: correlationID, causationID: causationID))
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
}
