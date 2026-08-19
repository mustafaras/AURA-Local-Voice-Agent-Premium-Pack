import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// Keychain-backed key storage for the Safari native-messaging bridge.
///
/// The two halves of the bridge keep different things here, and neither is a
/// shared secret:
///
/// * The **extension** stores its own P-256 signing key. It never leaves that
///   process's keychain, so nothing has to cross the sandbox boundary — which
///   is what made the earlier shared-secret design unbuildable without a
///   provisioning profile.
/// * The **containing app** stores the public key it pinned when the user
///   connected the profile. A public key is not sensitive; storing it in the
///   Keychain is about *integrity*, so that pinning survives restarts and
///   cannot be silently rewritten by editing a file.
///
/// The underlying `SecretStoring` seam keeps unit tests off the real Keychain.
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

  private func signingKeyKey(for profileID: String) -> String {
    "\(serviceName).\(profileID).signing-key"
  }

  private func pinnedKeyKey(for profileID: String) -> String {
    "\(serviceName).\(profileID).pinned-public-key"
  }

  // MARK: - Extension side

  /// The extension's signing key for a profile, generated on first use.
  ///
  /// Generation is idempotent: a profile keeps one identity for its lifetime,
  /// so a key that already exists is returned rather than replaced. Rotating
  /// on every call would invalidate the app's pin on every observation.
  public func signingKey(
    profileID: String
  ) async throws(ProductivityError) -> P256.Signing.PrivateKey {
    let key = signingKeyKey(for: profileID)
    do {
      if let existing = try await secretStore.retrieve(forKey: key),
        let restored = try? P256.Signing.PrivateKey(rawRepresentation: existing)
      {
        return restored
      }
      let generated = P256.Signing.PrivateKey()
      try await secretStore.store(generated.rawRepresentation, forKey: key)
      return generated
    } catch {
      throw .providerUnavailable
    }
  }

  // MARK: - Containing-app side

  /// Pin the extension's published key for a profile. This is the act that
  /// makes a profile connected, and it is deliberately the user's: it happens
  /// when they choose to connect, not when an extension first appears.
  public func pin(
    publicKey: String, profileID: String
  ) async throws(ProductivityError) {
    guard !publicKey.isEmpty else {
      throw .invalidInput("Safari bridge public key must not be empty")
    }
    // Reject anything that is not a usable P-256 key before it is stored, so a
    // malformed pin fails at connect time rather than on every later read.
    guard let raw = Data(base64Encoded: publicKey),
      (try? P256.Signing.PublicKey(rawRepresentation: raw)) != nil
    else {
      throw .invalidInput("Safari bridge public key is not a P-256 key")
    }
    do {
      try await secretStore.store(Data(publicKey.utf8), forKey: pinnedKeyKey(for: profileID))
    } catch {
      throw .providerUnavailable
    }
  }

  /// The pinned public key for a profile, or `nil` when never connected or
  /// revoked.
  public func pinnedPublicKey(
    profileID: String
  ) async throws(ProductivityError) -> String? {
    do {
      guard let data = try await secretStore.retrieve(forKey: pinnedKeyKey(for: profileID)) else {
        return nil
      }
      return String(data: data, encoding: .utf8)
    } catch {
      throw .providerUnavailable
    }
  }

  /// Revoke a profile's pin. After revocation the bridge is unauthenticated
  /// and the capability degrades to `.disabled`, even though the extension
  /// keeps signing: an unpinned signature is exactly as untrusted as no
  /// signature at all.
  public func revoke(profileID: String) async throws(ProductivityError) {
    do {
      try await secretStore.delete(forKey: pinnedKeyKey(for: profileID))
    } catch {
      throw .providerUnavailable
    }
  }
}
