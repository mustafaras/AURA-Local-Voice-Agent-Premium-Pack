import AuraCore
import Foundation

public actor ConfigurationEngine {
  private let schema: ConfigurationSchema
  private let store: any ConfigurationStateStoring
  private let migrations: [ConfigurationMigration]
  private let now: @Sendable () -> Date
  private let compatibilitySnapshotLimit: Int
  private var state: ConfigurationGovernanceState

  private init(
    schema: ConfigurationSchema,
    store: any ConfigurationStateStoring,
    migrations: [ConfigurationMigration],
    now: @escaping @Sendable () -> Date,
    compatibilitySnapshotLimit: Int,
    state: ConfigurationGovernanceState
  ) {
    self.schema = schema
    self.store = store
    self.migrations = migrations
    self.now = now
    self.compatibilitySnapshotLimit = compatibilitySnapshotLimit
    self.state = state
  }

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
    var warnings: [String] = []

    guard patch.layer != .secureDefaults else {
      return try await reject(
        auditID: auditID, action: "apply", actor: actor, layer: patch.layer,
        keys: Array(patch.values.keys), detail: "secure defaults are schema-owned",
        warnings: ["secure defaults cannot be overridden"])
    }

    for key in patch.values.keys.sorted() where schema.definitions[key] == nil {
      warnings.append("unknown configuration key ignored: \(safeKey(key))")
    }

    let knownValues = patch.values.filter { schema.definitions[$0.key] != nil }
    guard warnings.isEmpty else {
      var candidate = state
      candidate.unknownKeyWarnings.append(contentsOf: warnings)
      candidate.audit.append(
        audit(
          id: auditID, action: "apply", actor: actor, accepted: false, layer: patch.layer,
          keys: Array(patch.values.keys), detail: "unknown key rejected"))
      try await persist(candidate)
      return ConfigurationChangeResult(accepted: false, warnings: warnings, auditID: auditID)
    }

    for (key, value) in knownValues.sorted(by: { $0.key < $1.key }) {
      guard let definition = schema.definitions[key] else { continue }
      guard definition.allowedLayers.contains(patch.layer) else {
        warnings.append("\(key) cannot be set at \(patch.layer.rawValue)")
        continue
      }
      if let validation = definition.validate(value) {
        warnings.append(validation)
        continue
      }
      if let violation = constraintViolation(
        definition: definition, proposed: value, layer: patch.layer)
      {
        warnings.append(violation)
      }
    }

    guard warnings.isEmpty else {
      return try await reject(
        auditID: auditID, action: "apply", actor: actor, layer: patch.layer,
        keys: Array(knownValues.keys), detail: "typed or security validation rejected patch",
        warnings: warnings)
    }

    var candidate = state
    appendSnapshot(to: &candidate, reason: "before apply to \(patch.layer.rawValue)")
    var layerValues = candidate.layers[patch.layer] ?? [:]
    layerValues.merge(knownValues) { _, new in new }
    candidate.layers[patch.layer] = layerValues
    candidate.audit.append(
      audit(
        id: auditID, action: "apply", actor: actor, accepted: true, layer: patch.layer,
        keys: Array(knownValues.keys), detail: "typed patch accepted"))
    try await persist(candidate)
    return ConfigurationChangeResult(accepted: true, warnings: [], auditID: auditID)
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
        action: "revoke", actor: actor, accepted: true, layer: layer, keys: removed,
        detail: "override values removed"))
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
        action: "rollback", actor: actor, accepted: true, layer: nil, keys: [],
        detail: "restored snapshot \(snapshotID.uuidString)"))
    try await persist(candidate)
  }

  // MARK: - Feature flags

  public func registerFeatureFlag(
    _ flag: FeatureFlagDefinition,
    actor: ActorID = .user
  ) async throws(AuraError) -> ConfigurationChangeResult {
    let auditID = UUID()
    let errors = flag.validationErrors(now: now())
    guard errors.isEmpty else {
      return try await reject(
        auditID: auditID, action: "flag.register", actor: actor, layer: nil, keys: [flag.key],
        detail: "flag metadata rejected", warnings: errors)
    }
    guard state.featureFlags[flag.key] == nil else {
      return try await reject(
        auditID: auditID, action: "flag.register", actor: actor, layer: nil, keys: [flag.key],
        detail: "duplicate flag", warnings: ["feature flag already exists: \(flag.key)"])
    }
    var candidate = state
    appendSnapshot(to: &candidate, reason: "before feature flag registration")
    candidate.featureFlags[flag.key] = flag
    candidate.audit.append(
      audit(
        id: auditID, action: "flag.register", actor: actor, accepted: true, layer: nil,
        keys: [flag.key], detail: "owner=\(bounded(flag.owner))"))
    try await persist(candidate)
    return ConfigurationChangeResult(accepted: true, warnings: [], auditID: auditID)
  }

  public func evaluateFeatureFlag(
    _ key: String,
    context: FeatureFlagContext = FeatureFlagContext()
  ) -> FeatureFlagEvaluation {
    guard let flag = state.featureFlags[key] else {
      return FeatureFlagEvaluation(enabled: false, reason: .unknownFlag, expiresAt: nil)
    }
    if flag.killSwitchEngaged {
      return FeatureFlagEvaluation(
        enabled: false, reason: .killSwitch, expiresAt: flag.expiresAt)
    }
    if flag.expiresAt <= now() {
      return FeatureFlagEvaluation(enabled: false, reason: .expired, expiresAt: flag.expiresAt)
    }
    if let userID = context.userID, let override = flag.userOverrides[userID] {
      return FeatureFlagEvaluation(
        enabled: override, reason: .userOverride, expiresAt: flag.expiresAt)
    }
    if let projectID = context.projectID, let override = flag.projectOverrides[projectID] {
      return FeatureFlagEvaluation(
        enabled: override, reason: .projectOverride, expiresAt: flag.expiresAt)
    }
    if flag.rolloutPercentage < 100 {
      let identity = context.userID ?? context.projectID ?? "anonymous"
      let included = stableBucket("\(key):\(identity)") < flag.rolloutPercentage
      return FeatureFlagEvaluation(
        enabled: flag.defaultEnabled && included,
        reason: included ? .rolloutIncluded : .rolloutExcluded,
        expiresAt: flag.expiresAt)
    }
    return FeatureFlagEvaluation(
      enabled: flag.defaultEnabled, reason: .defaultValue, expiresAt: flag.expiresAt)
  }

  public func setFeatureFlagOverride(
    key: String,
    enabled: Bool,
    userID: String? = nil,
    projectID: String? = nil,
    actor: ActorID = .user
  ) async throws(AuraError) {
    guard (userID == nil) != (projectID == nil) else {
      throw AuraError.invalidConfiguration("exactly one feature override scope is required")
    }
    guard var flag = state.featureFlags[key] else {
      throw AuraError.invalidConfiguration("unknown feature flag: \(key)")
    }
    if projectID != nil, enabled, !flag.defaultEnabled, !flag.projectMayEnable {
      throw AuraError.permissionDenied(
        "project override cannot enable a feature without registry-owned permission")
    }
    if let userID {
      flag.userOverrides[userID] = enabled
    }
    if let projectID {
      flag.projectOverrides[projectID] = enabled
    }
    var candidate = state
    appendSnapshot(to: &candidate, reason: "before feature flag override")
    candidate.featureFlags[key] = flag
    candidate.audit.append(
      audit(
        action: "flag.override", actor: actor, accepted: true, layer: nil, keys: [key],
        detail: userID == nil ? "project-scoped override" : "user-scoped override"))
    try await persist(candidate)
  }

  public func setFeatureFlagKillSwitch(
    key: String,
    engaged: Bool,
    actor: ActorID = .user
  ) async throws(AuraError) {
    guard var flag = state.featureFlags[key] else {
      throw AuraError.invalidConfiguration("unknown feature flag: \(key)")
    }
    flag.killSwitchEngaged = engaged
    var candidate = state
    appendSnapshot(to: &candidate, reason: "before feature kill switch change")
    candidate.featureFlags[key] = flag
    candidate.audit.append(
      audit(
        action: "flag.killSwitch", actor: actor, accepted: true, layer: nil, keys: [key],
        detail: engaged ? "engaged" : "released"))
    try await persist(candidate)
  }

  public func renewFeatureFlag(
    key: String,
    expiresAt: Date,
    actor: ActorID = .user
  ) async throws(AuraError) {
    guard expiresAt > now() else {
      throw AuraError.invalidConfiguration("renewed feature flag expiry must be in the future")
    }
    guard var flag = state.featureFlags[key] else {
      throw AuraError.invalidConfiguration("unknown feature flag: \(key)")
    }
    flag.expiresAt = expiresAt
    var candidate = state
    appendSnapshot(to: &candidate, reason: "before feature flag renewal")
    candidate.featureFlags[key] = flag
    candidate.audit.append(
      audit(
        action: "flag.renew", actor: actor, accepted: true, layer: nil, keys: [key],
        detail: "explicit renewal"))
    try await persist(candidate)
  }

  // MARK: - Local recommendations

  public func recordMetric(
    _ kind: TuningMetricKind,
    value: Double
  ) async throws(AuraError) {
    guard value.isFinite, value >= 0 else {
      throw AuraError.invalidConfiguration("tuning metric must be finite and non-negative")
    }
    guard effectiveValue(for: "privacy.localRecommendationsEnabled") == .boolean(true) else {
      throw AuraError.permissionDenied("local tuning recommendations require explicit opt-in")
    }
    var candidate = state
    var aggregate = candidate.telemetry[kind] ?? MetricAggregate()
    aggregate.record(value)
    candidate.telemetry[kind] = aggregate
    candidate.audit.append(
      audit(
        action: "metric.aggregate", actor: .system, accepted: true, layer: nil,
        keys: [kind.rawValue], detail: "aggregate counter updated; no raw content retained"))
    try await persist(candidate)
  }

  public func generateRecommendations() async throws(AuraError) -> [TuningRecommendation] {
    guard effectiveValue(for: "privacy.localRecommendationsEnabled") == .boolean(true) else {
      throw AuraError.permissionDenied("local tuning recommendations require explicit opt-in")
    }
    var generated: [TuningRecommendation] = []
    let timestamp = now()

    if let latency = state.telemetry[.latencySeconds], latency.sampleCount >= 3,
      let current = integerValue(for: "audio.vad.silenceEndFrames"),
      latency.average > numberValue(for: "performance.wakeAcknowledgementBudgetSeconds")
    {
      generated.append(
        recommendation(
          key: "audio.vad.silenceEndFrames", value: .integer(max(3, current - 2)),
          explanation:
            "Average local latency \(format(latency.average))s exceeds the configured "
            + "\(format(numberValue(for: "performance.wakeAcknowledgementBudgetSeconds")))s "
            + "budget across \(latency.sampleCount) samples; reduce the silence window by 2 frames.",
          timestamp: timestamp))
    }
    if let correction = state.telemetry[.userCorrection], correction.sampleCount >= 3,
      correction.average > 0.15,
      let current = integerValue(for: "stt.stabilizationDelayFrames")
    {
      generated.append(
        recommendation(
          key: "stt.stabilizationDelayFrames", value: .integer(min(20, current + 1)),
          explanation:
            "The aggregate correction rate is \(format(correction.average * 100))% across "
            + "\(correction.sampleCount) samples; add one stabilization frame.",
          timestamp: timestamp))
    }
    if let energy = state.telemetry[.energyWatts], energy.sampleCount >= 3,
      energy.average > numberValue(for: "performance.energyBudgetWatts"),
      let current = integerValue(for: "models.maxConcurrentLocalModels"), current > 1
    {
      generated.append(
        recommendation(
          key: "models.maxConcurrentLocalModels", value: .integer(current - 1),
          explanation:
            "Average local energy \(format(energy.average))W exceeds the "
            + "\(format(numberValue(for: "performance.energyBudgetWatts")))W budget across "
            + "\(energy.sampleCount) samples; reduce concurrent model residency by one.",
          timestamp: timestamp))
    }

    guard !generated.isEmpty else { return [] }
    var candidate = state
    candidate.recommendations.append(contentsOf: generated)
    candidate.audit.append(
      audit(
        action: "recommendation.generate", actor: .system, accepted: true, layer: nil,
        keys: generated.map(\.key), detail: "explainable local recommendations generated"))
    try await persist(candidate)
    return generated
  }

  public func recommendations() -> [TuningRecommendation] {
    state.recommendations
  }

  public func acceptRecommendation(
    id: UUID,
    actor: ActorID = .user
  ) async throws(AuraError) -> ConfigurationChangeResult {
    guard let index = state.recommendations.firstIndex(where: { $0.id == id }),
      state.recommendations[index].status == .pending
    else {
      throw AuraError.invalidConfiguration("pending recommendation not found")
    }
    let recommendation = state.recommendations[index]
    let result = try await apply(
      ConfigurationPatch(
        layer: .userSettings,
        values: [recommendation.key: recommendation.proposedValue],
        source: "accepted local recommendation \(id.uuidString)"),
      actor: actor)
    if result.accepted {
      var candidate = state
      guard let currentIndex = candidate.recommendations.firstIndex(where: { $0.id == id }) else {
        return result
      }
      candidate.recommendations[currentIndex].status = .accepted
      candidate.audit.append(
        audit(
          action: "recommendation.accept", actor: actor, accepted: true, layer: .userSettings,
          keys: [recommendation.key], detail: "explicit user acceptance"))
      try await persist(candidate)
    }
    return result
  }

  public func rejectRecommendation(id: UUID, actor: ActorID = .user) async throws(AuraError) {
    guard let index = state.recommendations.firstIndex(where: { $0.id == id }),
      state.recommendations[index].status == .pending
    else {
      throw AuraError.invalidConfiguration("pending recommendation not found")
    }
    var candidate = state
    candidate.recommendations[index].status = .rejected
    candidate.audit.append(
      audit(
        action: "recommendation.reject", actor: actor, accepted: true, layer: nil,
        keys: [candidate.recommendations[index].key], detail: "explicit user rejection"))
    try await persist(candidate)
  }

  // MARK: - Internal governance

  private func effectiveEntry(for key: String) -> EffectiveConfigurationEntry? {
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

  private func effectiveValue(
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

  private func constraintViolation(
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

  private func reject(
    auditID: UUID,
    action: String,
    actor: ActorID,
    layer: ConfigurationLayer?,
    keys: [String],
    detail: String,
    warnings: [String]
  ) async throws(AuraError) -> ConfigurationChangeResult {
    var candidate = state
    candidate.audit.append(
      audit(
        id: auditID, action: action, actor: actor, accepted: false, layer: layer, keys: keys,
        detail: detail))
    try await persist(candidate)
    return ConfigurationChangeResult(accepted: false, warnings: warnings, auditID: auditID)
  }

  private func appendSnapshot(to candidate: inout ConfigurationGovernanceState, reason: String) {
    candidate.snapshots.append(
      ConfigurationSnapshot(
        id: UUID(), timestamp: now(), reason: reason, schemaVersion: candidate.schemaVersion,
        layers: candidate.layers, featureFlags: candidate.featureFlags))
    if candidate.snapshots.count > compatibilitySnapshotLimit {
      candidate.snapshots.removeFirst(candidate.snapshots.count - compatibilitySnapshotLimit)
    }
  }

  private func persist(_ candidate: ConfigurationGovernanceState) async throws(AuraError) {
    try await store.saveState(candidate)
    state = candidate
  }

  private func audit(
    id: UUID = UUID(),
    action: String,
    actor: ActorID,
    accepted: Bool,
    layer: ConfigurationLayer?,
    keys: [String],
    detail: String
  ) -> ConfigurationAuditRecord {
    ConfigurationAuditRecord(
      id: id, timestamp: now(), action: action, actor: actor, accepted: accepted, layer: layer,
      keys: keys.map(safeKey).sorted(), detail: bounded(detail))
  }

  private func recommendation(
    key: String,
    value: ConfigurationValue,
    explanation: String,
    timestamp: Date
  ) -> TuningRecommendation {
    TuningRecommendation(
      id: UUID(), key: key, proposedValue: value, explanation: bounded(explanation, limit: 500),
      aggregateEvidence: state.telemetry, createdAt: timestamp, status: .pending)
  }

  private func integerValue(for key: String) -> Int? {
    guard case .integer(let value) = effectiveValue(for: key) else { return nil }
    return value
  }

  private func numberValue(for key: String) -> Double {
    guard case .number(let value) = effectiveValue(for: key) else { return 0 }
    return value
  }

  private func numeric(_ value: ConfigurationValue) -> Double {
    switch value {
    case .integer(let value): Double(value)
    case .number(let value): value
    case .boolean(let value): value ? 1 : 0
    default: .nan
    }
  }

  private func stableBucket(_ value: String) -> Int {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return Int(hash % 100)
  }

  private func bounded(_ value: String, limit: Int = 200) -> String {
    String(value.prefix(limit))
  }

  private func safeKey(_ value: String) -> String {
    guard value.count <= 128,
      value.unicodeScalars.allSatisfy({
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).contains($0)
      })
    else { return "<invalid-key-redacted>" }
    return value
  }

  private func format(_ value: Double) -> String {
    String(format: "%.2f", value)
  }

  private static func migrate(
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
