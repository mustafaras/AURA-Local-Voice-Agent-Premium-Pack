import CryptoKit
import Foundation

/// Authoritative deny rule evaluated before grants.
public struct DenyRule: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let capability: Capability?
  public let patterns: [ResourcePattern]
  public let actor: ActorID?
  public let reason: String

  public init(
    id: UUID = UUID(),
    capability: Capability? = nil,
    patterns: [ResourcePattern] = [.any],
    actor: ActorID? = nil,
    reason: String
  ) {
    self.id = id
    self.capability = capability
    self.patterns = patterns
    self.actor = actor
    self.reason = reason
  }
}
