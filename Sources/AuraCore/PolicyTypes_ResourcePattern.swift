import CryptoKit
import Foundation

// MARK: - Resource patterns

/// Scope primitive for grants and deny rules.
///
/// Patterns are evaluated in order; a request matches a grant if at least one
/// pattern matches every constrained dimension of the request.
public enum ResourcePattern: Codable, Sendable, Equatable, Hashable {
  /// Matches any target. Use sparingly and only for low-risk capabilities.
  case any

  /// Matches a specific application bundle identifier.
  case appID(String)

  /// Matches a file path using a shell-style glob.
  case filePath(glob: String)

  /// Matches files under a directory path.
  case directory(String, recursive: Bool)

  /// Matches a shell command by regular expression.
  case command(regex: String)

  /// Requires the command arguments to be a subset of the allowed list.
  case argument(allowed: [String])

  /// Requires environment keys to be a subset of the allowed list.
  case environment(keys: [String])

  /// Matches a network host and optional port range.
  case network(host: String, port: ClosedRange<Int>)

  /// Requires the target's URL scheme to be one of `allowed`, compared
  /// case-insensitively. Added by SP-006's closeout so `url.open` can be
  /// narrowed at the policy layer instead of relying solely on the adapter's
  /// scheme allowlist: a URL with no scheme, or with a scheme outside the
  /// list, no longer matches the grant at all. `.network(host:port:)` cannot
  /// express this — a `mailto:` URL has no host, so host-scoping would refuse
  /// legitimate mail links while still permitting, say, `file:` or `ftp:`.
  case urlScheme(allowed: [String])
}
