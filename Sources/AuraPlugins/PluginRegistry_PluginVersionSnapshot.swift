import AuraCore
import AuraPolicy
import AuraStore
import Foundation

public struct PluginVersionSnapshot: Codable, Sendable, Equatable {
  public let manifest: PluginManifest
  public let artifactRelativePath: String?
  public let installedAt: Date

  public init(manifest: PluginManifest, artifactRelativePath: String?, installedAt: Date) {
    self.manifest = manifest
    self.artifactRelativePath = artifactRelativePath
    self.installedAt = installedAt
  }
}
