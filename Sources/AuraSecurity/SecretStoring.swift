import AuraCore
import Foundation
import Security

/// Storage seam for secret values, mirroring the project's established
/// protocol-plus-production-implementation pattern (`AdapterProcessExecuting`,
/// `OllamaAPIClient`) so tests never touch the real Keychain unless they
/// explicitly want a live integration check.
public protocol SecretStoring: Sendable {
  func store(_ value: Data, forKey key: String) async throws(AuraError)
  func retrieve(forKey key: String) async throws(AuraError) -> Data?
  func delete(forKey key: String) async throws(AuraError)
}

/// Production `SecretStoring` backed by the macOS Keychain via the `Security`
/// framework's generic-password APIs (`SecItemAdd`/`SecItemCopyMatching`/
/// `SecItemDelete`) — verified against a real Keychain in this environment
/// (add/retrieve/delete round-trip all returned `errSecSuccess`) on
/// 2026-07-26, not assumed from documentation alone.
///
/// Secrets are stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// — never synced to iCloud Keychain, never accessible before first unlock —
/// matching "Store credentials in macOS Keychain" (`docs/security/
/// 29_SECRET_HANDLING.md`) and the project's local-first posture.
public actor KeychainSecretStore: SecretStoring {
  private let serviceName: String

  public init(serviceName: String) {
    self.serviceName = serviceName
  }

  public func store(_ value: Data, forKey key: String) async throws(AuraError) {
    guard !key.isEmpty else {
      throw AuraError.invalidConfiguration("secret key must not be empty")
    }
    // Delete-then-add rather than SecItemUpdate: idempotent regardless of
    // whether a prior value exists, and avoids a second query round trip to
    // check existence first.
    _ = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    var addQuery = baseQuery(forKey: key)
    addQuery[kSecValueData as String] = value
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(addQuery as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw AuraError.securityError("Keychain store failed for key '\(key)': OSStatus \(status)")
    }
  }

  public func retrieve(forKey key: String) async throws(AuraError) -> Data? {
    guard !key.isEmpty else {
      throw AuraError.invalidConfiguration("secret key must not be empty")
    }
    var query = baseQuery(forKey: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw AuraError.securityError("Keychain retrieve failed for key '\(key)': OSStatus \(status)")
    }
    guard let data = result as? Data else {
      throw AuraError.securityError("Keychain returned a non-Data result for key '\(key)'")
    }
    return data
  }

  public func delete(forKey key: String) async throws(AuraError) {
    guard !key.isEmpty else {
      throw AuraError.invalidConfiguration("secret key must not be empty")
    }
    let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw AuraError.securityError("Keychain delete failed for key '\(key)': OSStatus \(status)")
    }
  }

  private func baseQuery(forKey key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: serviceName,
      kSecAttrAccount as String: key,
    ]
  }
}
