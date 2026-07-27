import AuraCore
import AuraPolicy
import AuraStore
import Foundation

/// Where a registered plugin currently stands. Only `.enabled` is ever
/// actionable (see `PluginRegistry.isActionable`); every other state is a
/// deliberate non-actionable rest state.
public enum PluginLifecycleState: String, Codable, Sendable, Equatable, CaseIterable {
  /// Verified and registered, but not yet explicitly enabled.
  case installed
  case enabled
  /// Explicitly turned off; re-enabling restores it — reversible.
  case disabled
  /// A protective, effectively terminal state: quarantining never reverses
  /// via `enable`; recovering requires `uninstall` and a fresh `install`.
  case quarantined
  /// Grants revoked, record retained for audit — "removes runtime
  /// artifacts while preserving audit records."
  case uninstalled
}

/// Persisted record of one registered plugin.
public struct PluginRecord: Codable, Sendable, Equatable, Identifiable {
  public var id: String { manifest.id }
  public let manifest: PluginManifest
  public var state: PluginLifecycleState
  public let installedAt: Date
  /// IDs of the `Grant`s issued for this plugin's declared capabilities,
  /// so `uninstall` can precisely revoke exactly what it issued.
  public var grantIDs: [UUID]

  public init(
    manifest: PluginManifest, state: PluginLifecycleState, installedAt: Date, grantIDs: [UUID]
  ) {
    self.manifest = manifest
    self.state = state
    self.installedAt = installedAt
    self.grantIDs = grantIDs
  }
}

/// Policy-gated plugin lifecycle registry: install (verify, then map
/// declared capabilities onto scoped `Grant`s), enable, disable, quarantine,
/// uninstall (revoke grants, retain the record). Every transition is itself
/// evaluated through `PolicyEngine` — a plugin cannot install or change its
/// own lifecycle state by simply being asked to; the policy engine's normal
/// deny-by-default/confirmation rules apply to plugin capabilities exactly
/// as they do to every other capability domain.
public actor PluginRegistry {
  private var records: [String: PluginRecord]
  private let verifier: PluginVerifier
  private let policyEngine: PolicyEngine
  private let store: AuraStore?
  private let eventBus: AuraEventBus?
  private let configuration: PluginConfiguration
  private let jsonEncoder: JSONEncoder
  private let jsonDecoder: JSONDecoder

  public init(
    verifier: PluginVerifier,
    policyEngine: PolicyEngine,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil,
    configuration: PluginConfiguration = PluginConfiguration()
  ) async throws(AuraError) {
    self.verifier = verifier
    self.policyEngine = policyEngine
    self.store = store
    self.eventBus = eventBus
    self.configuration = configuration
    self.records = [:]
    self.jsonEncoder = JSONEncoder()
    self.jsonEncoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder.outputFormatting = .sortedKeys
    self.jsonDecoder = JSONDecoder()
    self.jsonDecoder.dateDecodingStrategy = .iso8601
    try await loadFromStore()
  }

  // MARK: - Lifecycle

  /// Verify and register a new plugin. Rejects re-installing an id that is
  /// already in a non-`.uninstalled` state — no silent overwrite of an
  /// existing plugin's grants.
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
      throw AuraError.pluginError(
        "plugin \(manifest.id) is already installed (state: \(existing.state.rawValue))")
    }

    let policyDecision = await policyEngine.evaluate(
      PolicyEvaluationRequest(
        capability: .pluginInstall, actor: actor, target: PolicyTarget(appID: manifest.id),
        sessionID: sessionID, correlationID: correlationID, causationID: causationID))
    guard case .allow = policyDecision else {
      await emitVerification(manifest: manifest, result: "policyDenied")
      throw AuraError.pluginError("plugin install for \(manifest.id) denied by policy")
    }

    let verification = verifier.verify(manifest: manifest, bundleData: bundleData)
    await emitVerification(manifest: manifest, result: describe(verification))
    guard verification.isVerified else {
      throw AuraError.pluginError(
        "plugin verification failed for \(manifest.id): \(describe(verification))")
    }

    var grantIDs: [UUID] = []
    for capability in manifest.capabilities {
      let grant = Grant(
        capability: capability,
        patterns: manifest.requiredPermissions.isEmpty ? [.any] : manifest.requiredPermissions,
        confirmationRequirement: .forRiskTier(.mutation),
        issuer: .system,
        purpose: "plugin:\(manifest.id)")
      try await policyEngine.issueGrant(grant)
      grantIDs.append(grant.id)
    }

    records[manifest.id] = PluginRecord(
      manifest: manifest, state: .installed, installedAt: Date(), grantIDs: grantIDs)
    try await persist()
    await emitLifecycle(
      pluginID: manifest.id, transition: "install", resultingState: .installed, reason: "verified"
    )
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
    guard record.state != .quarantined else {
      throw AuraError.pluginError("plugin \(pluginID) is quarantined and cannot be enabled")
    }
    guard record.state != .uninstalled else {
      throw AuraError.pluginError("plugin \(pluginID) is uninstalled")
    }
    try await requirePolicyAllow(
      .pluginEnable, pluginID: pluginID, actor: actor, sessionID: sessionID,
      correlationID: correlationID, causationID: causationID)
    record.state = .enabled
    records[pluginID] = record
    try await persist()
    await emitLifecycle(pluginID: pluginID, transition: "enable", resultingState: .enabled, reason: "")
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
    try await persist()
    await emitLifecycle(
      pluginID: pluginID, transition: "disable", resultingState: .disabled, reason: "")
  }

  /// Quarantine is deliberately one-way from `enable`/`disable`'s
  /// perspective: `enable(pluginID:)` refuses a quarantined plugin, and
  /// there is no `unquarantine` — recovery requires `uninstall` followed by
  /// a fresh, re-verified `install`.
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
    record.state = .quarantined
    records[pluginID] = record
    try await persist()
    await emitLifecycle(
      pluginID: pluginID, transition: "quarantine", resultingState: .quarantined, reason: reason)
  }

  /// Revoke every grant this plugin was issued and mark it uninstalled.
  /// Idempotent: uninstalling an already-uninstalled plugin is a no-op, not
  /// an error. The record itself is retained (state flips, entry is not
  /// removed) so audit history survives.
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
    for grantID in record.grantIDs {
      // Best-effort: a grant already revoked through another path is the
      // same end state (no authority), not a failure worth aborting for.
      try? await policyEngine.revokeGrant(id: grantID)
    }
    record.state = .uninstalled
    record.grantIDs = []
    records[pluginID] = record
    try await persist()
    await emitLifecycle(
      pluginID: pluginID, transition: "uninstall", resultingState: .uninstalled, reason: "")
  }

  // MARK: - Queries

  public func record(forPluginID pluginID: String) -> PluginRecord? {
    records[pluginID]
  }

  public func allRecords() -> [PluginRecord] {
    records.values.sorted { $0.manifest.id < $1.manifest.id }
  }

  /// Whether a hypothetical future execution runtime may run this plugin's
  /// code. Only `.enabled` is actionable — `.installed` (verified but never
  /// explicitly enabled), `.disabled`, `.quarantined`, and `.uninstalled`
  /// are all non-actionable by construction, not by convention a future
  /// caller could forget to check.
  public func isActionable(pluginID: String) -> Bool {
    records[pluginID]?.state == .enabled
  }

  // MARK: - Internal

  private func requireRecord(_ pluginID: String) throws(AuraError) -> PluginRecord {
    guard let record = records[pluginID] else {
      throw AuraError.pluginError("no plugin registered with id \(pluginID)")
    }
    return record
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
        capability: capability, actor: actor, target: PolicyTarget(appID: pluginID),
        sessionID: sessionID, correlationID: correlationID, causationID: causationID))
    guard case .allow = decision else {
      throw AuraError.pluginError(
        "plugin \(capability.action) for \(pluginID) denied by policy")
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
    guard let store else { return }
    guard let json = try await store.value(forKey: configuration.registryStoreKey),
      let data = json.data(using: .utf8)
    else { return }
    do {
      let values = try jsonDecoder.decode([PluginRecord].self, from: data)
      records = Dictionary(uniqueKeysWithValues: values.map { ($0.manifest.id, $0) })
    } catch {
      throw AuraError.storeError(
        "failed to decode persisted plugin registry: \(error.localizedDescription)")
    }
  }

  private func emitVerification(manifest: PluginManifest, result: String) async {
    guard let eventBus else { return }
    let payload = PluginVerificationEvent(
      pluginID: manifest.id, version: manifest.version, result: result,
      vendorName: manifest.vendorName)
    let envelope = EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .plugin, sensitivity: .sensitive,
      payload: payload)
    await eventBus.emit(envelope)
  }

  private func emitLifecycle(
    pluginID: String, transition: String, resultingState: PluginLifecycleState, reason: String
  ) async {
    guard let eventBus else { return }
    let payload = PluginLifecycleEvent(
      pluginID: pluginID, transition: transition, resultingState: resultingState.rawValue,
      reason: reason)
    let envelope = EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .plugin, sensitivity: .sensitive,
      payload: payload)
    await eventBus.emit(envelope)
  }
}
