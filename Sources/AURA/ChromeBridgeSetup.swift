import AppKit
import Foundation

/// Relaunches Chrome with AURA's bundled extension for first-run setup or recovery.
enum ChromeBridgeSetup {
  static func launchArguments() -> [String] {
    ["chrome-extension://\(ChromeBridgeInstaller.extensionID)/bootstrap.html"]
  }

  @MainActor
  static func relaunchChromeForBridge() async throws {
    guard let chromeURL = NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: "com.google.Chrome")
    else {
      throw NSError(
        domain: "AURA.ChromeBridgeSetup", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Google Chrome is missing"])
    }
    // Restart Chrome so the installed extension reloads its bundled source
    // before the extension-owned bootstrap page requests an empty handshake.
    let running = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.google.Chrome")
    for application in running {
      _ = application.terminate()
    }
    for _ in 0..<20 {
      guard running.contains(where: { !$0.isTerminated }) else { break }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    guard running.allSatisfy(\.isTerminated) else {
      throw NSError(
        domain: "AURA.ChromeBridgeSetup", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Google Chrome could not be restarted"])
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.arguments = launchArguments()
    _ = try await NSWorkspace.shared.openApplication(
      at: chromeURL, configuration: configuration)
  }
}
