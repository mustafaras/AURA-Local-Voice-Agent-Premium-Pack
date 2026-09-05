import Foundation
import AuraCore

/// Installs AURA's bundled Chrome native messaging host and manifest into the
/// current user's Application Support directory.
///
/// The app bundle ships both the host executable and the unpacked extension.
/// On every launch this installer atomically refreshes the host copy and its
/// Chrome manifest, making the integration self-healing after app upgrades.
/// It never modifies Chrome's profile or enables an extension silently; the
/// user loads the bundled extension once through Chrome's Developer mode.
enum ChromeBridgeInstaller {
  static let hostName = "ai.aura.local.agent"
  static let extensionID = "ggccnafnholmbpghgljfbofapcbhkdjh"

  static func install(
    bundle: Bundle = .main,
    fileManager: FileManager = .default,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    productivity: ProductivityConfiguration = ProductivityConfiguration()
  ) throws {
    let auxiliaryHost = bundle.url(forAuxiliaryExecutable: "AuraChromeNativeHost")
    let directHost = bundle.bundleURL
      .appending(path: "Contents/Helpers/AuraChromeNativeHost")
    let bundledHost = auxiliaryHost
      ?? (fileManager.fileExists(atPath: directHost.path) ? directHost : nil)
    guard let bundledHost,
      let bundledExtension = bundle.resourceURL?
        .appending(path: "ChromeExtension", directoryHint: .isDirectory),
      fileManager.fileExists(atPath: bundledExtension.path)
    else {
      throw NSError(
        domain: "AURA.ChromeBridgeInstaller", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Chrome bridge is not bundled"])
    }

    try install(
      bundledHost: bundledHost,
      bundledExtension: bundledExtension,
      fileManager: fileManager,
      homeDirectory: homeDirectory,
      productivity: productivity)
  }

  static func install(
    bundledHost: URL,
    bundledExtension: URL,
    fileManager: FileManager = .default,
    homeDirectory: URL,
    productivity: ProductivityConfiguration = ProductivityConfiguration()
  ) throws {
    guard fileManager.fileExists(atPath: bundledHost.path),
      fileManager.fileExists(atPath: bundledExtension.path)
    else {
      throw NSError(
        domain: "AURA.ChromeBridgeInstaller", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Chrome bridge is not bundled"])
    }

    let auraDirectory = homeDirectory
      .appending(path: "Library/Application Support/AURA/ChromeNativeHost")
    let installedHost = auraDirectory.appending(path: "AuraChromeNativeHost")
    let hostConfigurationURL = auraDirectory.appending(path: "host-config.json")
    let manifestDirectory = homeDirectory.appending(
      path: "Library/Application Support/Google/Chrome/NativeMessagingHosts")
    let manifestURL = manifestDirectory.appending(path: "\(hostName).json")

    try fileManager.createDirectory(
      at: auraDirectory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    try fileManager.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: auraDirectory.path)
    try fileManager.createDirectory(
      at: manifestDirectory, withIntermediateDirectories: true)

    let temporaryHost = auraDirectory.appending(path: ".AuraChromeNativeHost.new")
    if fileManager.fileExists(atPath: temporaryHost.path) {
      try fileManager.removeItem(at: temporaryHost)
    }
    try fileManager.copyItem(at: bundledHost, to: temporaryHost)
    try fileManager.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: temporaryHost.path)
    if fileManager.fileExists(atPath: installedHost.path) {
      _ = try fileManager.replaceItemAt(installedHost, withItemAt: temporaryHost)
    } else {
      try fileManager.moveItem(at: temporaryHost, to: installedHost)
    }
    try fileManager.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: installedHost.path)

    let resolvedContainer = productivity.safariSharedContainerPath.isEmpty
      ? ProductivityConfiguration.defaultSafariSharedContainerPath(
        homeDirectory: homeDirectory.path)
      : productivity.safariSharedContainerPath
    let hostConfiguration: [String: String] = [
      "extensionID": "com.aura.safari-extension",
      "profileID": "personal",
      "sharedContainerPath": resolvedContainer,
      "extensionPath": bundledExtension.path,
    ]
    let hostConfigurationData = try JSONSerialization.data(
      withJSONObject: hostConfiguration, options: [.prettyPrinted, .sortedKeys])
    try hostConfigurationData.write(to: hostConfigurationURL, options: .atomic)
    try fileManager.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: hostConfigurationURL.path)

    let manifest: [String: Any] = [
      "name": hostName,
      "description": "AURA read-only browser bridge native messaging host",
      "path": installedHost.path,
      "type": "stdio",
      "allowed_origins": ["chrome-extension://\(extensionID)/"],
    ]
    let data = try JSONSerialization.data(
      withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: manifestURL, options: .atomic)
    try fileManager.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: manifestURL.path)
  }
}
