import AuraCore
import Foundation

struct ConfigurationRejectionInput {
  let auditID: UUID
  let action: String
  let actor: ActorID
  let layer: ConfigurationLayer?
  let keys: [String]
  let detail: String
  let warnings: [String]
}

struct ConfigurationAuditInput {
  let id: UUID
  let action: String
  let actor: ActorID
  let accepted: Bool
  let layer: ConfigurationLayer?
  let keys: [String]
  let detail: String

  init(
    id: UUID = UUID(),
    action: String,
    actor: ActorID,
    accepted: Bool,
    layer: ConfigurationLayer?,
    keys: [String],
    detail: String
  ) {
    self.id = id
    self.action = action
    self.actor = actor
    self.accepted = accepted
    self.layer = layer
    self.keys = keys
    self.detail = detail
  }
}

extension ConfigurationEngine {
  // MARK: - Internal governance

  func effectiveEntry(for key: String) -> EffectiveConfigurationEntry? {
    guard let definition = schema.definitions[key] else { return nil }
    var value = definition.defaultValue
    var source: ConfigurationLayer = .secureDefaults
    for layer in ConfigurationLayer.allCases.dropFirst() {
      if let override = state.layers[layer]?[key] {
        value = override
        source = layer
      }
    }
    return EffectiveConfigurationEntry(
      key: key, value: value, sourceLayer: source,
      differsFromDefault: value != definition.defaultValue)
  }

  func effectiveValue(
    for key: String,
    before layer: ConfigurationLayer
  ) -> ConfigurationValue? {
    guard let definition = schema.definitions[key] else { return nil }
    var value = definition.defaultValue
    for candidateLayer in ConfigurationLayer.allCases.dropFirst()
    where candidateLayer < layer {
      if let override = state.layers[candidateLayer]?[key] {
        value = override
      }
    }
    return value
  }

  func constraintViolation(
    definition: ConfigurationKeyDefinition,
    proposed: ConfigurationValue,
    layer: ConfigurationLayer
  ) -> String? {
    let lowerTrustLayer = layer == .projectSettings || layer == .sessionOverrides
    let machineEnforced =
      definition.machinePolicyEnforced
      && layer > .machinePolicy
      && state.layers[.machinePolicy]?[definition.key] != nil
    guard lowerTrustLayer || machineEnforced else { return nil }
    guard
      let baseline =
        machineEnforced
        ? state.layers[.machinePolicy]?[definition.key]
        : effectiveValue(for: definition.key, before: layer)
    else { return nil }

    let violated: Bool
    switch definition.projectConstraint {
    case .unrestricted:
      violated = machineEnforced && proposed != baseline
    case .immutable:
      violated = proposed != baseline
    case .mayNotIncrease:
      violated = numeric(proposed) > numeric(baseline)
    case .mayNotDecrease:
      violated = numeric(proposed) < numeric(baseline)
    case .mayOnlyNarrow:
      guard case .stringList(let proposedItems) = proposed,
        case .stringList(let baselineItems) = baseline
      else { return "\(definition.key) has an invalid narrowing constraint type" }
      violated = !Set(proposedItems).isSubset(of: Set(baselineItems))
    }
    return violated
      ? "\(definition.key) at \(layer.rawValue) would weaken a higher-trust security bound"
      : nil
  }

  func reject(_ input: ConfigurationRejectionInput) async throws(AuraError)
    -> ConfigurationChangeResult
  {
    var candidate = state
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          id: input.auditID,
          action: input.action,
          actor: input.actor,
          accepted: false,
          layer: input.layer,
          keys: input.keys,
          detail: input.detail)))
    try await persist(candidate)
    return ConfigurationChangeResult(
      accepted: false, warnings: input.warnings, auditID: input.auditID)
  }

  func appendSnapshot(to candidate: inout ConfigurationGovernanceState, reason: String) {
    candidate.snapshots.append(
      ConfigurationSnapshot(
        id: UUID(), timestamp: now(), reason: reason, schemaVersion: candidate.schemaVersion,
        layers: candidate.layers, featureFlags: candidate.featureFlags))
    if candidate.snapshots.count > compatibilitySnapshotLimit {
      candidate.snapshots.removeFirst(candidate.snapshots.count - compatibilitySnapshotLimit)
    }
  }

  func persist(_ candidate: ConfigurationGovernanceState) async throws(AuraError) {
    try await store.saveState(candidate)
    state = candidate
  }

  func audit(_ input: ConfigurationAuditInput) -> ConfigurationAuditRecord {
    ConfigurationAuditRecord(
      id: input.id,
      timestamp: now(),
      action: input.action,
      actor: input.actor,
      accepted: input.accepted,
      layer: input.layer,
      keys: input.keys.map(safeKey).sorted(),
      detail: bounded(input.detail))
  }

  func recommendation(
    key: String,
    value: ConfigurationValue,
    explanation: String,
    timestamp: Date
  ) -> TuningRecommendation {
    TuningRecommendation(
      id: UUID(), key: key, proposedValue: value, explanation: bounded(explanation, limit: 500),
      aggregateEvidence: state.telemetry, createdAt: timestamp, status: .pending)
  }

  func integerValue(for key: String) -> Int? {
    guard case .integer(let value) = effectiveValue(for: key) else { return nil }
    return value
  }

  func numberValue(for key: String) -> Double {
    guard case .number(let value) = effectiveValue(for: key) else { return 0 }
    return value
  }

  func numeric(_ value: ConfigurationValue) -> Double {
    switch value {
    case .integer(let value): Double(value)
    case .number(let value): value
    case .boolean(let value): value ? 1 : 0
    default: .nan
    }
  }

  func stableBucket(_ value: String) -> Int {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return Int(hash % 100)
  }

  func bounded(_ value: String, limit: Int = 200) -> String {
    String(value.prefix(limit))
  }

  func safeKey(_ value: String) -> String {
    guard value.count <= 128,
      value.unicodeScalars.allSatisfy({
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).contains($0)
      })
    else { return "<invalid-key-redacted>" }
    return value
  }

  func format(_ value: Double) -> String {
    String(format: "%.2f", value)
  }

  static func migrate(
    _ initial: ConfigurationGovernanceState,
    to targetVersion: String,
    migrations: [ConfigurationMigration],
    compatibilitySnapshotLimit: Int,
    now: Date
  ) throws(AuraError) -> ConfigurationGovernanceState {
    var candidate = initial
    var visited: Set<String> = []
    while candidate.schemaVersion != targetVersion {
      guard !visited.contains(candidate.schemaVersion) else {
        throw AuraError.invalidConfiguration("configuration migration cycle detected")
      }
      visited.insert(candidate.schemaVersion)
      if let forward = migrations.first(where: { $0.fromVersion == candidate.schemaVersion }) {
        candidate.snapshots.append(
          ConfigurationSnapshot(
            id: UUID(), timestamp: now, reason: "before schema migration",
            schemaVersion: candidate.schemaVersion, layers: candidate.layers,
            featureFlags: candidate.featureFlags))
        candidate = forward.migrateForward(candidate)
      } else if let reverse = migrations.first(where: {
        $0.toVersion == candidate.schemaVersion && $0.fromVersion == targetVersion
      }) {
        candidate = reverse.migrateReverse(candidate)
      } else {
        throw AuraError.invalidConfiguration(
          "no reversible migration path from \(candidate.schemaVersion) to \(targetVersion)")
      }
      if candidate.snapshots.count > compatibilitySnapshotLimit {
        candidate.snapshots.removeFirst(candidate.snapshots.count - compatibilitySnapshotLimit)
      }
    }
    return candidate
  }
}
