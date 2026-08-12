import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// Keychain-backed OAuth storage. The underlying `SecretStoring` seam keeps
/// unit tests off the real Keychain while production uses the existing
/// `KeychainSecretStore` implementation.
private struct StoredOAuthMaterial: Codable, Sendable, Equatable {
  let accessToken: String
  let refreshToken: String?
  let expiresAt: Date?
  let scopes: Set<String>

  enum CodingKeys: String, CodingKey {
    case accessToken, refreshToken, expiresAt, scopes
  }

  init(
    accessToken: String,
    refreshToken: String?,
    expiresAt: Date?,
    scopes: Set<String>
  ) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.expiresAt = expiresAt
    self.scopes = scopes
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    accessToken = try container.decode(String.self, forKey: .accessToken)
    refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
    expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
    scopes = try container.decodeIfPresent(Set<String>.self, forKey: .scopes) ?? []
  }
}

public actor KeychainOAuthTokenStore: OAuthTokenStoring {
  private let secretStore: any SecretStoring
  private let now: @Sendable () -> Date

  public init(secretStore: any SecretStoring, now: @escaping @Sendable () -> Date = { Date() }) {
    self.secretStore = secretStore
    self.now = now
  }

  public func save(
    _ material: OAuthTokenMaterial,
    for reference: OAuthTokenReference
  ) async throws(ProductivityError) {
    do {
      let data = try JSONEncoder().encode(
        StoredOAuthMaterial(
          accessToken: material.accessToken,
          refreshToken: material.refreshToken,
          expiresAt: material.expiresAt,
          scopes: material.scopes))
      try await secretStore.store(data, forKey: reference.keychainKey)
    } catch {
      throw .providerUnavailable
    }
  }

  public func accessToken(
    for reference: OAuthTokenReference
  ) async throws(ProductivityError) -> String? {
    do {
      guard let data = try await secretStore.retrieve(forKey: reference.keychainKey) else {
        return nil
      }
      guard let material = try? JSONDecoder().decode(StoredOAuthMaterial.self, from: data) else {
        throw ProductivityError.providerUnavailable
      }
      if let expiresAt = material.expiresAt, expiresAt <= now() {
        try? await secretStore.delete(forKey: reference.keychainKey)
        throw ProductivityError.tokenExpiredOrRevoked
      }
      return material.accessToken
    } catch let error as ProductivityError {
      throw error
    } catch {
      throw .providerUnavailable
    }
  }

  public func revoke(_ reference: OAuthTokenReference) async throws(ProductivityError) {
    do {
      try await secretStore.delete(forKey: reference.keychainKey)
    } catch {
      throw .providerUnavailable
    }
  }
}
