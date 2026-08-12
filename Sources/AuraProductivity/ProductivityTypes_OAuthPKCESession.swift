import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// A short-lived OAuth authorization session. State and PKCE bind the callback
/// to the exact user-started request; the authorization code itself is never
/// stored in this value, emitted as an event, or placed in a prompt.
public struct OAuthPKCESession: Sendable, Equatable {
  public let provider: OAuthProviderID
  public let redirectURI: URL
  public let state: String
  public let codeChallenge: String
  public let scopes: Set<String>
  private let codeVerifier: String

  public init(
    manifest: OAuthScopeManifest,
    tier: OAuthScopeTier,
    requestedScopes: Set<String>,
    redirectURI: URL,
    state: String? = nil,
    codeVerifier: String? = nil
  ) throws(ProductivityError) {
    try manifest.validate(requestedScopes: requestedScopes, for: tier)
    guard Self.isAllowedRedirect(redirectURI) else {
      throw .invalidRedirect(host: redirectURI.host ?? "missing")
    }
    let resolvedState = state ?? UUID().uuidString
    let resolvedVerifier = codeVerifier ?? (UUID().uuidString + UUID().uuidString)
    guard !resolvedState.isEmpty, resolvedVerifier.count >= 43 else {
      throw .invalidInput("OAuth state and PKCE verifier must be non-empty and bounded")
    }
    self.provider = manifest.provider
    self.redirectURI = redirectURI
    self.state = resolvedState
    self.codeVerifier = resolvedVerifier
    self.codeChallenge = Self.challenge(for: resolvedVerifier)
    self.scopes = requestedScopes
  }

  public func validateCallback(
    state callbackState: String,
    code: String,
    redirectURI callbackURI: URL
  ) throws(ProductivityError) {
    guard callbackState == state else {
      throw .invalidInput("OAuth callback state mismatch")
    }
    guard callbackURI == redirectURI else {
      throw .invalidRedirect(host: callbackURI.host ?? "missing")
    }
    guard !code.isEmpty, !code.contains("\n"), !code.contains("\r") else {
      throw .invalidInput("OAuth callback code is invalid")
    }
  }

  /// The verifier is consumed only by the token-exchange boundary and must
  /// never be included in logs, prompts, events, or support bundles.
  public var verifierForTokenExchange: String { codeVerifier }

  private static func challenge(for verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return Data(digest).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private static func isAllowedRedirect(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(),
      url.user == nil, url.password == nil
    else { return false }
    if scheme == "https" { return true }
    return scheme == "http" && ["127.0.0.1", "localhost", "[::1]", "::1"].contains(host)
  }
}
