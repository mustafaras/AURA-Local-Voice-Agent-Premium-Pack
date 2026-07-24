import AppKit
import AuraCore
import Foundation

/// Protocol for application lifecycle control to enable deterministic tests.
public protocol ApplicationControlling: Sendable {
  func runningApplications() -> [NativeApplicationDescriptor]
  func launchApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  func activateApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  func hideApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  func quitApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
}

extension ApplicationControlling {
  public nonisolated func runningApplications() -> [NativeApplicationDescriptor] {
    []
  }
}

/// A lightweight, serializable description of a running application.
public struct NativeApplicationDescriptor: Codable, Sendable, Equatable {
  public let bundleIdentifier: String
  public let name: String
  public let processID: Int32
  public let isActive: Bool
  public let isHidden: Bool

  public init(
    bundleIdentifier: String,
    name: String,
    processID: Int32,
    isActive: Bool,
    isHidden: Bool
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.name = name
    self.processID = processID
    self.isActive = isActive
    self.isHidden = isHidden
  }
}

/// Production controller using NSWorkspace and AppKit.
public actor ApplicationController: ApplicationControlling {
  private let workspace = NSWorkspace.shared
  private let logger: AuraLogger

  public init(logger: AuraLogger = AuraLogger(subsystem: "AuraAutomation", category: "app")) {
    self.logger = logger
  }

  nonisolated public func runningApplications() -> [NativeApplicationDescriptor] {
    NSWorkspace.shared.runningApplications.map { app in
      NativeApplicationDescriptor(
        bundleIdentifier: app.bundleIdentifier ?? "",
        name: app.localizedName ?? "",
        processID: app.processIdentifier,
        isActive: app.isActive,
        isHidden: app.isHidden
      )
    }
  }

  public func launchApplication(
    bundleIdentifier: String,
    timeout: TimeInterval
  ) async throws(AuraError) -> NativeApplicationDescriptor {
    guard !bundleIdentifier.isEmpty else {
      throw AuraError.automationError("bundleIdentifier must not be empty")
    }
    let start = Date()
    guard
      let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
    else {
      throw AuraError.automationError("Application not found: \(bundleIdentifier)")
    }
    do {
      let configuration = NSWorkspace.OpenConfiguration()
      _ = try await workspace.openApplication(
        at: url,
        configuration: configuration
      )
      let descriptor = try await waitForApplication(
        bundleIdentifier: bundleIdentifier,
        timeout: max(0, timeout - Date().timeIntervalSince(start)),
        mustBeRunning: true
      )
      await logger.info("Launched \(bundleIdentifier)")
      return descriptor
    } catch {
      throw AuraError.automationError("Launch failed: \(error.localizedDescription)")
    }
  }

  public func activateApplication(
    bundleIdentifier: String,
    timeout: TimeInterval
  ) async throws(AuraError) -> NativeApplicationDescriptor {
    let app = try await locateApplication(bundleIdentifier: bundleIdentifier, timeout: timeout)
    guard let runningApp = app.runningApplication else {
      throw AuraError.automationError("Application is not running: \(bundleIdentifier)")
    }
    _ = await MainActor.run { [runningApp] () -> Bool in
      if #available(macOS 14.0, *) {
        runningApp.activate(options: [.activateAllWindows])
      } else {
        runningApp.activate(options: [.activateIgnoringOtherApps])
      }
      return runningApp.isActive
    }
    return app.descriptor
  }

  public func hideApplication(
    bundleIdentifier: String,
    timeout: TimeInterval
  ) async throws(AuraError) -> NativeApplicationDescriptor {
    let app = try await locateApplication(bundleIdentifier: bundleIdentifier, timeout: timeout)
    guard let runningApp = app.runningApplication else {
      throw AuraError.automationError("Application is not running: \(bundleIdentifier)")
    }
    _ = await MainActor.run { [runningApp] () -> Bool in
      runningApp.hide()
      return runningApp.isHidden
    }
    return app.descriptor
  }

  public func quitApplication(
    bundleIdentifier: String,
    timeout: TimeInterval
  ) async throws(AuraError) -> NativeApplicationDescriptor {
    let app = try await locateApplication(bundleIdentifier: bundleIdentifier, timeout: timeout)
    guard let runningApp = app.runningApplication else {
      throw AuraError.automationError("Application is not running: \(bundleIdentifier)")
    }
    _ = await MainActor.run { [runningApp] () -> Bool in
      runningApp.terminate()
      return runningApp.isTerminated
    }
    _ = try? await waitForApplication(
      bundleIdentifier: bundleIdentifier,
      timeout: timeout,
      mustBeRunning: false
    )
    return app.descriptor
  }

  private func locateApplication(
    bundleIdentifier: String,
    timeout: TimeInterval
  ) async throws(AuraError) -> (
    descriptor: NativeApplicationDescriptor, runningApplication: NSRunningApplication?
  ) {
    guard !bundleIdentifier.isEmpty else {
      throw AuraError.automationError("bundleIdentifier must not be empty")
    }
    let descriptor = try await waitForApplication(
      bundleIdentifier: bundleIdentifier,
      timeout: timeout,
      mustBeRunning: true
    )
    let runningApp = workspace.runningApplications.first {
      $0.bundleIdentifier == bundleIdentifier
    }
    return (descriptor, runningApp)
  }

  private func waitForApplication(
    bundleIdentifier: String,
    timeout: TimeInterval,
    mustBeRunning: Bool
  ) async throws(AuraError) -> NativeApplicationDescriptor {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      let apps = runningApplications()
      let match = apps.first { $0.bundleIdentifier == bundleIdentifier }
      if mustBeRunning, let match {
        return match
      }
      if !mustBeRunning, match == nil {
        return NativeApplicationDescriptor(
          bundleIdentifier: bundleIdentifier,
          name: "",
          processID: 0,
          isActive: false,
          isHidden: false
        )
      }
      try? await Task.sleep(nanoseconds: 50_000_000)  // 50 ms
    }
    if mustBeRunning {
      throw AuraError.automationError(
        "Timeout waiting for \(bundleIdentifier) to be running")
    }
    return NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier,
      name: "",
      processID: 0,
      isActive: false,
      isHidden: false
    )
  }
}

extension NSRunningApplication {
  fileprivate var descriptor: NativeApplicationDescriptor {
    NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier ?? "",
      name: localizedName ?? "",
      processID: processIdentifier,
      isActive: isActive,
      isHidden: isHidden
    )
  }
}
