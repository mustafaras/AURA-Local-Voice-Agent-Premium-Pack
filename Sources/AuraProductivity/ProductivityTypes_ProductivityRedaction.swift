import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// The redaction boundary for productivity integrations.
///
/// `ProductivityError.errorDescription` is written for a person reading a
/// dialog and interpolates the private values it names: `accountAmbiguous`
/// carries every candidate mail address verbatim and `profileAmbiguous`
/// carries browser profile identifiers. Those strings must never reach an
/// event payload, a log line, a model prompt, or a ledger entry, so every
/// non-UI surface formats a failure through `diagnostic(for:)` and names an
/// account by an irreversible fingerprint instead of by its address.
///
/// None of this substitutes for not holding the secret: token material lives
/// only behind `OAuthTokenStoring` and is never carried by a record, a
/// snapshot, an error, or a summary in the first place.
public enum ProductivityRedaction {
  /// Maximum characters of provider-supplied text any summary may carry.
  /// External content is bounded before it can reach a prompt or an event.
  public static let summaryCharacterLimit = 240

  /// Stable, irreversible identifier for an account or a browser profile —
  /// safe for events, logs, prompts, and evidence records. The address cannot
  /// be recovered from it, and the same address always produces the same
  /// fingerprint, so two records can still be correlated.
  public static func fingerprint(_ identifier: String) -> String {
    let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let digest = SHA256.hash(data: Data(normalized.utf8))
    return "ac-" + digest.compactMap { String(format: "%02x", $0) }.joined().prefix(12)
  }

  /// UI-only masked label. The user is looking at their own screen, so the
  /// domain stays legible while the local part is reduced to its first
  /// character — enough to tell two enrolled accounts apart without printing
  /// a full address into a screenshot or a support bundle.
  public static func displayLabel(_ accountID: String) -> String {
    let trimmed = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let atIndex = trimmed.firstIndex(of: "@") else {
      guard let first = trimmed.first else { return "•••" }
      return "\(first)•••"
    }
    let localPart = trimmed[trimmed.startIndex..<atIndex]
    let domain = trimmed[atIndex...]
    guard let first = localPart.first else { return "•••\(domain)" }
    return "\(first)•••\(domain)"
  }

  /// Non-UI failure text. Distinct per case, because the dialogue and health
  /// surfaces must be able to tell "grant access" from "reconnect the
  /// account", but never interpolating a private value: candidate lists
  /// collapse to a count, and caller- or provider-supplied free text is
  /// dropped rather than echoed. Provider hostnames and reviewed OAuth scope
  /// strings are retained deliberately — neither is user data.
  public static func diagnostic(for error: ProductivityError) -> String {
    switch error {
    case .notConfigured:
      return "integration is not configured"
    case .permissionRequired:
      return "the user has not granted access yet"
    case .permissionDenied:
      return "access was denied"
    case .oauthTokenExchangeRejected(let reason):
      return "the OAuth token exchange was rejected: \(reason.rawValue)"
    case .tokenExpiredOrRevoked:
      return "the stored credential is expired or revoked"
    case .networkUnavailable:
      return "the network is unavailable"
    case .providerUnavailable:
      return "the provider is unavailable"
    case .insufficientScope(let required):
      return "the configured scope is insufficient: \(required)"
    case .accountAmbiguous(let candidates):
      return "the account is ambiguous among \(candidates.count) approved accounts"
    case .profileAmbiguous(let candidates):
      return "the browser profile is ambiguous among \(candidates.count) approved profiles"
    case .privacyBlocked(let reason):
      return "content was withheld by the privacy policy: \(reason)"
    case .invalidInput:
      return "the request was rejected as invalid"
    case .invalidRedirect(let host):
      return "the provider redirect host is not allowed: \(host)"
    case .hostNotAllowed(let host):
      return "the provider host is not allowed: \(host)"
    case .unsupported:
      return "the requested integration operation is not supported"
    case .cancelled:
      return "the request was cancelled"
    }
  }

  /// Bound and sanitize provider-supplied text before it can enter a prompt,
  /// an event, or a UI row.
  ///
  /// Two things happen, in this order. Newlines collapse, so a crafted mail
  /// body cannot forge extra lines in a log or extra sections in a prompt.
  /// Then the shared `OutputRedactor.default` — the same canonical
  /// `SecretPatternLibrary` the shell output path and `SecretScanner` use —
  /// replaces any secret-shaped substring, so a token pasted *into* a message
  /// body by a third party is redacted rather than relayed.
  public static func boundedText(_ text: String, limit: Int = summaryCharacterLimit) -> String {
    let collapsed =
      text
      .replacingOccurrences(of: "\r\n", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let sanitized = OutputRedactor.default.redact(collapsed)
    guard sanitized.count > limit else { return sanitized }
    return String(sanitized.prefix(limit)) + "…"
  }
}
