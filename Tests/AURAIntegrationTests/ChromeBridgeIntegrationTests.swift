import Foundation
import CryptoKit
import Testing
import AuraCore

@testable import AURA

@Suite("Chrome bridge packaging and installation")
struct ChromeBridgeIntegrationTests {
  @Test("Chrome opens the installed extension bootstrap without a rejected load flag")
  func chromeOpensInstalledExtensionBootstrap() {
    let arguments = ChromeBridgeSetup.launchArguments()

    #expect(arguments == [
      "chrome-extension://ggccnafnholmbpghgljfbofapcbhkdjh/bootstrap.html",
    ])
    #expect(arguments.contains(where: { $0.hasPrefix("--load-extension=") }) == false)
  }

  @Test("native host approved hashes match packaged extension sources")
  func nativeHostApprovedHashesMatchExtensionSources() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let hostSource = try String(
      contentsOf: repoRoot.appending(path: "Sources/AuraChromeNativeHost/main.swift"),
      encoding: .utf8)

    #expect(hostSource.contains("parent-launch-path") == false)

    let expectedFilenames = [
      "README.md", "manifest.json", "background.js", "bootstrap.html", "bootstrap.js",
      "bootstrap.css",
    ]
    let extensionDirectory = repoRoot.appending(path: "Resources/ChromeExtension")
    let packagedFilenames = try FileManager.default.contentsOfDirectory(
      at: extensionDirectory,
      includingPropertiesForKeys: nil,
      options: []).map(\.lastPathComponent)
    #expect(Set(packagedFilenames) == Set(expectedFilenames))

    for filename in expectedFilenames {
      let data = try Data(
        contentsOf: extensionDirectory.appending(path: filename))
      let digest = SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
      #expect(hostSource.contains("\"\(filename)\": \"\(digest)\""))
    }
  }

  @Test("installer copies the host and writes Chrome's exact allowed origin")
  func installerWritesNativeMessagingManifest() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: "aura-chrome-bridge-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let host = root.appending(path: "BundledAuraChromeNativeHost")
    try Data("host".utf8).write(to: host)
    let chromeExtension = root.appending(path: "ChromeExtension", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
      at: chromeExtension, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: chromeExtension.appending(path: "manifest.json"))
    let home = root.appending(path: "home", directoryHint: .isDirectory)
    let preexistingHostDirectory = home.appending(
      path: "Library/Application Support/AURA/ChromeNativeHost")
    try FileManager.default.createDirectory(
      at: preexistingHostDirectory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o755])

    let productivity = ProductivityConfiguration(
      safariProfileID: "work",
      safariExtensionID: "com.aura.chrome-extension",
      safariSharedContainerPath: home.appending(path: "custom/observation.json").path)
    try ChromeBridgeInstaller.install(
      bundledHost: host,
      bundledExtension: chromeExtension,
      homeDirectory: home,
      productivity: productivity)

    let installedHost = home.appending(
      path: "Library/Application Support/AURA/ChromeNativeHost/AuraChromeNativeHost")
    #expect(try Data(contentsOf: installedHost) == Data("host".utf8))

    let manifestURL = home.appending(
      path:
        "Library/Application Support/Google/Chrome/NativeMessagingHosts/"
          + "ai.aura.local.agent.json")
    let manifest = try JSONSerialization.jsonObject(
      with: Data(contentsOf: manifestURL)) as? [String: Any]
    #expect(manifest?["name"] as? String == ChromeBridgeInstaller.hostName)
    #expect(manifest?["path"] as? String == installedHost.path)
    #expect(
      manifest?["allowed_origins"] as? [String]
        == ["chrome-extension://\(ChromeBridgeInstaller.extensionID)/"])

    let hostConfigurationURL = home.appending(
      path: "Library/Application Support/AURA/ChromeNativeHost/host-config.json")
    let hostConfiguration = try JSONSerialization.jsonObject(
      with: Data(contentsOf: hostConfigurationURL)) as? [String: String]
    #expect(hostConfiguration?["extensionID"] == "com.aura.safari-extension")
    #expect(hostConfiguration?["profileID"] == "personal")
    #expect(
      hostConfiguration?["sharedContainerPath"]
        == home.appending(path: "custom/observation.json").path)
    #expect(hostConfiguration?["extensionPath"] == chromeExtension.path)

    let hostAttributes = try FileManager.default.attributesOfItem(
      atPath: installedHost.path)
    let manifestAttributes = try FileManager.default.attributesOfItem(
      atPath: manifestURL.path)
    let configurationAttributes = try FileManager.default.attributesOfItem(
      atPath: hostConfigurationURL.path)
    let hostDirectoryAttributes = try FileManager.default.attributesOfItem(
      atPath: preexistingHostDirectory.path)
    #expect((hostAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
    #expect((manifestAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    #expect((configurationAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    #expect((hostDirectoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)

    // A second install must atomically replace the existing host rather than
    // deleting it first and leaving the manifest pointed at a missing file.
    try Data("host-v2".utf8).write(to: host)
    try ChromeBridgeInstaller.install(
      bundledHost: host,
      bundledExtension: chromeExtension,
      homeDirectory: home,
      productivity: productivity)
    #expect(try Data(contentsOf: installedHost) == Data("host-v2".utf8))
  }

  @Test("Chrome extension manifest has stable identity and read-only permissions")
  func extensionManifestIsStableAndBounded() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let manifestURL = repoRoot.appending(path: "Resources/ChromeExtension/manifest.json")
    let manifest = try JSONSerialization.jsonObject(
      with: Data(contentsOf: manifestURL)) as? [String: Any]

    #expect(manifest?["manifest_version"] as? Int == 3)
    #expect(manifest?["name"] as? String == "AURA Chrome Read Bridge")
    #expect(manifest?["version"] as? String == "1.0.1")
    #expect(manifest?["key"] as? String != nil)
    #expect(
      Set(manifest?["permissions"] as? [String] ?? [])
        == Set(["nativeMessaging", "activeTab", "scripting"]))
    #expect(manifest?["host_permissions"] == nil)

    let commands = manifest?["commands"] as? [String: Any]
    let executeAction = commands?["_execute_action"] as? [String: Any]
    let suggestedKey = executeAction?["suggested_key"] as? [String: String]
    #expect(suggestedKey?["mac"] == "Command+Shift+Y")
  }
}
