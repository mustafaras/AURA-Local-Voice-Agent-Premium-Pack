import CryptoKit
import Foundation

// MARK: - Risk tiers

/// Risk classification for a capability or action request.
///
/// Tiers are ordered from least to most sensitive and are used by the policy
/// engine to apply default confirmation and deny rules.
public enum PermissionRiskTier: Int, Codable, Sendable, Equatable, CaseIterable {
  /// Observation of non-sensitive metadata.
  case observation = 0
  /// Reversible local action.
  case reversible = 1
  /// File or environment mutation.
  case mutation = 2
  /// External communication, push, deployment, purchase, deletion,
  /// privilege change, or sensitive-data access.
  case destructive = 3
  /// Network request: separated out so update, provider, telemetry, and
  /// cloud-model checks can be controlled independently of general
  /// destructive-tier actions.
  case network = 4
}

// MARK: - Capabilities

/// A namespaced, typed action descriptor used across tool boundaries.
///
/// Tool adapters translate model intents into concrete `Capability` requests;
/// raw model output must never be executed directly.
public struct Capability: Codable, Sendable, Equatable, Hashable {
  public let domain: String
  public let action: String
  public let riskTier: PermissionRiskTier

  public init(domain: String, action: String, riskTier: PermissionRiskTier) {
    self.domain = domain
    self.action = action
    self.riskTier = riskTier
  }
}
