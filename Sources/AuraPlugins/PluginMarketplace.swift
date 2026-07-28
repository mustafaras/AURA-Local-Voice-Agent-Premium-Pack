import AuraCore
import Foundation

public struct PluginMarketplacePackage: Sendable, Equatable, Identifiable {
  public var id: String { "\(manifest.id)@\(manifest.version)" }
  public let sourceID: String
  public let manifest: PluginManifest
  public let payload: Data

  public init(sourceID: String, manifest: PluginManifest, payload: Data) {
    self.sourceID = sourceID
    self.manifest = manifest
    self.payload = payload
  }
}

/// User-controlled, local-first marketplace catalog.
///
/// Sources have no authority merely by appearing in a catalog. The user must
/// approve a source, and install still traverses registry policy, hash,
/// vendor-key, signature, artifact, grant, and audit gates.
public actor PluginMarketplace {
  private let registry: PluginRegistry
  private var approvedSourceIDs: Set<String>
  private var packages: [String: PluginMarketplacePackage]

  public init(registry: PluginRegistry, approvedSourceIDs: Set<String> = []) {
    self.registry = registry
    self.approvedSourceIDs = approvedSourceIDs
    self.packages = [:]
  }

  public func approveSource(_ sourceID: String) throws(AuraError) {
    guard !sourceID.isEmpty else {
      throw AuraError.invalidConfiguration("marketplace source id must not be empty")
    }
    approvedSourceIDs.insert(sourceID)
  }

  public func revokeSource(_ sourceID: String) {
    approvedSourceIDs.remove(sourceID)
  }

  public func register(_ package: PluginMarketplacePackage) throws(AuraError) {
    guard approvedSourceIDs.contains(package.sourceID) else {
      throw AuraError.pluginError("marketplace source is not user-approved")
    }
    guard packages[package.id] == nil else {
      throw AuraError.pluginError("marketplace package identity is duplicated")
    }
    packages[package.id] = package
  }

  public func catalog() -> [PluginMarketplacePackage] {
    packages.values.sorted { $0.id < $1.id }
  }

  @discardableResult
  public func install(
    packageID: String,
    actor: ActorID = .user,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID()
  ) async throws(AuraError) -> PluginLifecycleState {
    guard let package = packages[packageID],
      approvedSourceIDs.contains(package.sourceID)
    else {
      throw AuraError.pluginError("marketplace package or source approval is unavailable")
    }
    return try await registry.install(
      manifest: package.manifest,
      bundleData: package.payload,
      actor: actor,
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: causationID)
  }
}
