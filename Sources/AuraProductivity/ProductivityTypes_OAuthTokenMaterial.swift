import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// Secret material exists only at the Keychain adapter boundary. It must not
/// be embedded in events, prompts, model context, or capability manifests.
/// Expiry and the reviewed scope set stay beside the secret so a stale or
/// over-scoped token cannot silently remain usable after restart.
public struct OAuthTokenMaterial: Sendable, Equatable {
  public let accessToken: String
  public let refreshToken: String?
  public let expiresAt: Date?
  public let scopes: Set<String>

  public init(
    accessToken: String,
    refreshToken: String? = nil,
    expiresAt: Date? = nil,
    scopes: Set<String> = []
  ) throws(ProductivityError) {
    guard !accessToken.isEmpty else {
      throw .invalidInput("access token must not be empty")
    }
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.expiresAt = expiresAt
    self.scopes = scopes
  }
}
