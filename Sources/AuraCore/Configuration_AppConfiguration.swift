import Foundation

public struct AppConfiguration: Codable, Sendable, Equatable {
  public var bundleIdentifier: String
  public var serviceName: String

  public init(
    bundleIdentifier: String = "ai.aura.local",
    serviceName: String = "AuraCore"
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.serviceName = serviceName
  }

  /// ADR-065 §2 (PA-1): the Keychain namespace a running process may use.
  /// Only code signed by the stable local identity gets the configured
  /// production `serviceName`; every other identity (debug builds, test
  /// hosts, ad-hoc bundles) gets `<serviceName>.dev`, so a foreign identity
  /// never reads or re-ACLs the installed app's items and macOS never raises
  /// the Keychain password dialog for it. Pure so it is unit-testable; the
  /// composition root supplies `isStableIdentity` from `CodeIdentityProbe`.
  public static let developmentNamespaceSuffix = ".dev"

  public static func effectiveServiceName(
    _ configured: String, isStableIdentity: Bool
  ) -> String {
    isStableIdentity ? configured : configured + developmentNamespaceSuffix
  }

  public func effectiveServiceName(isStableIdentity: Bool) -> String {
    Self.effectiveServiceName(serviceName, isStableIdentity: isStableIdentity)
  }

  public func validate() throws(AuraError) {
    guard !bundleIdentifier.isEmpty else {
      throw AuraError.invalidConfiguration("bundleIdentifier must not be empty")
    }
    guard !serviceName.isEmpty else {
      throw AuraError.invalidConfiguration("serviceName must not be empty")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    bundleIdentifier =
      try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) ?? "ai.aura.local"
    serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName) ?? "AuraCore"
  }
}
