import AuraCore
import AuraPolicy
import AuraStore
import Foundation

private struct VerifiedExecutionArtifact {
  let record: PluginRecord
  let artifact: URL
  let runtimeHost: any PluginRuntimeHosting
}

extension PluginRegistry {
  public func execute(
    pluginID: String,
    capability: Capability,
    target: PolicyTarget,
    payload: Data,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) -> Data {
    let verified = try await verifiedExecutionArtifact(
      pluginID: pluginID, capability: capability, target: target)
    let decision = await policyEngine.evaluate(
      PolicyEvaluationRequest(
        capability: capability, actor: .plugin, target: target, sessionID: sessionID,
        correlationID: correlationID, causationID: causationID))
    guard case .allow = decision else {
      throw AuraError.pluginError("plugin execution denied by policy")
    }
    let request = PluginRuntimeRequest(
      pluginID: pluginID, pluginVersion: verified.record.manifest.version,
      capability: capability, target: target, payload: payload)
    let response = try await verified.runtimeHost.execute(
      manifest: verified.record.manifest, artifactURL: verified.artifact, request: request)
    guard response.protocolVersion == PluginRuntimeRequest.protocolVersion,
      response.nonce == request.nonce, response.sandboxAttested
    else {
      throw AuraError.pluginError("plugin runtime attestation failed")
    }
    try await audit(
      PluginAuditInput(
        pluginID: pluginID, version: verified.record.manifest.version,
        action: "execute:\(capability.identifier)", outcome: "success", detail: ""),
      context: PluginAuditContext(actor: .plugin, correlationID: correlationID))
    return response.output
  }

  private func verifiedExecutionArtifact(
    pluginID: String,
    capability: Capability,
    target: PolicyTarget
  ) async throws(AuraError) -> VerifiedExecutionArtifact {
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
    return VerifiedExecutionArtifact(record: record, artifact: artifact, runtimeHost: runtimeHost)
  }

  public func record(forPluginID pluginID: String) -> PluginRecord? { records[pluginID] }
  public func allRecords() -> [PluginRecord] {
    records.values.sorted { $0.manifest.id < $1.manifest.id }
  }
  public func isActionable(pluginID: String) -> Bool { records[pluginID]?.state == .enabled }
}
