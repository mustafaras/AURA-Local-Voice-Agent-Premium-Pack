import AuraCore
import CryptoKit
import Foundation

/// Versioned, local-only storage for already verified plugin payloads.
public actor PluginArtifactStore {
  public nonisolated let rootDirectory: URL
  private let fileManager: FileManager

  public init(rootDirectory: URL, fileManager: FileManager = .default) throws(AuraError) {
    self.fileManager = fileManager
    do {
      try fileManager.createDirectory(
        at: rootDirectory.standardizedFileURL, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
    } catch {
      throw AuraError.pluginError(
        "unable to create plugin artifact root: \(error.localizedDescription)")
    }
    self.rootDirectory = rootDirectory.standardizedFileURL.resolvingSymlinksInPath()
  }

  public func install(manifest: PluginManifest, payload: Data) throws(AuraError) -> String {
    try manifest.validate()
    let actual = Self.sha256Hex(payload)
    guard actual == manifest.contentHashSHA256Hex else {
      throw AuraError.pluginError("refusing to store plugin payload with mismatched hash")
    }
    let versionDirectory =
      rootDirectory
      .appendingPathComponent(manifest.id, isDirectory: true)
      .appendingPathComponent(manifest.version, isDirectory: true)
    let artifactURL = versionDirectory.appendingPathComponent("payload", isDirectory: false)
    do {
      try fileManager.createDirectory(
        at: versionDirectory, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      let resolvedVersion = versionDirectory.resolvingSymlinksInPath()
      guard resolvedVersion.path.hasPrefix(rootDirectory.path + "/") else {
        throw AuraError.pluginError("plugin artifact directory escaped configured root")
      }
      try payload.write(to: artifactURL, options: [.atomic])
      try fileManager.setAttributes([.posixPermissions: 0o500], ofItemAtPath: artifactURL.path)
    } catch {
      try? fileManager.removeItem(at: versionDirectory)
      throw AuraError.pluginError(
        "unable to install plugin artifact: \(error.localizedDescription)")
    }
    return relativePath(for: artifactURL)
  }

  public func verifiedArtifact(
    relativePath: String, expectedSHA256Hex: String
  ) throws(AuraError) -> URL {
    let url = try resolve(relativePath)
    guard fileManager.fileExists(atPath: url.path),
      let data = try? Data(contentsOf: url),
      Self.sha256Hex(data) == expectedSHA256Hex
    else {
      throw AuraError.pluginError("plugin artifact is missing or tampered")
    }
    return url
  }

  public func removeAll(pluginID: String) throws(AuraError) {
    let directory = rootDirectory.appendingPathComponent(pluginID, isDirectory: true)
      .standardizedFileURL
    guard directory.path.hasPrefix(rootDirectory.path + "/") else {
      throw AuraError.pluginError("refusing unsafe plugin artifact removal")
    }
    guard fileManager.fileExists(atPath: directory.path) else { return }
    do {
      try fileManager.removeItem(at: directory)
    } catch {
      throw AuraError.pluginError(
        "unable to remove plugin artifacts: \(error.localizedDescription)")
    }
  }

  public func removeVersion(pluginID: String, version: String) throws(AuraError) {
    let directory =
      rootDirectory
      .appendingPathComponent(pluginID, isDirectory: true)
      .appendingPathComponent(version, isDirectory: true)
      .standardizedFileURL
    guard directory.path.hasPrefix(rootDirectory.path + "/") else {
      throw AuraError.pluginError("refusing unsafe plugin version removal")
    }
    guard fileManager.fileExists(atPath: directory.path) else { return }
    do {
      try fileManager.removeItem(at: directory)
    } catch {
      throw AuraError.pluginError(
        "unable to remove plugin version: \(error.localizedDescription)")
    }
  }

  public func artifactExists(relativePath: String) -> Bool {
    guard let url = try? resolve(relativePath) else { return false }
    return fileManager.fileExists(atPath: url.path)
  }

  private func resolve(_ relativePath: String) throws(AuraError) -> URL {
    guard !relativePath.hasPrefix("/"), !relativePath.contains("..") else {
      throw AuraError.pluginError("invalid plugin artifact path")
    }
    let url = rootDirectory.appendingPathComponent(relativePath).standardizedFileURL
      .resolvingSymlinksInPath()
    guard url.path.hasPrefix(rootDirectory.path + "/") else {
      throw AuraError.pluginError("plugin artifact escaped configured root")
    }
    return url
  }

  private func relativePath(for url: URL) -> String {
    String(url.path.dropFirst(rootDirectory.path.count + 1))
  }

  public static func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
