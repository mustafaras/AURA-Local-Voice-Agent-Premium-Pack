import AuraCore
import CryptoKit
import Foundation

/// Outcome of verifying one plugin manifest against its bundle payload.
public enum PluginVerificationResult: Sendable, Equatable {
  case verified
  case manifestInvalid(String)
  case hashMismatch
  case untrustedVendor
  case signatureInvalid

  public var isVerified: Bool {
    if case .verified = self { return true }
    return false
  }
}

/// Verifies a plugin manifest's content hash and vendor signature before
/// `PluginRegistry` will accept it — "Validate signatures and hashes"
/// (`docs/subsystems/23_PLUGIN_SYSTEM.md`).
///
/// Uses `CryptoKit.SHA256` (already the project's hashing primitive —
/// `PolicyEngine`'s confirmation-challenge hash) and `Curve25519.Signing`
/// (verified via a real `swiftc -typecheck` probe compile before use,
/// matching the project's established API-verification discipline) rather
/// than the raw `Security` framework `SecKey` C API, for a type-safe,
/// well-scoped signature primitive purpose-built for exactly this shape of
/// check.
public struct PluginVerifier: Sendable {
  private let trustRegistry: PluginTrustRegistry

  public init(trustRegistry: PluginTrustRegistry) {
    self.trustRegistry = trustRegistry
  }

  /// Verify `manifest` against the real bundle payload `bundleData`.
  ///
  /// Order matters for the returned diagnosis: structural validity, then
  /// content integrity (hash), then vendor trust, then signature validity —
  /// each step only runs once the prior one passes, so a caller always
  /// learns the *first* real problem rather than a downstream symptom of it.
  public func verify(manifest: PluginManifest, bundleData: Data) -> PluginVerificationResult {
    do {
      try manifest.validate()
    } catch {
      return .manifestInvalid(error.localizedDescription)
    }

    let actualHashHex = SHA256.hash(data: bundleData)
      .compactMap { String(format: "%02x", $0) }
      .joined()
    guard actualHashHex == manifest.contentHashSHA256Hex.lowercased() else {
      return .hashMismatch
    }

    guard let publicKey = trustRegistry.publicKey(forVendor: manifest.vendorName) else {
      return .untrustedVendor
    }

    guard let signatureData = Data(base64Encoded: manifest.signatureBase64) else {
      return .signatureInvalid
    }
    guard publicKey.isValidSignature(signatureData, for: manifest.signedPayload) else {
      return .signatureInvalid
    }

    return .verified
  }
}
