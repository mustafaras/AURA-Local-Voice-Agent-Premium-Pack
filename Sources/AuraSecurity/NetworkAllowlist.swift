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
    let normalizedHost = Self.normalizeHost(host)
    guard !normalizedHost.isEmpty else { return false }
    for entry in allowedHosts {
      let normalizedEntry = Self.normalizeHost(entry)
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

  private static func normalizeHost(_ host: String) -> String {
    var value = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if value.hasPrefix("[") && value.hasSuffix("]") {
      value = String(value.dropFirst().dropLast())
    }
    while value.hasSuffix(".") { value.removeLast() }
    return value
  }
}

/// A complete endpoint policy used at the transport boundary. Host-only
/// checks are insufficient: a client must bind scheme, effective port, and
/// path as well, and a redirect must pass the same policy again. DNS answers
/// are intentionally not treated as trusted authority; callers that need
/// DNS/IP pinning must add a resolver with an explicit evidence record.
public struct NetworkEndpointPolicy: Sendable, Equatable {
  public let allowlist: NetworkAllowlist
  public let allowedSchemes: Set<String>
  public let allowedPorts: Set<Int>
  public let allowedPathPrefixes: Set<String>
  public let maximumResponseBytes: Int

  public init(
    allowlist: NetworkAllowlist,
    allowedSchemes: Set<String> = ["https"],
    allowedPorts: Set<Int> = [],
    allowedPathPrefixes: Set<String> = [],
    maximumResponseBytes: Int = 10 * 1024 * 1024
  ) {
    self.allowlist = allowlist
    self.allowedSchemes = Set(allowedSchemes.map { $0.lowercased() })
    self.allowedPorts = allowedPorts
    self.allowedPathPrefixes = allowedPathPrefixes
    self.maximumResponseBytes = maximumResponseBytes
  }

  public func validate(_ url: URL, isRedirect: Bool = false) throws(AuraError) {
    guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else {
      throw .securityError("network scheme is not allowed")
    }
    guard url.user == nil, url.password == nil else {
      throw .securityError("network URL userinfo is not allowed")
    }
    guard let host = url.host, allowlist.isAllowed(host: host) else {
      throw .securityError(
        isRedirect ? "network redirect host is not allowed" : "network host is not allowed")
    }
    if !allowedPorts.isEmpty {
      let effectivePort = url.port ?? (scheme == "https" ? 443 : 80)
      guard allowedPorts.contains(effectivePort) else {
        throw .securityError("network port is not allowed")
      }
    }
    if !allowedPathPrefixes.isEmpty {
      let path = url.path.isEmpty ? "/" : url.path
      guard allowedPathPrefixes.contains(where: { path.hasPrefix($0) }) else {
        throw .securityError("network path is not allowed")
      }
    }
  }
}
