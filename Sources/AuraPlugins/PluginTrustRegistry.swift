import AuraCore
import CryptoKit
import Foundation

/// Vendor name → trusted Ed25519 (Curve25519 signing) public key.
///
/// Deny-by-default: a vendor with no entry here can never pass
/// `PluginVerifier`, regardless of what its manifest and signature claim.
/// This is a local, user/operator-controlled trust list — not a connection
/// to any external PKI or vendor directory, matching this phase's explicit
/// scope (Phase 23 owns marketplace-scale vendor discovery/distribution).
public struct PluginTrustRegistry: Sendable {
  private let keysByVendor: [String: Curve25519.Signing.PublicKey]

  public init(keysByVendor: [String: Curve25519.Signing.PublicKey]) {
    self.keysByVendor = keysByVendor
  }

  /// Build the registry from `PluginConfiguration.trustedVendorPublicKeysBase64`.
  /// Malformed entries (invalid base64, wrong key length) are silently
  /// skipped rather than throwing — `AuraConfiguration.validate()` already
  /// rejects a malformed entry earlier in the configuration pipeline, so by
  /// the time this initializer runs the input is expected to be well-formed;
  /// skipping defensively here means a corrupted single entry can never
  /// crash plugin verification for every other vendor.
  public init(configuration: PluginConfiguration) {
    var keys: [String: Curve25519.Signing.PublicKey] = [:]
    for (vendor, base64) in configuration.trustedVendorPublicKeysBase64 {
      guard let data = Data(base64Encoded: base64),
        let key = try? Curve25519.Signing.PublicKey(rawRepresentation: data)
      else { continue }
      keys[vendor] = key
    }
    self.keysByVendor = keys
  }

  public func publicKey(forVendor vendor: String) -> Curve25519.Signing.PublicKey? {
    keysByVendor[vendor]
  }
}
