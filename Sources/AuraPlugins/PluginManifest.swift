import AuraCore
import Foundation

public enum PluginAuditLevel: String, Codable, Sendable, Equatable, CaseIterable {
  case standard
  case elevated
}

public enum PluginSigningAlgorithm: String, Codable, Sendable, Equatable {
  case ed25519
}

/// A named JSON schema advertised by a plugin for one input or output.
public struct PluginSchemaDeclaration: Codable, Sendable, Equatable, Hashable {
  public let name: String
  public let mediaType: String
  public let schemaJSON: String

  public init(name: String, mediaType: String = "application/schema+json", schemaJSON: String) {
    self.name = name
    self.mediaType = mediaType
    self.schemaJSON = schemaJSON
  }

  fileprivate func validate() throws(AuraError) {
    guard !name.isEmpty, !mediaType.isEmpty, !schemaJSON.isEmpty else {
      throw AuraError.invalidConfiguration("plugin schemas require name, mediaType, and schemaJSON")
    }
    guard let data = schemaJSON.data(using: .utf8),
      (try? JSONSerialization.jsonObject(with: data)) != nil
    else {
      throw AuraError.invalidConfiguration("plugin schema \(name) must contain valid JSON")
    }
  }
}

/// Cryptographically bound plugin manifest schema v1.
///
/// Every field that can influence identity, authority, execution, migration,
/// or data exchange participates in `signedPayload`.
public struct PluginManifest: Codable, Sendable, Equatable, Identifiable {
  public static let currentSchemaVersion = "1"

  public let schemaVersion: String
  public let id: String
  public let version: String
  public let vendorName: String
  public let vendorKeyID: String
  public let signingAlgorithm: PluginSigningAlgorithm
  public let capabilities: [Capability]
  public let inputSchemas: [PluginSchemaDeclaration]
  public let outputSchemas: [PluginSchemaDeclaration]
  public let requiredPermissions: [ResourcePattern]
  public let supportedApplicationBundleIDs: [String]
  public let networkDomains: [String]
  public let executableDependencies: [String]
  public let entrypoint: String
  public let grantLifetimeSeconds: Int
  public let migrationNotes: String
  public let auditLevel: PluginAuditLevel
  public let contentHashSHA256Hex: String
  public let signatureBase64: String

  public init(
    schemaVersion: String = PluginManifest.currentSchemaVersion,
    id: String,
    version: String,
    vendorName: String,
    vendorKeyID: String = "default",
    signingAlgorithm: PluginSigningAlgorithm = .ed25519,
    capabilities: [Capability] = [],
    inputSchemas: [PluginSchemaDeclaration] = [],
    outputSchemas: [PluginSchemaDeclaration] = [],
    requiredPermissions: [ResourcePattern] = [],
    supportedApplicationBundleIDs: [String] = [],
    networkDomains: [String] = [],
    executableDependencies: [String] = [],
    entrypoint: String = "plugin",
    grantLifetimeSeconds: Int = 3_600,
    migrationNotes: String = "",
    auditLevel: PluginAuditLevel = .standard,
    contentHashSHA256Hex: String,
    signatureBase64: String
  ) {
    self.schemaVersion = schemaVersion
    self.id = id
    self.version = version
    self.vendorName = vendorName
    self.vendorKeyID = vendorKeyID
    self.signingAlgorithm = signingAlgorithm
    self.capabilities = capabilities
    self.inputSchemas = inputSchemas
    self.outputSchemas = outputSchemas
    self.requiredPermissions = requiredPermissions
    self.supportedApplicationBundleIDs = supportedApplicationBundleIDs
    self.networkDomains = networkDomains
    self.executableDependencies = executableDependencies
    self.entrypoint = entrypoint
    self.grantLifetimeSeconds = grantLifetimeSeconds
    self.migrationNotes = migrationNotes
    self.auditLevel = auditLevel
    self.contentHashSHA256Hex = contentHashSHA256Hex
    self.signatureBase64 = signatureBase64
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion, id, version, vendorName, vendorKeyID, signingAlgorithm
    case capabilities, inputSchemas, outputSchemas, requiredPermissions
    case supportedApplicationBundleIDs, networkDomains, executableDependencies
    case entrypoint, grantLifetimeSeconds, migrationNotes, auditLevel
    case contentHashSHA256Hex, signatureBase64
  }

  /// Restrictive Phase 19 migration: absent schema-v1 fields receive local
  /// defaults, never broader permissions or runtime authority.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion =
      try container.decodeIfPresent(String.self, forKey: .schemaVersion)
      ?? Self.currentSchemaVersion
    id = try container.decode(String.self, forKey: .id)
    version = try container.decode(String.self, forKey: .version)
    vendorName = try container.decode(String.self, forKey: .vendorName)
    vendorKeyID = try container.decodeIfPresent(String.self, forKey: .vendorKeyID) ?? "default"
    signingAlgorithm =
      try container.decodeIfPresent(PluginSigningAlgorithm.self, forKey: .signingAlgorithm)
      ?? .ed25519
    capabilities = try container.decodeIfPresent([Capability].self, forKey: .capabilities) ?? []
    inputSchemas =
      try container.decodeIfPresent([PluginSchemaDeclaration].self, forKey: .inputSchemas) ?? []
    outputSchemas =
      try container.decodeIfPresent([PluginSchemaDeclaration].self, forKey: .outputSchemas) ?? []
    requiredPermissions =
      try container.decodeIfPresent([ResourcePattern].self, forKey: .requiredPermissions) ?? []
    supportedApplicationBundleIDs =
      try container.decodeIfPresent([String].self, forKey: .supportedApplicationBundleIDs) ?? []
    networkDomains =
      try container.decodeIfPresent([String].self, forKey: .networkDomains) ?? []
    executableDependencies =
      try container.decodeIfPresent([String].self, forKey: .executableDependencies) ?? []
    entrypoint = try container.decodeIfPresent(String.self, forKey: .entrypoint) ?? "plugin"
    grantLifetimeSeconds =
      try container.decodeIfPresent(Int.self, forKey: .grantLifetimeSeconds) ?? 3_600
    migrationNotes = try container.decodeIfPresent(String.self, forKey: .migrationNotes) ?? ""
    auditLevel =
      try container.decodeIfPresent(PluginAuditLevel.self, forKey: .auditLevel) ?? .standard
    contentHashSHA256Hex = try container.decode(String.self, forKey: .contentHashSHA256Hex)
    signatureBase64 = try container.decode(String.self, forKey: .signatureBase64)
  }

  public func validate() throws(AuraError) {
    guard schemaVersion == Self.currentSchemaVersion else {
      throw AuraError.invalidConfiguration("unsupported plugin manifest schemaVersion")
    }
    guard Self.isReverseDNS(id) else {
      throw AuraError.invalidConfiguration(
        "plugin manifest id must be a lowercase reverse-DNS identifier")
    }
    guard Self.isSemanticVersion(version) else {
      throw AuraError.invalidConfiguration(
        "plugin manifest version must be semantic version major.minor.patch")
    }
    guard !vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      Self.isSafeIdentifier(vendorKeyID)
    else {
      throw AuraError.invalidConfiguration("plugin vendorName and vendorKeyID must be valid")
    }
    guard Self.isSafeRelativePath(entrypoint) else {
      throw AuraError.invalidConfiguration("plugin entrypoint must be a safe relative path")
    }
    guard (60...2_592_000).contains(grantLifetimeSeconds) else {
      throw AuraError.invalidConfiguration("plugin grantLifetimeSeconds must be 60...2592000")
    }
    guard contentHashSHA256Hex.count == 64,
      contentHashSHA256Hex == contentHashSHA256Hex.lowercased(),
      contentHashSHA256Hex.allSatisfy({ $0.isHexDigit })
    else {
      throw AuraError.invalidConfiguration(
        "plugin content hash must be 64 lowercase hex characters")
    }
    guard let signature = Data(base64Encoded: signatureBase64), signature.count == 64 else {
      throw AuraError.invalidConfiguration("plugin signature must be a base64 Ed25519 signature")
    }
    guard Set(capabilities.map(\.identifier)).count == capabilities.count else {
      throw AuraError.invalidConfiguration("plugin capabilities must be unique")
    }
    if !capabilities.isEmpty {
      guard !requiredPermissions.isEmpty, !requiredPermissions.contains(.any) else {
        throw AuraError.invalidConfiguration(
          "plugins with capabilities require explicit scoped permissions; .any is forbidden")
      }
    }
    for schema in inputSchemas + outputSchemas {
      try schema.validate()
    }
    guard inputSchemas.map(\.name).uniquedCount == inputSchemas.count,
      outputSchemas.map(\.name).uniquedCount == outputSchemas.count
    else {
      throw AuraError.invalidConfiguration("plugin schema names must be unique per direction")
    }
    for bundleID in supportedApplicationBundleIDs where !Self.isReverseDNS(bundleID) {
      throw AuraError.invalidConfiguration("invalid supported application bundle identifier")
    }
    for domain in networkDomains where !Self.isNetworkDomain(domain) {
      throw AuraError.invalidConfiguration("invalid plugin network domain")
    }
    for dependency in executableDependencies where !Self.isSafeRelativePath(dependency) {
      throw AuraError.invalidConfiguration("plugin executable dependencies must be relative paths")
    }
  }

  /// Canonical sorted JSON, excluding only the signature itself.
  public var signedPayload: Data {
    let canonical = CanonicalManifest(
      schemaVersion: schemaVersion,
      id: id,
      version: version,
      vendorName: vendorName,
      vendorKeyID: vendorKeyID,
      signingAlgorithm: signingAlgorithm,
      capabilities: capabilities.sorted { $0.identifier < $1.identifier },
      inputSchemas: inputSchemas.sorted { $0.name < $1.name },
      outputSchemas: outputSchemas.sorted { $0.name < $1.name },
      requiredPermissions: requiredPermissions.sorted {
        Self.canonicalDescription($0) < Self.canonicalDescription($1)
      },
      supportedApplicationBundleIDs: supportedApplicationBundleIDs.sorted(),
      networkDomains: networkDomains.sorted(),
      executableDependencies: executableDependencies.sorted(),
      entrypoint: entrypoint,
      grantLifetimeSeconds: grantLifetimeSeconds,
      migrationNotes: migrationNotes,
      auditLevel: auditLevel,
      contentHashSHA256Hex: contentHashSHA256Hex)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(canonical)) ?? Data()
  }

  private struct CanonicalManifest: Codable {
    let schemaVersion: String
    let id: String
    let version: String
    let vendorName: String
    let vendorKeyID: String
    let signingAlgorithm: PluginSigningAlgorithm
    let capabilities: [Capability]
    let inputSchemas: [PluginSchemaDeclaration]
    let outputSchemas: [PluginSchemaDeclaration]
    let requiredPermissions: [ResourcePattern]
    let supportedApplicationBundleIDs: [String]
    let networkDomains: [String]
    let executableDependencies: [String]
    let entrypoint: String
    let grantLifetimeSeconds: Int
    let migrationNotes: String
    let auditLevel: PluginAuditLevel
    let contentHashSHA256Hex: String
  }

  private static func isReverseDNS(_ value: String) -> Bool {
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count >= 2 else { return false }
    return parts.allSatisfy {
      !$0.isEmpty && $0.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }
        && $0.first != "-" && $0.last != "-"
    }
  }

  private static func isSemanticVersion(_ value: String) -> Bool {
    let core = value.split(separator: "-", maxSplits: 1)[0]
    let parts = core.split(separator: ".", omittingEmptySubsequences: false)
    return parts.count == 3 && parts.allSatisfy { !$0.isEmpty && Int($0) != nil }
  }

  private static func isSafeIdentifier(_ value: String) -> Bool {
    !value.isEmpty && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
  }

  private static func isSafeRelativePath(_ value: String) -> Bool {
    guard !value.isEmpty, !value.hasPrefix("/"), !value.contains("\\") else { return false }
    return !value.split(separator: "/", omittingEmptySubsequences: false).contains("..")
  }

  private static func isNetworkDomain(_ value: String) -> Bool {
    !value.isEmpty && value == value.lowercased() && !value.contains("://")
      && value.split(separator: ".").allSatisfy { !$0.isEmpty }
  }

  static func canonicalDescription(_ pattern: ResourcePattern) -> String {
    switch pattern {
    case .any: return "any"
    case .appID(let value): return "appID:\(value)"
    case .filePath(let value): return "filePath:\(value)"
    case .directory(let value, let recursive): return "directory:\(value):\(recursive)"
    case .command(let value): return "command:\(value)"
    case .argument(let values): return "argument:\(values.sorted().joined(separator: ","))"
    case .environment(let values): return "environment:\(values.sorted().joined(separator: ","))"
    case .network(let host, let ports):
      return "network:\(host):\(ports.lowerBound)-\(ports.upperBound)"
    }
  }
}

extension Array where Element: Hashable {
  fileprivate var uniquedCount: Int { Set(self).count }
}
