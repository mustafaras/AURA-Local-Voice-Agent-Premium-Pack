import Foundation

/// Validates a *resolved* IP address against an allowlist before a connection
/// is made.
///
/// DNS answers are not trusted authority: a hostname may resolve to an
/// unexpected address (DNS rebinding, a poisoned cache, or a provider that
/// returns different addresses per request), so a client that needs IP
/// pinning must validate the resolved address, not just the hostname. This is
/// the deterministic, testable primitive; a caller resolves the hostname and
/// then rejects the connection unless every candidate IP passes.
///
/// This is deliberately a value type with no network dependency: the resolver
/// seam lives at the caller, so tests can exercise the allowlist decision
/// without opening a socket.
public struct ResolvedIPValidator: Sendable, Equatable {
  public let allowedIPs: Set<String>

  public init(allowedIPs: Set<String>) {
    self.allowedIPs = allowedIPs
  }

  /// True only when `ip` exactly matches an allowlisted address (after
  /// normalization). Empty allowlist denies everything.
  public func isAllowed(ip: String) -> Bool {
    let normalized = Self.normalize(ip)
    guard !normalized.isEmpty else { return false }
    return allowedIPs.contains(normalized)
  }

  /// True only when every candidate IP in `resolvedIPs` is allowlisted.
  /// A single unexpected address fails the whole set, so a hostname that
  /// resolves to a mix of trusted and untrusted addresses is rejected.
  public func allAllowed(resolvedIPs: [String]) -> Bool {
    guard !resolvedIPs.isEmpty else { return false }
    return resolvedIPs.allSatisfy { isAllowed(ip: $0) }
  }

  private static func normalize(_ ip: String) -> String {
    var value = ip.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    // Strip IPv6 zone identifiers (e.g. "fe80::1%en0" -> "fe80::1").
    if let zoneIndex = value.firstIndex(of: "%") {
      value = String(value[..<zoneIndex])
    }
    return value
  }
}
