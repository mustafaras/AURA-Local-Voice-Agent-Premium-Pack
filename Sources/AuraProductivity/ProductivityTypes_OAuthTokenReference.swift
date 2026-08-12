import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// A stable, non-secret pointer to a Keychain item. The token value itself is
/// intentionally absent from this type so references are safe in diagnostics
/// and audit metadata.
public struct OAuthTokenReference: Codable, Sendable, Equatable, Hashable {
  public let provider: OAuthProviderID
  public let accountID: String
  public let keychainKey: String

  public init(provider: OAuthProviderID, accountID: String) throws(ProductivityError) {
    let normalized = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty, !normalized.contains("\n"), !normalized.contains("\r") else {
      throw .invalidInput("OAuth account identifier must be non-empty and single-line")
    }
    self.provider = provider
    self.accountID = normalized
    self.keychainKey = "aura.oauth.\(provider.rawValue).\(normalized)"
  }
}
