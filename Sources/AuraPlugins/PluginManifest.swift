import AuraCore
import Foundation

/// Declared audit posture of a plugin, informing how closely its actions
/// should be logged/reviewed once a real execution runtime exists.
public enum PluginAuditLevel: String, Codable, Sendable, Equatable, CaseIterable {
  case standard
  case elevated
}

/// A plugin's self-declared, cryptographically verifiable identity and
/// capability request — the manifest schema from `docs/subsystems/
/// 23_PLUGIN_SYSTEM.md`. Untrusted until `PluginVerifier` confirms
/// `contentHashSHA256Hex` matches the real bundle payload and
/// `signatureBase64` is a valid vendor signature over `signedPayload`.
public struct PluginManifest: Codable, Sendable, Equatable, Identifiable {
  /// Reverse-DNS plugin identifier, e.g. `"com.example.myplugin"`.
  public let id: String
  /// Semantic version string, e.g. `"1.0.0"`.
  public let version: String
  public let vendorName: String
  public let capabilities: [Capability]
  public let requiredPermissions: [ResourcePattern]
  public let supportedApplicationBundleIDs: [String]
  public let networkDomains: [String]
  public let executableDependencies: [String]
  public let migrationNotes: String
  public let auditLevel: PluginAuditLevel
  /// Lowercase hex-encoded SHA-256 of the plugin bundle payload.
  public let contentHashSHA256Hex: String
  /// Base64-encoded Ed25519 (Curve25519 signing) signature over
  /// `signedPayload`, produced by the vendor's private key.
  public let signatureBase64: String

  public init(
    id: String,
    version: String,
    vendorName: String,
    capabilities: [Capability] = [],
    requiredPermissions: [ResourcePattern] = [],
    supportedApplicationBundleIDs: [String] = [],
    networkDomains: [String] = [],
    executableDependencies: [String] = [],
    migrationNotes: String = "",
    auditLevel: PluginAuditLevel = .standard,
    contentHashSHA256Hex: String,
    signatureBase64: String
  ) {
    self.id = id
    self.version = version
    self.vendorName = vendorName
    self.capabilities = capabilities
    self.requiredPermissions = requiredPermissions
    self.supportedApplicationBundleIDs = supportedApplicationBundleIDs
    self.networkDomains = networkDomains
    self.executableDependencies = executableDependencies
    self.migrationNotes = migrationNotes
    self.auditLevel = auditLevel
    self.contentHashSHA256Hex = contentHashSHA256Hex
    self.signatureBase64 = signatureBase64
  }

  /// Structural validation only — does not verify the hash or signature are
  /// *correct*, only that they are well-formed. `PluginVerifier` performs
  /// the cryptographic checks.
  public func validate() throws(AuraError) {
    guard !id.isEmpty, id.contains(".") else {
      throw AuraError.invalidConfiguration(
        "plugin manifest id must be a non-empty reverse-DNS identifier")
    }
    guard !version.isEmpty else {
      throw AuraError.invalidConfiguration("plugin manifest version must not be empty")
    }
    guard !vendorName.isEmpty else {
      throw AuraError.invalidConfiguration("plugin manifest vendorName must not be empty")
    }
    guard contentHashSHA256Hex.count == 64,
      contentHashSHA256Hex.allSatisfy({ $0.isHexDigit })
    else {
      throw AuraError.invalidConfiguration(
        "plugin manifest contentHashSHA256Hex must be a 64-character hex string")
    }
    guard !signatureBase64.isEmpty, Data(base64Encoded: signatureBase64) != nil else {
      throw AuraError.invalidConfiguration(
        "plugin manifest signatureBase64 must be valid base64")
    }
  }

  /// Canonical bytes the vendor's signature is computed over. Built from
  /// sorted, delimited fields so byte-identical signing/verification never
  /// depends on incidental array/dictionary ordering upstream of this type.
  ///
  /// Every field `PluginRegistry.install` actually acts on must appear here.
  /// In particular `capabilities` is encoded with its full `riskTier`, not
  /// just `identifier` ("domain.action"), and `requiredPermissions` is
  /// included in full — both feed directly into the `Grant.patterns`/
  /// `Grant.capability` a verified manifest is allowed to obtain, so leaving
  /// either out of the signed payload would let a manifest be tampered with
  /// after signing (e.g. widening `requiredPermissions` to `[.any]`, or
  /// silently downgrading a capability's risk tier) without invalidating
  /// the vendor's signature.
  public var signedPayload: Data {
    var parts = [id, version, vendorName, contentHashSHA256Hex, auditLevel.rawValue]
    parts.append(
      contentsOf: capabilities.map { "\($0.domain).\($0.action).\($0.riskTier.rawValue)" }.sorted()
    )
    parts.append(contentsOf: requiredPermissions.map(Self.canonicalDescription).sorted())
    parts.append(contentsOf: supportedApplicationBundleIDs.sorted())
    parts.append(contentsOf: networkDomains.sorted())
    parts.append(contentsOf: executableDependencies.sorted())
    return Data(parts.joined(separator: "|").utf8)
  }

  /// Deterministic, unambiguous string encoding of one `ResourcePattern`
  /// for inclusion in `signedPayload`. Delimited so no two distinct
  /// patterns can collide onto the same encoded string.
  private static func canonicalDescription(_ pattern: ResourcePattern) -> String {
    switch pattern {
    case .any:
      return "any"
    case .appID(let appID):
      return "appID:\(appID)"
    case .filePath(let glob):
      return "filePath:\(glob)"
    case .directory(let directory, let recursive):
      return "directory:\(directory):\(recursive)"
    case .command(let regex):
      return "command:\(regex)"
    case .argument(let allowed):
      return "argument:\(allowed.sorted().joined(separator: ","))"
    case .environment(let keys):
      return "environment:\(keys.sorted().joined(separator: ","))"
    case .network(let host, let port):
      return "network:\(host):\(port.lowerBound)-\(port.upperBound)"
    }
  }
}
