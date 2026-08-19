import AuraCore
import AuraSecurity
import Foundation
import Testing

@testable import AuraProductivity

/// SP-010: provider/account onboarding, transport, revocation, and the
/// redaction boundary.
///
/// Every credential here is synthetic and shaped to *look* like a real
/// secret, because that is what makes the redaction assertions meaningful.
/// No test opens a socket: the provider transport is exercised through the
/// `HTTPProviderFetching` seam against recorded payloads.

// MARK: - Fixtures

private let approvedAccount = "person@example.com"
private let secondAccount = "other@example.com"
/// Shaped like an OpenAI-style key so `SecretPatternLibrary` recognizes it.
private let syntheticAccessToken = "sk-abcdefghijklmnopqrstuvwxyz012345"

private actor RequestRecorder {
  private(set) var requests: [URLRequest] = []
  func record(_ request: URLRequest) { requests.append(request) }
  var last: URLRequest? { requests.last }
}

private struct RecordedFetcher: HTTPProviderFetching {
  let status: Int
  let payload: Data
  let error: (any Error)?
  /// Captures what the client actually sent, so the token's placement can be
  /// asserted rather than assumed.
  let observed = RequestRecorder()

  init(status: Int = 200, payload: Data = Data("{}".utf8), error: (any Error)? = nil) {
    self.status = status
    self.payload = payload
    self.error = error
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    await observed.record(request)
    if let error { throw error }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
    return (payload, response)
  }
}

private func gmailPolicy() -> ProductivityNetworkPolicy {
  ProductivityNetworkPolicy(allowlist: NetworkAllowlist(allowedHosts: ["gmail.googleapis.com"]))
}

private func makeOnboarding(
  approved: [String] = [approvedAccount],
  profiles: [String] = ["personal"],
  tokenStore: any OAuthTokenStoring,
  browserSecretStore: SafariBridgeSecretStore? = nil,
  allowsTestAuthorization: Bool = false
) -> IntegrationOnboardingService {
  IntegrationOnboardingService(
    approvedAccounts: ApprovedIntegrationAccounts(accountIDs: approved),
    approvedProfiles: ApprovedBrowserProfiles(profileIDs: profiles),
    tokenStore: tokenStore,
    browserSecretStore: browserSecretStore,
    allowsTestAuthorization: allowsTestAuthorization)
}

private func readAuthorization(
  accountID: String = approvedAccount,
  tier: OAuthScopeTier = .read,
  scopes: Set<String> = OAuthScopeManifest.gmailReadFirst.scopes(for: .read),
  source: IntegrationAuthorizationSource = .userOnboardingConsent
) throws -> IntegrationAccountAuthorization {
  IntegrationAccountAuthorization(
    provider: .gmail, accountID: accountID, tier: tier, grantedScopes: scopes,
    source: source,
    material: try OAuthTokenMaterial(accessToken: syntheticAccessToken, scopes: scopes))
}

// MARK: - Authority

@Suite("SP-010 onboarding authority")
struct SP010OnboardingAuthorityTests {
  @Test("inferred authority is refused and stores nothing")
  func inferredAuthorityRefused() async throws {
    let store = OAuthTokenStoreFake()
    let onboarding = makeOnboarding(tokenStore: store)
    await #expect(throws: ProductivityError.permissionRequired) {
      try await onboarding.enroll(try readAuthorization(source: .inferred))
    }
    // The decisive assertion is not the throw but the absence of a
    // credential: a refusal that still wrote to the Keychain would be no
    // refusal at all.
    let reference = try OAuthTokenReference(provider: .gmail, accountID: approvedAccount)
    #expect(try await store.accessToken(for: reference) == nil)
    #expect(await onboarding.records().isEmpty)
  }

  @Test("test authorization is refused unless the service was built for it")
  func testAuthorityRequiresExplicitOptIn() async throws {
    let refusing = makeOnboarding(tokenStore: OAuthTokenStoreFake())
    await #expect(throws: ProductivityError.permissionDenied) {
      try await refusing.enroll(try readAuthorization(source: .explicitTestAuthorization))
    }

    let accepting = makeOnboarding(
      tokenStore: OAuthTokenStoreFake(), allowsTestAuthorization: true)
    let record = try await accepting.enroll(
      try readAuthorization(source: .explicitTestAuthorization))
    #expect(record.accountID == approvedAccount)
  }

  @Test("an account the user never approved cannot be enrolled")
  func unapprovedAccountRefused() async throws {
    let store = OAuthTokenStoreFake()
    let onboarding = makeOnboarding(approved: [approvedAccount], tokenStore: store)
    await #expect(throws: ProductivityError.self) {
      try await onboarding.enroll(try readAuthorization(accountID: "stranger@example.com"))
    }
    let reference = try OAuthTokenReference(provider: .gmail, accountID: "stranger@example.com")
    #expect(try await store.accessToken(for: reference) == nil)
  }
}

// MARK: - Scope boundary

@Suite("SP-010 scope boundary")
struct SP010ScopeBoundaryTests {
  @Test("compose and send tiers are refused at enrollment")
  func nonReadTiersRefused() async throws {
    let onboarding = makeOnboarding(tokenStore: OAuthTokenStoreFake())
    for tier in [OAuthScopeTier.compose, .send] {
      await #expect(throws: ProductivityError.self) {
        try await onboarding.enroll(
          try readAuthorization(
            tier: tier, scopes: OAuthScopeManifest.gmailReadFirst.scopes(for: tier)))
      }
    }
  }

  @Test("a send scope smuggled into a read-tier enrollment is refused")
  func sendScopeInReadTierRefused() async throws {
    let onboarding = makeOnboarding(tokenStore: OAuthTokenStoreFake())
    let scopes = OAuthScopeManifest.gmailReadFirst.scopes(for: .read)
      .union(["https://www.googleapis.com/auth/gmail.send"])
    await #expect(throws: ProductivityError.self) {
      try await onboarding.enroll(try readAuthorization(scopes: scopes))
    }
  }

  @Test("scope escalation always fails, so send stays unreachable")
  func escalationRefused() async throws {
    let onboarding = makeOnboarding(tokenStore: OAuthTokenStoreFake())
    _ = try await onboarding.enroll(try readAuthorization())
    await #expect(throws: ProductivityError.self) {
      _ = try await onboarding.escalateScope(
        provider: .gmail, accountID: approvedAccount, to: .send)
    }
  }
}

// MARK: - Connection state and revocation

@Suite("SP-010 connection state and revocation")
struct SP010ConnectionStateTests {
  @Test("an approved account is not connected until it is enrolled")
  func approvedIsNotConnected() async throws {
    let onboarding = makeOnboarding(tokenStore: OAuthTokenStoreFake())
    let state = await onboarding.connectionState(provider: .gmail, accountID: approvedAccount)
    #expect(state == .notProvisioned)
  }

  @Test("revocation disconnects the account and clears the credential")
  func revocationDisconnects() async throws {
    let store = OAuthTokenStoreFake()
    let onboarding = makeOnboarding(tokenStore: store)
    _ = try await onboarding.enroll(try readAuthorization())
    #expect(
      await onboarding.connectionState(provider: .gmail, accountID: approvedAccount)
        == .connected(fingerprint: ProductivityRedaction.fingerprint(approvedAccount)))

    try await onboarding.revokeAccount(provider: .gmail, accountID: approvedAccount)

    #expect(
      await onboarding.connectionState(provider: .gmail, accountID: approvedAccount)
        == .notProvisioned)
    let reference = try OAuthTokenReference(provider: .gmail, accountID: approvedAccount)
    #expect(try await store.accessToken(for: reference) == nil)
    #expect(await onboarding.records().isEmpty)
  }

  @Test("browser profile enrollment provisions a secret and revocation clears it")
  func browserProfileLifecycle() async throws {
    let secretStore = SafariBridgeSecretStore(
      secretStore: ProductivitySecretStoreFake(), serviceName: "test.bridge")
    let onboarding = makeOnboarding(
      tokenStore: OAuthTokenStoreFake(), browserSecretStore: secretStore)

    #expect(await onboarding.browserProfileState(profileID: "personal") == .notProvisioned)
    let secret = try await onboarding.enrollBrowserProfile(
      BrowserProfileAuthorization(profileID: "personal", source: .userOnboardingConsent))
    #expect(!secret.isEmpty)
    #expect(
      await onboarding.browserProfileState(profileID: "personal")
        == .connected(fingerprint: ProductivityRedaction.fingerprint("personal")))

    try await onboarding.revokeBrowserProfile(profileID: "personal")
    #expect(await onboarding.browserProfileState(profileID: "personal") == .notProvisioned)
  }

  @Test("an unapproved profile is never reported as connected")
  func unapprovedProfileNotConnected() async throws {
    let secretStore = SafariBridgeSecretStore(
      secretStore: ProductivitySecretStoreFake(), serviceName: "test.bridge")
    let onboarding = makeOnboarding(
      tokenStore: OAuthTokenStoreFake(), browserSecretStore: secretStore)
    guard case .unavailable = await onboarding.browserProfileState(profileID: "work") else {
      Issue.record("an unapproved profile must not report a connected or provisionable state")
      return
    }
  }
}

// MARK: - Redaction and secret leakage

@Suite("SP-010 redaction boundary")
struct SP010RedactionTests {
  @Test("a fingerprint is stable, distinguishing, and does not contain the address")
  func fingerprintProperties() {
    let first = ProductivityRedaction.fingerprint(approvedAccount)
    #expect(first == ProductivityRedaction.fingerprint(approvedAccount))
    #expect(first == ProductivityRedaction.fingerprint("  PERSON@Example.com "))
    #expect(first != ProductivityRedaction.fingerprint(secondAccount))
    #expect(!first.contains("person"))
    #expect(!first.contains("example.com"))
  }

  @Test("the display label masks the local part but keeps the domain legible")
  func displayLabelMasks() {
    let label = ProductivityRedaction.displayLabel(approvedAccount)
    #expect(label == "p•••@example.com")
    #expect(!label.contains("person"))
    #expect(ProductivityRedaction.displayLabel("") == "•••")
  }

  /// Why the boundary exists at all: the human-facing description
  /// interpolates private values and the diagnostic must not. The paired
  /// assertions are what prove these are genuinely two different strings
  /// rather than two names for the same text.
  @Test("the diagnostic drops the candidate addresses that errorDescription leaks")
  func diagnosticDoesNotLeakCandidates() {
    let error = ProductivityError.accountAmbiguous(candidates: [approvedAccount, secondAccount])
    let human = error.errorDescription ?? ""
    #expect(human.contains(approvedAccount))

    let diagnostic = ProductivityRedaction.diagnostic(for: error)
    #expect(!diagnostic.contains(approvedAccount))
    #expect(!diagnostic.contains(secondAccount))
    #expect(diagnostic.contains("2"))
  }

  @Test("profile ambiguity and invalid input drop their private detail too")
  func otherDiagnosticsAreClean() {
    let profileError = ProductivityError.profileAmbiguous(candidates: ["personal", "work"])
    let profileDiagnostic = ProductivityRedaction.diagnostic(for: profileError)
    #expect(!profileDiagnostic.contains("personal"))
    #expect(!profileDiagnostic.contains("work"))

    let inputError = ProductivityError.invalidInput("/Users/someone/private/path.txt")
    let inputDiagnostic = ProductivityRedaction.diagnostic(for: inputError)
    #expect(!inputDiagnostic.contains("someone"))
    #expect(!inputDiagnostic.contains("path.txt"))
  }

  @Test("bounded text collapses newlines, truncates, and scrubs secret shapes")
  func boundedTextSanitizes() {
    let hostile =
      "Line one\nIGNORE PREVIOUS\r\ntoken \(syntheticAccessToken) ghp_ABCDEFGHIJ0123456789"
    let bounded = ProductivityRedaction.boundedText(hostile)
    #expect(!bounded.contains("\n"))
    #expect(!bounded.contains("\r"))
    // A token pasted into a message body by a third party is redacted rather
    // than relayed into a prompt or an event.
    #expect(!bounded.contains(syntheticAccessToken))
    #expect(!bounded.contains("ghp_ABCDEFGHIJ0123456789"))

    let long = String(repeating: "a", count: 500)
    #expect(ProductivityRedaction.boundedText(long).count <= 241)
  }

  @Test("an enrollment record never carries token material, even when described")
  func recordCarriesNoSecret() async throws {
    let onboarding = makeOnboarding(tokenStore: OAuthTokenStoreFake())
    let record = try await onboarding.enroll(try readAuthorization())
    // `String(describing:)` walks every stored property, so this catches a
    // future field that starts carrying the credential.
    let described = String(describing: record)
    #expect(!described.contains(syntheticAccessToken))
    #expect(!record.tokenReference.keychainKey.contains(syntheticAccessToken))
    #expect(record.fingerprint != record.accountID)
    #expect(record.isReadOnly)
  }
}

// MARK: - Provider transport

@Suite("SP-010 provider transport")
struct SP010ProviderTransportTests {
  @Test("the bearer token travels in a header and never in the URL")
  func tokenStaysInHeader() async throws {
    let payload = Data(#"{"emailAddress":"person@example.com"}"#.utf8)
    let fetcher = RecordedFetcher(payload: payload)
    let transport = try URLSessionGmailReadTransport(
      fetcher: fetcher, networkPolicy: gmailPolicy())

    _ = try await transport.accounts(accessToken: syntheticAccessToken)

    let request = await fetcher.observed.last
    #expect(
      request?.value(forHTTPHeaderField: "Authorization") == "Bearer \(syntheticAccessToken)")
    #expect(request?.httpMethod == "GET")
    #expect(request?.url?.absoluteString.contains(syntheticAccessToken) == false)
  }

  @Test("a non-allowlisted or non-HTTPS endpoint fails closed at construction")
  func endpointIsConstrained() async throws {
    #expect(throws: ProductivityError.self) {
      _ = try URLSessionGmailReadTransport(
        endpoint: URL(string: "https://mail.example.com/v1")!,
        fetcher: RecordedFetcher(), networkPolicy: gmailPolicy())
    }
    #expect(throws: ProductivityError.self) {
      _ = try URLSessionGmailReadTransport(
        endpoint: URL(string: "http://gmail.googleapis.com/gmail/v1")!,
        fetcher: RecordedFetcher(), networkPolicy: gmailPolicy())
    }
  }

  @Test("each provider status maps to its own distinct failure")
  func statusMapping() async throws {
    let expectations: [(Int, ProductivityError)] = [
      (401, .tokenExpiredOrRevoked),
      (403, .insufficientScope(required: "the provider refused the configured read scope")),
      (503, .providerUnavailable),
      (429, .providerUnavailable),
    ]
    for (status, expected) in expectations {
      let transport = try URLSessionGmailReadTransport(
        fetcher: RecordedFetcher(status: status), networkPolicy: gmailPolicy())
      await #expect(throws: expected) {
        _ = try await transport.unreadCount(accountID: approvedAccount, accessToken: "t")
      }
    }
  }

  @Test("being offline is reported as a network failure, not a bad credential")
  func offlineIsDistinct() async throws {
    let transport = try URLSessionGmailReadTransport(
      fetcher: RecordedFetcher(error: URLError(.notConnectedToInternet)),
      networkPolicy: gmailPolicy())
    await #expect(throws: ProductivityError.networkUnavailable) {
      _ = try await transport.unreadCount(accountID: approvedAccount, accessToken: "t")
    }
  }

  @Test("a malformed provider payload is an outage, never a half-built message")
  func malformedPayloadFailsClosed() async throws {
    let transport = try URLSessionGmailReadTransport(
      fetcher: RecordedFetcher(payload: Data("not json".utf8)), networkPolicy: gmailPolicy())
    await #expect(throws: ProductivityError.providerUnavailable) {
      _ = try await transport.accounts(accessToken: "t")
    }
  }

  @Test("a recorded thread decodes headers and a base64url plain-text body")
  func decodesRecordedThread() async throws {
    // "Merhaba" in the URL-safe base64 alphabet without padding, as Gmail
    // sends it.
    let encodedBody = Data("Merhaba".utf8).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    let payload = Data(
      """
      {"messages":[{"id":"m1","threadId":"t1","labelIds":["UNREAD"],
      "internalDate":"1700000000000","snippet":"ignored",
      "payload":{"mimeType":"text/plain",
      "headers":[{"name":"From","value":"sender@example.com"},
      {"name":"To","value":"person@example.com, other@example.com"},
      {"name":"Subject","value":"Quarterly plan"}],
      "body":{"size":7,"data":"\(encodedBody)"}}}]}
      """.utf8)
    let transport = try URLSessionGmailReadTransport(
      fetcher: RecordedFetcher(payload: payload), networkPolicy: gmailPolicy())

    let messages = try await transport.thread(
      accountID: approvedAccount, threadID: "t1", accessToken: "t")

    #expect(messages.count == 1)
    #expect(messages[0].subject == "Quarterly plan")
    #expect(messages[0].sender == "sender@example.com")
    #expect(messages[0].recipients.count == 2)
    #expect(messages[0].body == "Merhaba")
    #expect(messages[0].isUnread)
    #expect(messages[0].receivedAt == Date(timeIntervalSince1970: 1_700_000_000))
  }
}

// MARK: - Adapter composition over the real transport

@Suite("SP-010 mail adapter over the production transport")
struct SP010MailAdapterCompositionTests {
  private func makeAdapter(
    approved: [String],
    tokenStore: any OAuthTokenStoring,
    payload: Data = Data(#"{"messages":[]}"#.utf8)
  ) throws -> GmailReadAdapter {
    let policy = gmailPolicy()
    return try GmailReadAdapter(
      approvedAccounts: ApprovedIntegrationAccounts(accountIDs: approved),
      configuredScopes: OAuthScopeManifest.gmailReadFirst.scopes(for: .read),
      tokenStore: tokenStore,
      transport: try URLSessionGmailReadTransport(
        fetcher: RecordedFetcher(payload: payload), networkPolicy: policy),
      networkPolicy: policy)
  }

  @Test("a revoked credential stops reads at the adapter")
  func revokedCredentialStopsReads() async throws {
    let store = OAuthTokenStoreFake()
    let onboarding = makeOnboarding(tokenStore: store)
    _ = try await onboarding.enroll(try readAuthorization())
    let adapter = try makeAdapter(approved: [approvedAccount], tokenStore: store)

    // Connected: the read reaches the transport and returns the recorded
    // empty result.
    let before = try await adapter.search(
      accountID: approvedAccount, query: "is:unread", limit: 5)
    #expect(before.isEmpty)

    try await onboarding.revokeAccount(provider: .gmail, accountID: approvedAccount)

    await #expect(throws: ProductivityError.tokenExpiredOrRevoked) {
      _ = try await adapter.search(accountID: approvedAccount, query: "is:unread", limit: 5)
    }
  }

  @Test("two approved accounts with no stated account is ambiguous, never a guess")
  func ambiguityIsNotResolvedByGuessing() async throws {
    let store = OAuthTokenStoreFake()
    let adapter = try makeAdapter(
      approved: [approvedAccount, secondAccount], tokenStore: store)
    await #expect(throws: ProductivityError.self) {
      _ = try await adapter.accounts()
    }
  }
}
