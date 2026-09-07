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
  /// ADR-055 (2026-09-07): the release owner directed that computer use be
  /// permitted for **all** applications ("olabilecek olan tüm uygulamalara
  /// izin verilsin"). When `allowsAllApplications` is true the per-app list
  /// is no longer the structural gate — every bundle identifier is approved,
  /// and the remaining controls are the policy confirmation challenge, the
  /// control loop's own verify/no-progress/destructive-action guards, and
  /// the screen-context sensitive-app exclusion.
  private let allowsAllApplications: Bool

  public init(
    apps: [ComputerUseBetaApp] = [],
    allowsAllApplications: Bool = false
  ) {
    self.apps = Dictionary(uniqueKeysWithValues: apps.map { ($0.appBundleIdentifier, $0) })
    self.allowsAllApplications = allowsAllApplications
  }

  public func app(for bundleIdentifier: String) -> ComputerUseBetaApp? {
    apps[bundleIdentifier]
  }

  public func isApproved(_ bundleIdentifier: String) -> Bool {
    if allowsAllApplications { return true }
    return apps[bundleIdentifier]?.isUsable ?? false
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

  /// The allowlist production runs with under ADR-055 (2026-09-07): the
  /// release owner directed that computer use be permitted for **all**
  /// applications. `allowsAllApplications` makes every bundle identifier
  /// approved; the enumerated `initial` apps are retained so their names
  /// still resolve for diagnostics, and `liveValidatedProduction` remains
  /// the record of which apps carry real live evidence
  /// (`EV-SP-007-20260816-LIVE-02`). The structural per-app gate is lifted;
  /// the controls that remain are the policy confirmation challenge, the
  /// control loop's own verify/no-progress/destructive-action guards, and
  /// the screen-context sensitive-app exclusion.
  public static let ownerOpenApplications: ComputerUseBetaAllowlist =
    ComputerUseBetaAllowlist(
      apps: Array(initial.apps.values),
      allowsAllApplications: true)
}
