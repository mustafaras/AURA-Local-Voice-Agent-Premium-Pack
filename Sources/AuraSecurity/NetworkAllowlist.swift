import AuraCore
import Foundation

/// Deny-by-default outbound-network host allowlist.
///
/// `OllamaConfiguration.allowedLoopbackHosts` already governs the one real
/// outbound network call site in the codebase today (`URLSessionOllama
/// APIClient`) with a *stronger* guarantee — a loopback-only host-family
/// restriction, not a domain list, since Ollama must never be pointed at a
/// remote address at all. `NetworkAllowlist` is the general-purpose primitive
/// for any future capability that legitimately needs non-loopback network
/// access (e.g. a plugin's declared `networkDomains`, or a future cloud
/// adapter): empty allowlist denies everything, and a leading `*.` matches
/// exactly one level of subdomain plus the bare domain itself.
public struct NetworkAllowlist: Sendable, Equatable {
  public let allowedHosts: Set<String>

  public init(allowedHosts: Set<String>) {
    self.allowedHosts = allowedHosts
  }

  public init(configuration: SecurityConfiguration) {
    self.allowedHosts = configuration.networkAllowlist
  }

  /// True only when `host` exactly matches an entry, or matches a `*.`
  /// wildcard entry's domain or one of its subdomains.
  public func isAllowed(host: String) -> Bool {
    let normalizedHost = host.lowercased()
    for entry in allowedHosts {
      let normalizedEntry = entry.lowercased()
      if normalizedEntry.hasPrefix("*.") {
        let suffix = String(normalizedEntry.dropFirst())  // ".example.com"
        let bareDomain = String(normalizedEntry.dropFirst(2))  // "example.com"
        if normalizedHost == bareDomain || normalizedHost.hasSuffix(suffix) {
          return true
        }
      } else if normalizedHost == normalizedEntry {
        return true
      }
    }
    return false
  }
}
