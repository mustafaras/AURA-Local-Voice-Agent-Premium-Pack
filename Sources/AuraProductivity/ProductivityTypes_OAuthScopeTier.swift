import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// OAuth authority is deliberately represented as a closed tier, not as a
/// caller-provided string. A read-only installation can therefore never
/// silently request compose or send authority.
public enum OAuthScopeTier: String, Codable, Sendable, Equatable, CaseIterable {
  case read
  case compose
  case send
}
