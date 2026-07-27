import AuraCore
import AuraSecurity
import Foundation

/// In-memory `SecretStoring` fake for tests that must not depend on the
/// real Keychain (hermetic, deterministic). `KeychainSecretStoreTests`
/// separately exercises the real production implementation.
actor InMemorySecretStore: SecretStoring {
  private var storage: [String: Data] = [:]

  func store(_ value: Data, forKey key: String) async throws(AuraError) {
    guard !key.isEmpty else {
      throw AuraError.invalidConfiguration("secret key must not be empty")
    }
    storage[key] = value
  }

  func retrieve(forKey key: String) async throws(AuraError) -> Data? {
    storage[key]
  }

  func delete(forKey key: String) async throws(AuraError) {
    storage.removeValue(forKey: key)
  }
}
