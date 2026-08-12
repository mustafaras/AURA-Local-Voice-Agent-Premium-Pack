import AuraCore
import Foundation

extension ConfigurationEngine {
  // MARK: - Feature flags

  public func registerFeatureFlag(
    _ flag: FeatureFlagDefinition,
    actor: ActorID = .user
  ) async throws(AuraError) -> ConfigurationChangeResult {
    let auditID = UUID()
    let errors = flag.validationErrors(now: now())
    guard errors.isEmpty else {
      return try await reject(
        ConfigurationRejectionInput(
          auditID: auditID,
          action: "flag.register",
          actor: actor,
          layer: nil,
          keys: [flag.key],
          detail: "flag metadata rejected",
          warnings: errors))
    }
    guard state.featureFlags[flag.key] == nil else {
      return try await reject(
        ConfigurationRejectionInput(
          auditID: auditID,
          action: "flag.register",
          actor: actor,
          layer: nil,
          keys: [flag.key],
          detail: "duplicate flag",
          warnings: ["feature flag already exists: \(flag.key)"]))
    }
    var candidate = state
    appendSnapshot(to: &candidate, reason: "before feature flag registration")
    candidate.featureFlags[flag.key] = flag
    candidate.audit.append(
      audit(
        ConfigurationAuditInput(
          id: auditID,
          action: "flag.register",
          actor: actor,
          accepted: true,
          layer: nil,
          keys: [flag.key],
          detail: "owner=\(bounded(flag.owner))")))
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
        ConfigurationAuditInput(
          action: "flag.override",
          actor: actor,
          accepted: true,
          layer: nil,
          keys: [key],
          detail: userID == nil ? "project-scoped override" : "user-scoped override")))
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
        ConfigurationAuditInput(
          action: "flag.killSwitch",
          actor: actor,
          accepted: true,
          layer: nil,
          keys: [key],
          detail: engaged ? "engaged" : "released")))
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
        ConfigurationAuditInput(
          action: "flag.renew",
          actor: actor,
          accepted: true,
          layer: nil,
          keys: [key],
          detail: "explicit renewal")))
    try await persist(candidate)
  }
}
