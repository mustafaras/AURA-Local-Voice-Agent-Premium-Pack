import AuraCore
import AuraSecurity
import Foundation

/// User-presentable failure states for productivity integrations. These are
/// intentionally distinct so the dialogue/UI can explain whether the user
/// needs to configure an integration, grant access, reconnect an account, or
/// retry after an external outage.
public enum ProductivityError: Error, Sendable, Equatable {
  case notConfigured
  case permissionRequired
  case permissionDenied
  case tokenExpiredOrRevoked
  case networkUnavailable
  case providerUnavailable
  case insufficientScope(required: String)
  case accountAmbiguous(candidates: [String])
  case profileAmbiguous(candidates: [String])
  case privacyBlocked(reason: String)
  case invalidInput(String)
  case invalidRedirect(host: String)
  case hostNotAllowed(host: String)
  case unsupported(String)
  case cancelled
}

extension ProductivityError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "The productivity integration is not configured."
    case .permissionRequired:
      return "The user must grant access before this integration can be read."
    case .permissionDenied:
      return "Access to this productivity integration was denied."
    case .tokenExpiredOrRevoked:
      return "The provider token is expired or revoked."
    case .networkUnavailable:
      return "The provider network is unavailable."
    case .providerUnavailable:
      return "The productivity provider is unavailable."
    case .insufficientScope(let required):
      return "The configured read scope is insufficient: \(required)."
    case .accountAmbiguous(let candidates):
      return "The account is ambiguous: \(candidates.joined(separator: ", "))."
    case .profileAmbiguous(let candidates):
      return "The browser profile is ambiguous: \(candidates.joined(separator: ", "))."
    case .privacyBlocked(let reason):
      return "Content was blocked by the privacy policy: \(reason)."
    case .invalidInput(let detail):
      return "Invalid productivity input: \(detail)."
    case .invalidRedirect(let host):
      return "The provider redirect is not allowed: \(host)."
    case .hostNotAllowed(let host):
      return "The provider host is not allowed: \(host)."
    case .unsupported(let detail):
      return "This productivity integration is unsupported: \(detail)."
    case .cancelled:
      return "The productivity request was cancelled."
    }
  }
}

/// OAuth authority is deliberately represented as a closed tier, not as a
/// caller-provided string. A read-only installation can therefore never
/// silently request compose or send authority.
public enum OAuthScopeTier: String, Codable, Sendable, Equatable, CaseIterable {
  case read
  case compose
  case send
}

public enum OAuthProviderID: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case gmail
  case microsoftGraph
  case custom
}

public struct OAuthScopeManifest: Codable, Sendable, Equatable {
  public let provider: OAuthProviderID
  public let readScopes: Set<String>
  public let composeScopes: Set<String>
  public let sendScopes: Set<String>

  public init(
    provider: OAuthProviderID,
    readScopes: Set<String>,
    composeScopes: Set<String> = [],
    sendScopes: Set<String> = []
  ) {
    self.provider = provider
    self.readScopes = readScopes
    self.composeScopes = composeScopes
    self.sendScopes = sendScopes
  }

  /// The currently selected Gmail scopes are based on Google's published
  /// scope taxonomy. No send scope is present in the read tier.
  public static let gmailReadFirst = OAuthScopeManifest(
    provider: .gmail,
    readScopes: ["https://www.googleapis.com/auth/gmail.readonly"],
    composeScopes: ["https://www.googleapis.com/auth/gmail.compose"],
    sendScopes: ["https://www.googleapis.com/auth/gmail.send"])

  public func scopes(for tier: OAuthScopeTier) -> Set<String> {
    switch tier {
    case .read:
      return readScopes
    case .compose:
      return readScopes.union(composeScopes)
    case .send:
      return readScopes.union(composeScopes).union(sendScopes)
    }
  }

  /// Validate provider-returned or caller-requested scopes against the
  /// reviewed manifest. Unknown scopes and tier escalation fail closed.
  public func validate(
    requestedScopes: Set<String>,
    for tier: OAuthScopeTier
  ) throws(ProductivityError) {
    let allowed = scopes(for: tier)
    guard requestedScopes.isSubset(of: allowed) else {
      let unknown = requestedScopes.subtracting(allowed).sorted().joined(separator: ", ")
      throw .insufficientScope(required: "unreviewed OAuth scope(s): \(unknown)")
    }
    guard requestedScopes.isSuperset(of: readScopes) else {
      throw .insufficientScope(required: readScopes.sorted().joined(separator: ", "))
    }
    if tier == .read && !requestedScopes.isDisjoint(with: composeScopes.union(sendScopes)) {
      throw .insufficientScope(required: "read-only installation cannot request compose/send")
    }
  }

  public func isReadOnly(_ scopes: Set<String>) -> Bool {
    scopes.isSubset(of: readScopes)
  }
}

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

/// Secret material exists only at the Keychain adapter boundary. It must not
/// be embedded in events, prompts, model context, or capability manifests.
public struct OAuthTokenMaterial: Sendable, Equatable {
  public let accessToken: String
  public let refreshToken: String?

  public init(accessToken: String, refreshToken: String? = nil) throws(ProductivityError) {
    guard !accessToken.isEmpty else {
      throw .invalidInput("access token must not be empty")
    }
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }
}

public protocol OAuthTokenStoring: Sendable {
  func save(
    _ material: OAuthTokenMaterial,
    for reference: OAuthTokenReference
  ) async throws(ProductivityError)
  func accessToken(
    for reference: OAuthTokenReference
  ) async throws(ProductivityError) -> String?
  func revoke(_ reference: OAuthTokenReference) async throws(ProductivityError)
}

/// Keychain-backed OAuth storage. The underlying `SecretStoring` seam keeps
/// unit tests off the real Keychain while production uses the existing
/// `KeychainSecretStore` implementation.
public actor KeychainOAuthTokenStore: OAuthTokenStoring {
  private struct StoredMaterial: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String?
  }

  private let secretStore: any SecretStoring

  public init(secretStore: any SecretStoring) {
    self.secretStore = secretStore
  }

  public func save(
    _ material: OAuthTokenMaterial,
    for reference: OAuthTokenReference
  ) async throws(ProductivityError) {
    do {
      let data = try JSONEncoder().encode(
        StoredMaterial(accessToken: material.accessToken, refreshToken: material.refreshToken))
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
      guard let material = try? JSONDecoder().decode(StoredMaterial.self, from: data) else {
        throw ProductivityError.providerUnavailable
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

public struct ApprovedIntegrationAccounts: Sendable, Equatable {
  public let accountIDs: [String]

  public init(accountIDs: [String]) {
    self.accountIDs = Array(Set(accountIDs.filter { !$0.isEmpty })).sorted()
  }

  public func resolve(requestedID: String?) throws(ProductivityError) -> String {
    if let requestedID {
      guard accountIDs.contains(requestedID) else {
        throw .accountAmbiguous(candidates: accountIDs)
      }
      return requestedID
    }
    guard accountIDs.count == 1, let only = accountIDs.first else {
      if accountIDs.isEmpty { throw .notConfigured }
      throw .accountAmbiguous(candidates: accountIDs)
    }
    return only
  }
}

public struct ApprovedBrowserProfiles: Sendable, Equatable {
  public let profileIDs: [String]

  public init(profileIDs: [String]) {
    self.profileIDs = Array(Set(profileIDs.filter { !$0.isEmpty })).sorted()
  }

  public func resolve(requestedID: String?) throws(ProductivityError) -> String {
    if let requestedID {
      guard profileIDs.contains(requestedID) else {
        throw .profileAmbiguous(candidates: profileIDs)
      }
      return requestedID
    }
    guard profileIDs.count == 1, let only = profileIDs.first else {
      if profileIDs.isEmpty { throw .notConfigured }
      throw .profileAmbiguous(candidates: profileIDs)
    }
    return only
  }
}
