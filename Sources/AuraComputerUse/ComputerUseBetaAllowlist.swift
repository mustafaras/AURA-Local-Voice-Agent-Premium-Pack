import Foundation

/// One approved beta application and its validation state. An entry is
/// `.liveValidated` only after app-specific fixtures and live validation
/// pass (R4 section C); until then it is `.disabled` and unreachable by a
/// production planner.
public struct ComputerUseBetaApp: Sendable, Equatable {
  public let appBundleIdentifier: String
  public let appName: String?
  public let validationState: ComputerUseBetaValidationState

  public init(
    appBundleIdentifier: String,
    appName: String? = nil,
    validationState: ComputerUseBetaValidationState
  ) {
    self.appBundleIdentifier = appBundleIdentifier
    self.appName = appName
    self.validationState = validationState
  }

  public var isUsable: Bool { validationState == .liveValidated }
}

/// Whether a beta app has passed live validation. Only `.liveValidated`
/// makes it reachable; anything else is structurally disabled.
public enum ComputerUseBetaValidationState: String, Sendable, Equatable, CaseIterable {
  case disabled
  case liveValidated
}

/// The R4 beta allowlist. Closed by default: an application is reachable by
/// a production planner only if it is present AND `.liveValidated`.
/// This makes "remains disabled for unvalidated apps" a structural property,
/// not a caller convention.
public struct ComputerUseBetaAllowlist: Sendable, Equatable {
  private let apps: [String: ComputerUseBetaApp]

  public init(apps: [ComputerUseBetaApp] = []) {
    self.apps = Dictionary(uniqueKeysWithValues: apps.map { ($0.appBundleIdentifier, $0) })
  }

  public func app(for bundleIdentifier: String) -> ComputerUseBetaApp? {
    apps[bundleIdentifier]
  }

  public func isApproved(_ bundleIdentifier: String) -> Bool {
    apps[bundleIdentifier]?.isUsable ?? false
  }

  public var usableBundleIdentifiers: [String] {
    apps.values.filter(\.isUsable).map(\.appBundleIdentifier).sorted()
  }

  /// Returns a copy with the given app marked `.liveValidated` (the only way
  /// to open an entry, and only ever done after real validation evidence).
  public func validating(_ bundleIdentifier: String, appName: String? = nil)
    -> ComputerUseBetaAllowlist
  {
    var updated = apps
    let current = apps[bundleIdentifier]
    updated[bundleIdentifier] = ComputerUseBetaApp(
      appBundleIdentifier: bundleIdentifier,
      appName: appName ?? current?.appName,
      validationState: .liveValidated)
    return ComputerUseBetaAllowlist(apps: Array(updated.values))
  }

  /// The prompt's deliberately small starting set. All entries start
  /// `.disabled`; each is opened only by explicit `.validating(...)` after
  /// live fixtures pass.
  public static let initial: ComputerUseBetaAllowlist = ComputerUseBetaAllowlist(apps: [
    ComputerUseBetaApp(
      appBundleIdentifier: "com.apple.finder", appName: "Finder", validationState: .disabled),
    ComputerUseBetaApp(
      appBundleIdentifier: "com.apple.Safari", appName: "Safari", validationState: .disabled),
    ComputerUseBetaApp(
      appBundleIdentifier: "com.microsoft.VSCode", appName: "VS Code", validationState: .disabled),
    ComputerUseBetaApp(
      appBundleIdentifier: "com.apple.Terminal", appName: "Terminal", validationState: .disabled),
    ComputerUseBetaApp(
      appBundleIdentifier: "com.apple.Notes", appName: "Notes", validationState: .disabled),
    ComputerUseBetaApp(
      appBundleIdentifier: "com.apple.iCal", appName: "Calendar", validationState: .disabled),
    ComputerUseBetaApp(
      appBundleIdentifier: "com.apple.mail", appName: "Mail", validationState: .disabled),
  ])

  /// The allowlist production actually runs with: `initial` opened for
  /// exactly the applications a live acceptance run directly validated.
  ///
  /// Finder, Terminal, and Notes were each exercised live under
  /// `EV-SP-007-20260816-LIVE-02` with one Accessibility-anchored action, one
  /// bounded coordinate fallback, and one confirmation-required action.
  /// Safari, VS Code, Calendar, and Mail have **no** live evidence and remain
  /// `.disabled`.
  ///
  /// Declared here rather than assembled at the kernel construction site so
  /// "only directly validated apps are reachable" is one auditable value a
  /// regression test can assert against, instead of a wiring detail that
  /// could drift open unnoticed. Add an entry only together with its
  /// evidence ID.
  public static let liveValidatedProduction: ComputerUseBetaAllowlist =
    initial
    .validating("com.apple.finder", appName: "Finder")
    .validating("com.apple.Terminal", appName: "Terminal")
    .validating("com.apple.Notes", appName: "Notes")
}
