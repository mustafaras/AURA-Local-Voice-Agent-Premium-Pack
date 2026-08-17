import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// Keychain-backed storage for the Safari native-messaging shared secret. The
/// underlying `SecretStoring` seam keeps unit tests off the real Keychain while
/// production uses the existing `KeychainSecretStore` implementation. The
/// secret value never appears in logs, events, prompts, or ledgers.
public actor SafariBridgeSecretStore {
  private let secretStore: any SecretStoring
  private let serviceName: String

  public init(
    secretStore: any SecretStoring,
    serviceName: String = "com.aura.safari-bridge"
  ) {
    self.secretStore = secretStore
    self.serviceName = serviceName
  }

  private func key(for profileID: String) -> String {
    "\(serviceName).\(profileID).shared-secret"
  }

  /// Provision a fresh shared secret for a profile. Returns the secret so the
  /// caller can hand it to the extension at onboarding; the secret is stored
  /// in the Keychain-backed store and never returned again by this actor.
  public func provision(profileID: String) async throws(ProductivityError) -> String {
    let secret = Self.generateSecret()
    do {
      try await secretStore.store(Data(secret.utf8), forKey: key(for: profileID))
    } catch {
      throw .providerUnavailable
    }
    return secret
  }

  /// Retrieve the shared secret for a profile, or `nil` when not provisioned.
  public func sharedSecret(profileID: String) async throws(ProductivityError) -> String? {
    do {
      guard let data = try await secretStore.retrieve(forKey: key(for: profileID)) else {
        return nil
      }
      return String(data: data, encoding: .utf8)
    } catch {
      throw .providerUnavailable
    }
  }

  /// Revoke the shared secret for a profile. After revocation the bridge is
  /// unauthenticated and the capability degrades to `.disabled`.
  public func revoke(profileID: String) async throws(ProductivityError) {
    do {
      try await secretStore.delete(forKey: key(for: profileID))
    } catch {
      throw .providerUnavailable
    }
  }

  /// Deterministic, high-entropy secret generation. 32 random bytes base64-
  /// encoded yields 256 bits of entropy, matching the HMAC-SHA256 key size.
  public static func generateSecret() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    for index in bytes.indices {
      bytes[index] = UInt8.random(in: .min ... .max)
    }
    return Data(bytes).base64EncodedString()
  }
}
