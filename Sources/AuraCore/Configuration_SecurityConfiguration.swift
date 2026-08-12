import Foundation

/// Configuration for `AuraSecurity` (Phase 19) — the Keychain-backed secret
/// store, the deterministic prompt-injection classifier, and the outbound
/// network domain allowlist. `Ollama`'s own network egress is governed
/// separately and more strictly by `OllamaConfiguration.allowedLoopbackHosts`
/// (a host-family restriction, not a domain list); `networkAllowlist` here
/// is for any future non-loopback network capability.
public struct SecurityConfiguration: Codable, Sendable, Equatable {
  /// Keychain service name secrets are stored under. Namespaced by the app
  /// bundle identifier so a Keychain search never leaks across apps.
  public var secretKeychainServiceName: String

  /// Host allowlist for outbound network requests evaluated through
  /// `NetworkAllowlist`. Deny-by-default: empty means no host is allowed.
  /// A leading `*.` matches any subdomain (e.g. `*.githubusercontent.com`).
  public var networkAllowlist: Set<String>

  /// Whether `PromptInjectionClassifier` is consulted at all. `false` only
  /// for narrow diagnostic scenarios; production defaults to `true`.
  public var injectionClassifierEnabled: Bool

  /// Cumulative matched-rule severity at or above which a classification is
  /// `.blocked` rather than merely `.suspicious`.
  public var injectionBlockSeverityThreshold: Int

  public init(
    secretKeychainServiceName: String = "ai.aura.local.secrets",
    networkAllowlist: Set<String> = [],
    injectionClassifierEnabled: Bool = true,
    injectionBlockSeverityThreshold: Int = 3
  ) {
    self.secretKeychainServiceName = secretKeychainServiceName
    self.networkAllowlist = networkAllowlist
    self.injectionClassifierEnabled = injectionClassifierEnabled
    self.injectionBlockSeverityThreshold = injectionBlockSeverityThreshold
  }

  public func validate() throws(AuraError) {
    guard !secretKeychainServiceName.isEmpty else {
      throw AuraError.invalidConfiguration("security secretKeychainServiceName must not be empty")
    }
    guard injectionBlockSeverityThreshold > 0 else {
      throw AuraError.invalidConfiguration(
        "security injectionBlockSeverityThreshold must be positive")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> SecurityConfiguration {
    SecurityConfiguration(
      secretKeychainServiceName: self.secretKeychainServiceName.isEmpty
        ? SecurityConfiguration().secretKeychainServiceName
        : self.secretKeychainServiceName,
      networkAllowlist: self.networkAllowlist,
      injectionClassifierEnabled: self.injectionClassifierEnabled,
      injectionBlockSeverityThreshold: self.injectionBlockSeverityThreshold <= 0
        ? SecurityConfiguration().injectionBlockSeverityThreshold
        : self.injectionBlockSeverityThreshold
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = SecurityConfiguration()
    secretKeychainServiceName =
      try container.decodeIfPresent(String.self, forKey: .secretKeychainServiceName)
      ?? defaults.secretKeychainServiceName
    networkAllowlist =
      try container.decodeIfPresent(Set<String>.self, forKey: .networkAllowlist)
      ?? defaults.networkAllowlist
    injectionClassifierEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .injectionClassifierEnabled)
      ?? defaults.injectionClassifierEnabled
    injectionBlockSeverityThreshold =
      try container.decodeIfPresent(Int.self, forKey: .injectionBlockSeverityThreshold)
      ?? defaults.injectionBlockSeverityThreshold
  }
}
