import CryptoKit
import Foundation

// MARK: - Configuration

/// Policy-specific configuration embedded in `AuraConfiguration`.
public struct PolicyConfiguration: Codable, Sendable, Equatable {
  /// Capabilities at or above this tier require explicit confirmation by default
  /// when no matching grant says otherwise.
  public var defaultConfirmationTier: PermissionRiskTier

  /// Number of seconds a confirmation challenge remains valid.
  public var confirmationExpirySeconds: Double

  /// Risk tiers that are allowed when no grant exists (dangerous; default empty).
  public var allowByDefaultTiers: Set<PermissionRiskTier>

  /// Risk tiers that are denied when no grant exists (default all except observation).
  public var denyByDefaultTiers: Set<PermissionRiskTier>

  /// Store key under which grants are persisted.
  public var grantStoreKey: String

  /// Store key under which deny rules are persisted.
  public var denyRuleStoreKey: String

  public init(
    defaultConfirmationTier: PermissionRiskTier = .mutation,
    confirmationExpirySeconds: Double = 60.0,
    allowByDefaultTiers: Set<PermissionRiskTier> = [],
    denyByDefaultTiers: Set<PermissionRiskTier> = [.reversible, .mutation, .destructive, .network],
    grantStoreKey: String = "aura.policy.grants",
    denyRuleStoreKey: String = "aura.policy.denyRules"
  ) {
    self.defaultConfirmationTier = defaultConfirmationTier
    self.confirmationExpirySeconds = confirmationExpirySeconds
    self.allowByDefaultTiers = allowByDefaultTiers
    self.denyByDefaultTiers = denyByDefaultTiers
    self.grantStoreKey = grantStoreKey
    self.denyRuleStoreKey = denyRuleStoreKey
  }

  public func validate() throws(AuraError) {
    guard confirmationExpirySeconds > 0 else {
      throw AuraError.invalidConfiguration("policy confirmationExpirySeconds must be positive")
    }
    guard !grantStoreKey.isEmpty else {
      throw AuraError.invalidConfiguration("policy grantStoreKey must not be empty")
    }
    guard !denyRuleStoreKey.isEmpty else {
      throw AuraError.invalidConfiguration("policy denyRuleStoreKey must not be empty")
    }
    let overlap = allowByDefaultTiers.intersection(denyByDefaultTiers)
    guard overlap.isEmpty else {
      throw AuraError.invalidConfiguration(
        "policy allowByDefaultTiers and denyByDefaultTiers overlap: "
          + "\(overlap.map { String($0.rawValue) }.joined(separator: ", "))"
      )
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    defaultConfirmationTier =
      try container.decodeIfPresent(PermissionRiskTier.self, forKey: .defaultConfirmationTier)
      ?? .mutation
    confirmationExpirySeconds =
      try container.decodeIfPresent(Double.self, forKey: .confirmationExpirySeconds) ?? 60.0
    allowByDefaultTiers =
      try container.decodeIfPresent(Set<PermissionRiskTier>.self, forKey: .allowByDefaultTiers)
      ?? []
    denyByDefaultTiers =
      try container.decodeIfPresent(Set<PermissionRiskTier>.self, forKey: .denyByDefaultTiers) ?? [
        .reversible, .mutation, .destructive, .network,
      ]
    grantStoreKey =
      try container.decodeIfPresent(String.self, forKey: .grantStoreKey) ?? "aura.policy.grants"
    denyRuleStoreKey =
      try container.decodeIfPresent(String.self, forKey: .denyRuleStoreKey)
      ?? "aura.policy.denyRules"
  }

  /// Merge a partial policy configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> PolicyConfiguration {
    PolicyConfiguration(
      defaultConfirmationTier: self.defaultConfirmationTier,
      confirmationExpirySeconds: self.confirmationExpirySeconds <= 0
        ? PolicyConfiguration().confirmationExpirySeconds
        : self.confirmationExpirySeconds,
      allowByDefaultTiers: self.allowByDefaultTiers.isEmpty
        ? PolicyConfiguration().allowByDefaultTiers
        : self.allowByDefaultTiers,
      denyByDefaultTiers: self.denyByDefaultTiers.isEmpty
        ? PolicyConfiguration().denyByDefaultTiers
        : self.denyByDefaultTiers,
      grantStoreKey: self.grantStoreKey.isEmpty
        ? PolicyConfiguration().grantStoreKey
        : self.grantStoreKey,
      denyRuleStoreKey: self.denyRuleStoreKey.isEmpty
        ? PolicyConfiguration().denyRuleStoreKey
        : self.denyRuleStoreKey
    )
  }
}
