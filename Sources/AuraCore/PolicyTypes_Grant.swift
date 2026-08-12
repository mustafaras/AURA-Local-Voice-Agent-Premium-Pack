import CryptoKit
import Foundation

// MARK: - Grants and deny rules

/// A user-authorized permission rule with scoped, time-bounded applicability.
public struct Grant: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let capability: Capability
  public let patterns: [ResourcePattern]
  public let confirmationRequirement: ConfirmationRequirement
  public let createdAt: Date
  public let expiresAt: Date?
  public let issuer: ActorID
  /// Optional actor this grant authorizes. `nil` preserves legacy
  /// actor-agnostic grants; plugin-issued grants always set `.plugin`.
  public let subjectActor: ActorID?
  public let purpose: String

  public init(
    id: UUID = UUID(),
    capability: Capability,
    patterns: [ResourcePattern] = [.any],
    confirmationRequirement: ConfirmationRequirement = .forRiskTier(.mutation),
    createdAt: Date = Date(),
    expiresAt: Date? = nil,
    issuer: ActorID = .user,
    subjectActor: ActorID? = nil,
    purpose: String = ""
  ) {
    self.id = id
    self.capability = capability
    self.patterns = patterns
    self.confirmationRequirement = confirmationRequirement
    self.createdAt = createdAt
    self.expiresAt = expiresAt
    self.issuer = issuer
    self.subjectActor = subjectActor
    self.purpose = purpose
  }
}
