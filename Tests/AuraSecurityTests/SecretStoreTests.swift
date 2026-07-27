import AuraCore
import AuraSecurity
import Foundation
import Testing

// MARK: - InMemorySecretStore (hermetic fake)

@Test
func inMemoryStoreRoundTripsAValue() async throws {
  let store = InMemorySecretStore()
  let value = Data("hello-secret".utf8)
  try await store.store(value, forKey: "k1")
  let retrieved = try await store.retrieve(forKey: "k1")
  #expect(retrieved == value)
}

@Test
func inMemoryStoreReturnsNilForMissingKey() async throws {
  let store = InMemorySecretStore()
  let retrieved = try await store.retrieve(forKey: "does-not-exist")
  #expect(retrieved == nil)
}

@Test
func inMemoryStoreDeleteRemovesValue() async throws {
  let store = InMemorySecretStore()
  try await store.store(Data("x".utf8), forKey: "k2")
  try await store.delete(forKey: "k2")
  let retrieved = try await store.retrieve(forKey: "k2")
  #expect(retrieved == nil)
}

@Test
func inMemoryStoreRejectsEmptyKey() async {
  let store = InMemorySecretStore()
  await #expect(throws: AuraError.self) {
    try await store.store(Data("x".utf8), forKey: "")
  }
}

// MARK: - KeychainSecretStore (real Security framework — verified live in
// this environment on 2026-07-26: add/retrieve/delete all returned
// errSecSuccess via a standalone probe before this production code was
// written). Uses a per-test-run unique service name so concurrent test runs
// never collide, and cleans up after itself.

@Test
func keychainStoreRoundTripsAValue() async throws {
  let store = KeychainSecretStore(serviceName: "ai.aura.local.secrets.test.\(UUID().uuidString)")
  let key = "test-key-\(UUID().uuidString)"
  let value = Data("keychain-round-trip-value".utf8)
  defer { Task { try? await store.delete(forKey: key) } }

  try await store.store(value, forKey: key)
  let retrieved = try await store.retrieve(forKey: key)
  #expect(retrieved == value)

  try await store.delete(forKey: key)
  let afterDelete = try await store.retrieve(forKey: key)
  #expect(afterDelete == nil)
}

@Test
func keychainStoreReturnsNilForMissingKey() async throws {
  let store = KeychainSecretStore(serviceName: "ai.aura.local.secrets.test.\(UUID().uuidString)")
  let retrieved = try await store.retrieve(forKey: "never-stored-\(UUID().uuidString)")
  #expect(retrieved == nil)
}

@Test
func keychainStoreOverwritesExistingValue() async throws {
  let store = KeychainSecretStore(serviceName: "ai.aura.local.secrets.test.\(UUID().uuidString)")
  let key = "overwrite-key-\(UUID().uuidString)"
  defer { Task { try? await store.delete(forKey: key) } }

  try await store.store(Data("first".utf8), forKey: key)
  try await store.store(Data("second".utf8), forKey: key)
  let retrieved = try await store.retrieve(forKey: key)
  #expect(retrieved == Data("second".utf8))
}

@Test
func keychainStoreRejectsEmptyKey() async {
  let store = KeychainSecretStore(serviceName: "ai.aura.local.secrets.test")
  await #expect(throws: AuraError.self) {
    try await store.store(Data("x".utf8), forKey: "")
  }
}
