import AuraCore
import AuraPolicy
import AuraStore
import Foundation

public struct PluginRecord: Codable, Sendable, Equatable, Identifiable {
  public var id: String { manifest.id }
  public var manifest: PluginManifest
  public var state: PluginLifecycleState
  public let installedAt: Date
  public var grantIDs: [UUID]
  public var artifactRelativePath: String?
  public var retainedVersions: [PluginVersionSnapshot]

  public init(
    manifest: PluginManifest,
    state: PluginLifecycleState,
    installedAt: Date,
    grantIDs: [UUID],
    artifactRelativePath: String? = nil,
    retainedVersions: [PluginVersionSnapshot] = []
  ) {
    self.manifest = manifest
    self.state = state
    self.installedAt = installedAt
    self.grantIDs = grantIDs
    self.artifactRelativePath = artifactRelativePath
    self.retainedVersions = retainedVersions
  }

  private enum CodingKeys: String, CodingKey {
    case manifest, state, installedAt, grantIDs, artifactRelativePath, retainedVersions
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    manifest = try container.decode(PluginManifest.self, forKey: .manifest)
    state = try container.decode(PluginLifecycleState.self, forKey: .state)
    installedAt = try container.decode(Date.self, forKey: .installedAt)
    grantIDs = try container.decodeIfPresent([UUID].self, forKey: .grantIDs) ?? []
    artifactRelativePath =
      try container.decodeIfPresent(String.self, forKey: .artifactRelativePath)
    retainedVersions =
      try container.decodeIfPresent([PluginVersionSnapshot].self, forKey: .retainedVersions) ?? []
  }
}
