import AuraCore
import Foundation

private struct ConfigurationPatchValidation {
  let knownValues: [String: ConfigurationValue]
  let unknownWarnings: [String]
  let validationWarnings: [String]
}

extension ConfigurationEngine {
  public static func load(
    schema: ConfigurationSchema = .phase24,
    store: any ConfigurationStateStoring,
    migrations: [ConfigurationMigration] = [],
    now: @escaping @Sendable () -> Date = Date.init,
    compatibilitySnapshotLimit: Int = 10
  ) async throws(AuraError) -> ConfigurationEngine {
    guard compatibilitySnapshotLimit > 0 else {
      throw AuraError.invalidConfiguration("compatibility snapshot limit must be positive")
    }
    var loaded = try await store.loadState() ?? ConfigurationGovernanceState(schema: schema)
    var requiresPersistence = false
    let schemaDefaults = schema.definitions.mapValues(\.defaultValue)
    if loaded.layers[.secureDefaults] != schemaDefaults {
      loaded.layers[.secureDefaults] = schemaDefaults
      requiresPersistence = true
    }
    if !(loaded.layers[.sessionOverrides] ?? [:]).isEmpty {
      loaded.layers[.sessionOverrides] = [:]
      loaded.audit.append(
        ConfigurationAuditRecord(
          id: UUID(), timestamp: now(), action: "session.expire", actor: .system,
          accepted: true, layer: .sessionOverrides, keys: [],
          detail: "ephemeral session overrides cleared on restart"))
      requiresPersistence = true
    }
    if loaded.schemaVersion != schema.version {
      loaded = try migrate(
        loaded, to: schema.version, migrations: migrations,
        compatibilitySnapshotLimit: compatibilitySnapshotLimit, now: now())
      requiresPersistence = true
    }
    if requiresPersistence {
      try await store.saveState(loaded)
    }
    return ConfigurationEngine(
      schema: schema,
      store: store,
      migrations: migrations,
      now: now,
      compatibilitySnapshotLimit: compatibilitySnapshotLimit,
      state: loaded)
  }

  public func apply(
    _ patch: ConfigurationPatch,
    actor: ActorID = .user
  ) async throws(AuraError) -> ConfigurationChangeResult {
    let auditID = UUID()
    guard patch.layer != .secureDefaults else {
      return try await reject(
        ConfigurationRejectionInput(
          auditID: auditID,
          action: "apply",
          actor: actor,
          layer: patch.layer,
          keys: Array(patch.values.keys),
          detail: "secure defaults are schema-owned",
          warnings: ["secure defaults cannot be overridden"]))
    }
    let validation = validatePatch(patch)
    if !validation.unknownWarnings.isEmpty {
      return try await rejectUnknownPatch(
        patch, validation: validation, auditID: auditID, actor: actor)
    }
    if !validation.validationWarnings.isEmpty {
      return try await rejectTypedPatch(
        patch, validation: validation, auditID: auditID, actor: actor)
    }
    return try await persistAcceptedPatch(
      patch, validation: validation, auditID: auditID, actor: actor)
  }

  private func rejectUnknownPatch(
    _ patch: ConfigurationPatch,
    validation: ConfigurationPatchValidation,
    auditID: UUID,
    actor: ActorID
  ) async throws(AuraError) -> ConfigurationChangeResult {
    var candidate = state
    candidate.unknownKeyWarnings.append(contentsOf: validation.unknownWarnings)
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          id: auditID, action: "apply", actor: actor, accepted: false, layer: patch.layer,
          keys: Array(patch.values.keys), detail: "unknown key rejected")))
    try await persist(candidate)
    return ConfigurationChangeResult(
      accepted: false, warnings: validation.unknownWarnings, auditID: auditID)
  }

  private func rejectTypedPatch(
    _ patch: ConfigurationPatch,
    validation: ConfigurationPatchValidation,
    auditID: UUID,
    actor: ActorID
  ) async throws(AuraError) -> ConfigurationChangeResult {
    try await reject(
      ConfigurationRejectionInput(
        auditID: auditID, action: "apply", actor: actor, layer: patch.layer,
        keys: Array(validation.knownValues.keys),
        detail: "typed or security validation rejected patch",
        warnings: validation.validationWarnings))
  }

  private func persistAcceptedPatch(
    _ patch: ConfigurationPatch,
    validation: ConfigurationPatchValidation,
    auditID: UUID,
    actor: ActorID
  ) async throws(AuraError) -> ConfigurationChangeResult {
    var candidate = state
    appendSnapshot(to: &candidate, reason: "before apply to \(patch.layer.rawValue)")
    var layerValues = candidate.layers[patch.layer] ?? [:]
    layerValues.merge(validation.knownValues) { _, new in new }
    candidate.layers[patch.layer] = layerValues
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          id: auditID, action: "apply", actor: actor, accepted: true, layer: patch.layer,
          keys: Array(validation.knownValues.keys), detail: "typed patch accepted")))
    try await persist(candidate)
    return ConfigurationChangeResult(accepted: true, warnings: [], auditID: auditID)
  }

  private func validatePatch(_ patch: ConfigurationPatch) -> ConfigurationPatchValidation {
    var unknownWarnings: [String] = []
    for key in patch.values.keys.sorted() where schema.definitions[key] == nil {
      unknownWarnings.append("unknown configuration key ignored: \(safeKey(key))")
    }
    let knownValues = patch.values.filter { schema.definitions[$0.key] != nil }
    var validationWarnings: [String] = []
    for (key, value) in knownValues.sorted(by: { $0.key < $1.key }) {
      guard let definition = schema.definitions[key] else { continue }
      guard definition.allowedLayers.contains(patch.layer) else {
        validationWarnings.append("\(key) cannot be set at \(patch.layer.rawValue)")
        continue
      }
      if let validation = definition.validate(value) {
        validationWarnings.append(validation)
        continue
      }
      if let violation = constraintViolation(
        definition: definition, proposed: value, layer: patch.layer)
      {
        validationWarnings.append(violation)
      }
    }
    return ConfigurationPatchValidation(
      knownValues: knownValues,
      unknownWarnings: unknownWarnings,
      validationWarnings: validationWarnings)
  }

  public func revokeOverrides(
    layer: ConfigurationLayer,
    keys: Set<String>? = nil,
    actor: ActorID = .user
  ) async throws(AuraError) {
    guard layer != .secureDefaults else {
      throw AuraError.permissionDenied("secure defaults are schema-owned")
    }
    var candidate = state
    appendSnapshot(to: &candidate, reason: "before override revocation")
    let removed: [String]
    if let keys {
      removed = keys.sorted()
      for key in keys {
        candidate.layers[layer]?.removeValue(forKey: key)
      }
    } else {
      removed = Array((candidate.layers[layer] ?? [:]).keys).sorted()
      candidate.layers[layer] = [:]
    }
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          action: "revoke",
          actor: actor,
          accepted: true,
          layer: layer,
          keys: removed,
          detail: "override values removed")))
    try await persist(candidate)
  }

  public func effectiveValue(for key: String) -> ConfigurationValue? {
    effectiveEntry(for: key)?.value
  }

  public func inspect() -> ConfigurationInspection {
    let entries = schema.definitions.keys.sorted().compactMap(effectiveEntry(for:))
    return ConfigurationInspection(
      schemaVersion: state.schemaVersion,
      entries: entries,
      unknownKeyWarnings: state.unknownKeyWarnings)
  }

  public func auditRecords() -> [ConfigurationAuditRecord] {
    state.audit
  }

  public func snapshots() -> [ConfigurationSnapshot] {
    state.snapshots
  }

  public func rollback(
    to snapshotID: UUID,
    actor: ActorID = .user
  ) async throws(AuraError) {
    guard let snapshot = state.snapshots.first(where: { $0.id == snapshotID }) else {
      throw AuraError.invalidConfiguration("configuration snapshot not found")
    }
    guard
      snapshot.schemaVersion == schema.version
        || migrations.contains(where: {
          ($0.fromVersion == snapshot.schemaVersion && $0.toVersion == schema.version)
            || ($0.toVersion == snapshot.schemaVersion && $0.fromVersion == schema.version)
        })
    else {
      throw AuraError.invalidConfiguration("snapshot is outside the migration compatibility window")
    }

    var candidate = state
    appendSnapshot(to: &candidate, reason: "before rollback")
    candidate.schemaVersion = snapshot.schemaVersion
    candidate.layers = snapshot.layers
    candidate.featureFlags = snapshot.featureFlags
    if candidate.schemaVersion != schema.version {
      candidate = try Self.migrate(
        candidate, to: schema.version, migrations: migrations,
        compatibilitySnapshotLimit: compatibilitySnapshotLimit, now: now())
    }
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          action: "rollback",
          actor: actor,
          accepted: true,
          layer: nil,
          keys: [],
          detail: "restored snapshot \(snapshotID.uuidString)")))
    try await persist(candidate)
  }
}
