import CryptoKit
import Foundation

// MARK: - Confirmation requirement

/// Describes when and how a grant requires explicit user confirmation.
public enum ConfirmationRequirement: Codable, Sendable, Equatable {
  /// No confirmation required.
  case none

  /// Confirm once per session, then allow for the remainder of the session.
  case oncePerSession

  /// Confirm every request.
  case always

  /// Confirm when the capability risk tier is at least the given tier.
  case forRiskTier(PermissionRiskTier)

  /// Confirm when the target matches the given pattern (e.g. outside home).
  case when(pattern: ResourcePattern)
}
