import AuraCore
import AuraSecurity
import Foundation

/// Keychain-backed symmetric secret storage for the VS Code extension bridge.
///
/// Unlike the Safari bridge, which uses asymmetric P-256 pinning because a
/// sandboxed Safari extension cannot share a keychain item with the containing
/// app, the VS Code extension bridge uses a symmetric HMAC secret. The two
/// halves are provisioned through a user-controlled path: AURA generates or
/// displays the secret once, and the user confirms it in the VS Code
/// extension, which stores it in VS Code's own encrypted `SecretStorage`.
/// AURA stores the same secret in the macOS Keychain via the `SecretStoring`
/// seam. Either side can revoke the secret, which degrades all VS Code
/// capabilities back to `.disabled`.
public actor VSCodeBridgeSecretStore {
  private let secretStore: any SecretStoring
  private let serviceName: String

  /// - Parameters:
  ///   - secretStore: the backing store; production uses `KeychainSecretStore`.
  ///   - serviceName: Keychain service name that groups all VS Code bridge
  ///     secrets. The extension ID is part of the account key, so multiple
  ///     extensions can be pinned independently.
  public init(
    secretStore: any SecretStoring,
    serviceName: String = "ai.aura.vscode-bridge"
  ) {
    self.secretStore = secretStore
    self.serviceName = serviceName
  }

  private func key(forExtensionID extensionID: String) -> String {
    "\(serviceName).\(extensionID).shared-secret"
  }

  /// Store the symmetric secret for an extension identity.
  ///
  /// This is the containing-app side of the provisioning step. The secret
  /// value is never logged; only its presence and length are used for
  /// validation here.
  public func provision(
    sharedSecret: Data,
    forExtensionID extensionID: String
  ) async throws(AuraError) {
    guard !extensionID.isEmpty else {
      throw AuraError.invalidConfiguration("VS Code bridge extension ID must not be empty")
    }
    guard !sharedSecret.isEmpty else {
      throw AuraError.securityError("VS Code bridge shared secret must not be empty")
    }
    try await secretStore.store(sharedSecret, forKey: key(forExtensionID: extensionID))
  }

  /// Retrieve the stored secret for an extension identity.
  ///
  /// Returns `nil` when the extension was never provisioned or has been
  /// revoked. Callers construct an authenticator only when a non-empty secret
  /// is returned.
  public func retrieveSecret(
    forExtensionID extensionID: String
  ) async throws(AuraError) -> Data? {
    guard !extensionID.isEmpty else {
      throw AuraError.invalidConfiguration("VS Code bridge extension ID must not be empty")
    }
    return try await secretStore.retrieve(forKey: key(forExtensionID: extensionID))
  }

  /// Revoke a previously provisioned extension secret.
  ///
  /// After revocation, the bridge becomes `.unauthorized` and all VS Code
  /// capabilities return to `.disabled` until the user re-provisions.
  public func revoke(extensionID: String) async throws(AuraError) {
    guard !extensionID.isEmpty else {
      throw AuraError.invalidConfiguration("VS Code bridge extension ID must not be empty")
    }
    try await secretStore.delete(forKey: key(forExtensionID: extensionID))
  }
}
