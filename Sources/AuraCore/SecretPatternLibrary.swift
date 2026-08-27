import Foundation

/// One named, regex-expressed secret shape.
///
/// Named (not just a bare pattern string) so callers can report *which*
/// category of secret was detected without re-deriving it from the regex —
/// used by `SecretScanner` (`AuraSecurity`) to build typed `SecretMatch`
/// results instead of a bare boolean.
public struct SecretPatternDefinition: Sendable, Equatable {
  public let name: String
  public let pattern: String

  public init(name: String, pattern: String) {
    self.name = name
    self.pattern = pattern
  }
}

/// Canonical, single-source-of-truth list of secret-shaped regexes, used
/// everywhere a secret could otherwise leak: command output (`OutputRedactor
/// .default`), repository customization files (`RepositoryInstructionsScanner`
/// in `AuraAgent`), and pre-flight scanning of model prompts / events /
/// ledger entries (`SecretScanner` in `AuraSecurity`).
///
/// This consolidates what were previously two independently maintained,
/// overlapping-but-different pattern lists (`OutputRedactor.default` and
/// `RepositoryInstructionsScanner`'s private `secretDetector`) into one list,
/// so a new secret shape only needs to be added once. The merge is a strict
/// superset of both prior lists — no existing detection behavior narrows.
public enum SecretPatternLibrary {
  public static let all: [SecretPatternDefinition] = [
    SecretPatternDefinition(name: "hex40", pattern: "\\b[0-9a-fA-F]{40}\\b"),
    SecretPatternDefinition(name: "openaiStyleKey", pattern: "sk-[a-zA-Z0-9]{20,}"),
    SecretPatternDefinition(name: "githubToken", pattern: "gh[pousr]_[A-Za-z0-9]{20,}"),
    SecretPatternDefinition(name: "awsAccessKeyID", pattern: "AKIA[0-9A-Z]{16}"),
    SecretPatternDefinition(
      name: "privateKeyBlock",
      pattern: "-----BEGIN (RSA|EC|OPENSSH|PGP|DSA) PRIVATE KEY-----"),
    SecretPatternDefinition(
      name: "jwt",
      pattern: "eyJ[A-Za-z0-9_-]*\\.eyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*"),
    SecretPatternDefinition(name: "slackToken", pattern: "xox[baprs]-[A-Za-z0-9-]{10,}"),
    SecretPatternDefinition(name: "googleAPIKey", pattern: "AIza[0-9A-Za-z_-]{35}"),
    SecretPatternDefinition(name: "stripeKey", pattern: "(sk|rk)_(live|test)_[0-9a-zA-Z]{20,}"),
    SecretPatternDefinition(name: "npmToken", pattern: "npm_[A-Za-z0-9]{36}"),
    // Google OAuth access tokens (the `ya29.` prefix) and refresh tokens
    // (the `1//` prefix). These are the shapes AURA's own Gmail OAuth flow
    // stores in the Keychain, so they must be recognized by the same
    // canonical redaction boundary as every other secret: a token pasted
    // into a mail body, a command's stdout, or a support bundle must be
    // redacted or flagged, never relayed.
    SecretPatternDefinition(name: "googleOAuthAccessToken", pattern: "ya29\\.[A-Za-z0-9_-]{10,}"),
    SecretPatternDefinition(name: "googleOAuthRefreshToken", pattern: "1//[A-Za-z0-9_-]{10,}"),
  ]

  // A generic "key=value"-shaped heuristic was deliberately considered and
  // rejected here: `OutputRedactor.default` uses this same list to redact
  // real command output before logging, and a broad assignment heuristic
  // would false-positive on ordinary diagnostic text (e.g. config dumps
  // mentioning "token: <placeholder>"), silently destroying legitimate
  // diagnostic content. Only concrete, well-known secret *shapes* are
  // listed above; a value-shape-agnostic scan is out of scope for this list.

  /// Regex pattern strings only, in library order — the shape `OutputRedactor`
  /// and `RepositoryInstructionsScanner` consume.
  public static var patterns: [String] { all.map(\.pattern) }
}
