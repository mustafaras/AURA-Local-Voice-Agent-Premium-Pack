import Foundation

/// Configuration for `AuraPlugins` (Phase 19 foundation, Phase 23 runtime)
/// — manifest verification, lifecycle, artifacts, and the isolated helper.
/// `trustedVendorPublicKeysBase64` is
/// deny-by-default (empty): a vendor must be explicitly added before any of
/// its plugins can pass `PluginVerifier`, matching the deny-by-default
/// posture used everywhere else in the policy engine.
public struct PluginConfiguration: Codable, Sendable, Equatable {
  /// Vendor display name → base64-encoded 32-byte raw Curve25519 (Ed25519)
  /// signing public key. A plugin manifest's `vendorName` must have a key
  /// here for its signature to ever verify.
  public var trustedVendorPublicKeysBase64: [String: String]
  /// `"normalized vendor#keyID"` → base64 Ed25519 public key. This is the
  /// Phase 23 rotation-capable trust map; the vendor-only map above remains
  /// as a `#default` migration surface.
  public var trustedVendorPublicKeysByKeyIDBase64: [String: String]

  /// Store key under which the plugin registry's lifecycle state is
  /// persisted, mirroring `PolicyConfiguration.grantStoreKey`'s convention.
  public var registryStoreKey: String
  /// Versioned plugin payload root. Empty means runtime installation is
  /// unavailable and execution fails closed.
  public var artifactRootPath: String
  /// Fixed AURA-owned sandboxed helper executable. Empty disables runtime.
  public var helperExecutablePath: String
  /// Pinned lowercase SHA-256 of the helper executable.
  public var helperSHA256Hex: String

  public init(
    trustedVendorPublicKeysBase64: [String: String] = [:],
    trustedVendorPublicKeysByKeyIDBase64: [String: String] = [:],
    registryStoreKey: String = "aura.plugins.registry",
    artifactRootPath: String = "",
    helperExecutablePath: String = "",
    helperSHA256Hex: String = ""
  ) {
    self.trustedVendorPublicKeysBase64 = trustedVendorPublicKeysBase64
    self.trustedVendorPublicKeysByKeyIDBase64 = trustedVendorPublicKeysByKeyIDBase64
    self.registryStoreKey = registryStoreKey
    self.artifactRootPath = artifactRootPath
    self.helperExecutablePath = helperExecutablePath
    self.helperSHA256Hex = helperSHA256Hex
  }

  public func validate() throws(AuraError) {
    guard !registryStoreKey.isEmpty else {
      throw AuraError.invalidConfiguration("plugins registryStoreKey must not be empty")
    }
    let helperFields = [helperExecutablePath, helperSHA256Hex]
    guard helperFields.allSatisfy(\.isEmpty) || helperFields.allSatisfy({ !$0.isEmpty }) else {
      throw AuraError.invalidConfiguration(
        "plugins helperExecutablePath and helperSHA256Hex must be configured together")
    }
    if !helperSHA256Hex.isEmpty {
      guard helperSHA256Hex.count == 64,
        helperSHA256Hex == helperSHA256Hex.lowercased(),
        helperSHA256Hex.allSatisfy(\.isHexDigit)
      else {
        throw AuraError.invalidConfiguration(
          "plugins helperSHA256Hex must be 64 lowercase hex characters")
      }
    }
    for (vendor, keyBase64) in trustedVendorPublicKeysBase64 {
      guard !vendor.isEmpty else {
        throw AuraError.invalidConfiguration(
          "plugins trustedVendorPublicKeysBase64 has an empty vendor name")
      }
      guard let data = Data(base64Encoded: keyBase64), data.count == 32 else {
        throw AuraError.invalidConfiguration(
          "plugins trustedVendorPublicKeysBase64[\(vendor)] must be a base64-encoded "
            + "32-byte Curve25519 public key"
        )
      }
    }
    for (vendorAndKeyID, keyBase64) in trustedVendorPublicKeysByKeyIDBase64 {
      let parts = vendorAndKeyID.split(separator: "#", omittingEmptySubsequences: false)
      guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else {
        throw AuraError.invalidConfiguration(
          "plugins trustedVendorPublicKeysByKeyIDBase64 keys must be vendor#keyID")
      }
      guard let data = Data(base64Encoded: keyBase64), data.count == 32 else {
        throw AuraError.invalidConfiguration(
          "plugins trustedVendorPublicKeysByKeyIDBase64[\(vendorAndKeyID)] must be "
            + "a base64-encoded 32-byte Curve25519 public key"
        )
      }
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> PluginConfiguration {
    PluginConfiguration(
      trustedVendorPublicKeysBase64: self.trustedVendorPublicKeysBase64,
      trustedVendorPublicKeysByKeyIDBase64: self.trustedVendorPublicKeysByKeyIDBase64,
      registryStoreKey: self.registryStoreKey.isEmpty
        ? PluginConfiguration().registryStoreKey
        : self.registryStoreKey,
      artifactRootPath: self.artifactRootPath,
      helperExecutablePath: self.helperExecutablePath,
      helperSHA256Hex: self.helperSHA256Hex
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = PluginConfiguration()
    trustedVendorPublicKeysBase64 =
      try container.decodeIfPresent([String: String].self, forKey: .trustedVendorPublicKeysBase64)
      ?? defaults.trustedVendorPublicKeysBase64
    trustedVendorPublicKeysByKeyIDBase64 =
      try container.decodeIfPresent(
        [String: String].self, forKey: .trustedVendorPublicKeysByKeyIDBase64)
      ?? defaults.trustedVendorPublicKeysByKeyIDBase64
    registryStoreKey =
      try container.decodeIfPresent(String.self, forKey: .registryStoreKey)
      ?? defaults.registryStoreKey
    artifactRootPath =
      try container.decodeIfPresent(String.self, forKey: .artifactRootPath)
      ?? defaults.artifactRootPath
    helperExecutablePath =
      try container.decodeIfPresent(String.self, forKey: .helperExecutablePath)
      ?? defaults.helperExecutablePath
    helperSHA256Hex =
      try container.decodeIfPresent(String.self, forKey: .helperSHA256Hex)
      ?? defaults.helperSHA256Hex
  }
}
