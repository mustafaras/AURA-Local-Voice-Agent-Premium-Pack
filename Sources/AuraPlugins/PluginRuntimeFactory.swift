import AuraCore
import Foundation

public struct PluginRuntimeComponents: Sendable {
  public let artifactStore: PluginArtifactStore
  public let runtimeHost: PluginHelperProcessHost

  public init(artifactStore: PluginArtifactStore, runtimeHost: PluginHelperProcessHost) {
    self.artifactStore = artifactStore
    self.runtimeHost = runtimeHost
  }
}

public enum PluginRuntimeFactory {
  /// Construct the production runtime only from a complete, validated,
  /// operator-controlled configuration. Empty/incomplete configuration is a
  /// denial, never an implicit temporary or unsandboxed fallback.
  public static func make(configuration: PluginConfiguration) throws(AuraError)
    -> PluginRuntimeComponents
  {
    try configuration.validate()
    guard !configuration.artifactRootPath.isEmpty,
      !configuration.helperExecutablePath.isEmpty,
      !configuration.helperSHA256Hex.isEmpty
    else {
      throw AuraError.invalidConfiguration("verified plugin runtime is not configured")
    }
    let artifactStore = try PluginArtifactStore(
      rootDirectory: URL(fileURLWithPath: configuration.artifactRootPath, isDirectory: true))
    let runtimeHost = try PluginHelperProcessHost(
      helperURL: URL(fileURLWithPath: configuration.helperExecutablePath),
      expectedHelperSHA256Hex: configuration.helperSHA256Hex)
    return PluginRuntimeComponents(artifactStore: artifactStore, runtimeHost: runtimeHost)
  }
}
