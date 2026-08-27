import AuraCore
import AuraProductivity
import AuraSecurity
import Foundation
import Testing

/// Closes the "redacted leakage corpus across logs/events/env/args/crashes/
/// support" leg of SP-024 for the OAuth path.
///
/// Token material must never appear in a diagnostic, an event, a reference,
/// a redacted summary, or a Keychain key. These tests assert the typed
/// boundaries that keep a secret out of every non-Keychain surface.
@Suite("OAuth secret-leakage corpus")
struct OAuthLeakageCorpusTests {

  private static let accessToken = "ya29.access-secret-value"
  private static let refreshToken = "1//refresh-secret-value"

  private static func material() throws -> OAuthTokenMaterial {
    try OAuthTokenMaterial(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: Date().addingTimeInterval(3_600),
      scopes: OAuthScopeManifest.gmailReadFirst.scopes(for: .read))
  }

  @Test("Token material never appears in a token reference or its Keychain key")
  func tokenReferenceCarriesNoSecret() throws {
    let reference = try OAuthTokenReference(provider: .gmail, accountID: "person@example.com")
    #expect(reference.keychainKey.contains(Self.accessToken) == false)
    #expect(reference.keychainKey.contains(Self.refreshToken) == false)
    #expect(reference.keychainKey.contains("person@example.com") == true)
  }

  @Test("OAuth error diagnostics never echo token material or provider free text")
  func oauthDiagnosticsCarryNoSecret() {
    // A provider-controlled error_description may contain request details; the
    // diagnostic must preserve only the reviewed protocol error identifier.
    let diagnostic = ProductivityRedaction.diagnostic(
      for: .oauthTokenExchangeRejected(.invalidGrant))
    #expect(diagnostic.contains(Self.accessToken) == false)
    #expect(diagnostic.contains(Self.refreshToken) == false)
    #expect(diagnostic.contains("invalid_grant"))
  }

  @Test("Redacted bounded text strips a token pasted into external content")
  func boundedTextRedactsEmbeddedToken() {
    let body = "Please review this attachment. \(Self.accessToken)"
    let bounded = ProductivityRedaction.boundedText(body)
    #expect(bounded.contains(Self.accessToken) == false)
    #expect(bounded.contains("Please review this attachment"))
  }

  @Test("SecretScanner flags the OAuth-shaped token before it can be persisted")
  func secretScannerFlagsOAuthToken() {
    let scanner = SecretScanner()
    #expect(scanner.containsSecret(Self.accessToken))
    #expect(scanner.containsSecret(Self.refreshToken))
  }

  @Test("Keychain store keeps material only behind the secret store boundary")
  func keychainStoreKeepsMaterialBehindBoundary() async throws {
    let secretStore = ProductivitySecretStoreFake()
    let store = KeychainOAuthTokenStore(secretStore: secretStore)
    let reference = try OAuthTokenReference(provider: .gmail, accountID: "person@example.com")
    try await store.save(try Self.material(), for: reference)

    // The raw Keychain value holds the token (that is its job), but the
    // reference and the store's public surface never expose it. The stored
    // JSON escapes slashes, so compare against the token's distinctive
    // prefix rather than the exact literal.
    let raw = await secretStore.rawValue(forKey: reference.keychainKey)
    #expect(raw != nil)
    let stored = String(decoding: raw!, as: UTF8.self)
    #expect(stored.contains("ya29.access-secret-value"))
    #expect(stored.contains("refresh-secret-value"))

    // Revocation deletes the material entirely.
    try await store.revoke(reference)
    #expect(await secretStore.rawValue(forKey: reference.keychainKey) == nil)
  }
}
