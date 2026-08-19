import Foundation
import Network

/// The configuration required to run the Gmail OAuth authorization-code
/// flow. PKCE is always required. A provider-issued Desktop client secret is
/// optional and remains memory-only; it is never placed in the authorization
/// URL, persisted, logged, or returned from this type.
public struct GmailOAuthConfiguration: Sendable, Equatable {
  public let clientID: String
  let clientSecret: String?
  public let authorizationEndpoint: URL
  public let tokenEndpoint: URL
  public let redirectURI: URL

  public init(
    clientID: String,
    clientSecret: String? = nil,
    authorizationEndpoint: URL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
    tokenEndpoint: URL = URL(string: "https://oauth2.googleapis.com/token")!,
    redirectURI: URL = URL(string: "http://127.0.0.1:48080/oauth2callback")!
  ) throws(ProductivityError) {
    guard !clientID.isEmpty, !clientID.contains("\n"), !clientID.contains("\r") else {
      throw .invalidInput("Gmail OAuth client ID must be non-empty and single-line")
    }
    if let clientSecret {
      guard !clientSecret.isEmpty, !clientSecret.contains("\n"), !clientSecret.contains("\r") else {
        throw .invalidInput("Gmail OAuth client secret must be non-empty and single-line")
      }
    }
    guard authorizationEndpoint.scheme?.lowercased() == "https",
      authorizationEndpoint.host?.lowercased() == "accounts.google.com"
    else {
      throw .hostNotAllowed(host: authorizationEndpoint.host ?? "missing")
    }
    guard tokenEndpoint.scheme?.lowercased() == "https",
      tokenEndpoint.host?.lowercased() == "oauth2.googleapis.com"
    else {
      throw .hostNotAllowed(host: tokenEndpoint.host ?? "missing")
    }
    guard Self.isLocalRedirect(redirectURI), redirectURI.path == "/oauth2callback",
      redirectURI.port != nil
    else {
      throw .invalidRedirect(host: redirectURI.host ?? "missing")
    }
    self.clientID = clientID
    self.clientSecret = clientSecret
    self.authorizationEndpoint = authorizationEndpoint
    self.tokenEndpoint = tokenEndpoint
    self.redirectURI = redirectURI
  }

  public var callbackPort: UInt16 {
    UInt16(redirectURI.port ?? 80)
  }

  private static func isLocalRedirect(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "http", url.user == nil, url.password == nil else {
      return false
    }
    // The listener below is deliberately IPv4 loopback only. Keeping the
    // accepted redirect host identical to the bind address avoids a config
    // that validates but can never receive its callback.
    return url.host?.lowercased() == "127.0.0.1"
  }
}

/// A callback payload is kept in memory only long enough to validate state and
/// exchange the authorization code. It is never logged, emitted, or surfaced
/// to the model/UI.
struct OAuthCallbackPayload: Sendable {
  let state: String?
  let code: String?
  let error: String?
}

/// Minimal localhost HTTP callback listener for the OAuth redirect.
///
/// The listener binds only to loopback, accepts one request, returns a generic
/// browser response, and then closes. It deliberately does not retain the
/// request URL or query string after parsing.
final class LocalOAuthCallbackServer: @unchecked Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "ai.aura.local.oauth-callback")
  private let path: String
  private let lock = NSLock()
  private var startContinuation: CheckedContinuation<Void, ProductivityError>?
  private var callbackContinuation: CheckedContinuation<OAuthCallbackPayload, ProductivityError>?
  private var pendingCallback: Result<OAuthCallbackPayload, ProductivityError>?
  private var isStopped = false

  init(configuration: GmailOAuthConfiguration) throws(ProductivityError) {
    guard let port = NWEndpoint.Port(rawValue: configuration.callbackPort) else {
      throw .invalidInput("Gmail OAuth callback port is invalid")
    }
    do {
      let parameters = NWParameters.tcp
      parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
      listener = try NWListener(using: parameters)
    } catch {
      throw .providerUnavailable
    }
    path = configuration.redirectURI.path
    listener.newConnectionHandler = { [weak self] connection in
      self?.handle(connection)
    }
    listener.stateUpdateHandler = { [weak self] state in
      self?.handle(state: state)
    }
  }

  func start() async throws(ProductivityError) {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, ProductivityError>) in
      lock.lock()
      if isStopped {
        lock.unlock()
        continuation.resume(throwing: ProductivityError.cancelled)
        return
      }
      startContinuation = continuation
      lock.unlock()
      listener.start(queue: queue)
    }
  }

  func waitForCallback() async throws(ProductivityError) -> OAuthCallbackPayload {
    do {
      return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation {
          (continuation: CheckedContinuation<OAuthCallbackPayload, ProductivityError>) in
          lock.lock()
          if let pendingCallback {
            self.pendingCallback = nil
            lock.unlock()
            continuation.resume(with: pendingCallback)
            return
          }
          if isStopped {
            lock.unlock()
            continuation.resume(throwing: ProductivityError.cancelled)
            return
          }
          callbackContinuation = continuation
          lock.unlock()
        }
      } onCancel: { [weak self] in
        self?.stop()
      }
    } catch let error as ProductivityError {
      throw error
    } catch {
      throw .cancelled
    }
  }

  func stop() {
    lock.lock()
    guard !isStopped else {
      lock.unlock()
      return
    }
    isStopped = true
    let start = startContinuation
    startContinuation = nil
    let callback = callbackContinuation
    callbackContinuation = nil
    lock.unlock()
    listener.cancel()
    start?.resume(throwing: ProductivityError.cancelled)
    callback?.resume(throwing: ProductivityError.cancelled)
  }

  private func handle(state: NWListener.State) {
    switch state {
    case .ready:
      lock.lock()
      let continuation = startContinuation
      startContinuation = nil
      lock.unlock()
      continuation?.resume()
    case .failed:
      fail(.providerUnavailable)
    case .cancelled:
      fail(.cancelled)
    default:
      break
    }
  }

  private func handle(_ connection: NWConnection) {
    connection.stateUpdateHandler = { state in
      if case .failed = state {
        connection.cancel()
      }
    }
    connection.start(queue: queue)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) {
      [weak self, weak connection] data, _, _, _ in
      guard let self, let connection else { return }
      let result: Result<OAuthCallbackPayload, ProductivityError>
      if let data, let payload = Self.parse(data: data, path: self.path) {
        result = .success(payload)
        self.sendSuccess(to: connection)
      } else {
        result = .failure(ProductivityError.invalidInput("OAuth callback request is invalid"))
        self.sendFailure(to: connection)
      }
      self.resolve(result)
    }
  }

  private func sendSuccess(to connection: NWConnection) {
    send(
      "AURA bağlantısı alındı. Bu pencereyi kapatabilirsiniz.",
      status: "200 OK",
      to: connection)
  }

  private func sendFailure(to connection: NWConnection) {
    send("AURA bağlantısı doğrulanamadı.", status: "400 Bad Request", to: connection)
  }

  private func send(_ body: String, status: String, to connection: NWConnection) {
    let bodyData = Data(body.utf8)
    let header =
      "HTTP/1.1 \(status)\r\nContent-Type: text/plain; charset=utf-8\r\n"
      + "Content-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n"
    connection.send(
      content: Data(header.utf8) + bodyData,
      completion: .contentProcessed { _ in connection.cancel() })
  }

  private func resolve(_ result: Result<OAuthCallbackPayload, ProductivityError>) {
    lock.lock()
    let continuation = callbackContinuation
    if continuation != nil {
      callbackContinuation = nil
    } else {
      pendingCallback = result
    }
    lock.unlock()
    continuation?.resume(with: result)
  }

  private func fail(_ error: ProductivityError) {
    lock.lock()
    let start = startContinuation
    startContinuation = nil
    let callback = callbackContinuation
    callbackContinuation = nil
    lock.unlock()
    start?.resume(throwing: error)
    callback?.resume(throwing: error)
  }

  private static func parse(data: Data, path: String) -> OAuthCallbackPayload? {
    let request = String(decoding: data, as: UTF8.self)
    guard let requestLine = request.components(separatedBy: "\r\n").first else { return nil }
    let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
    guard parts.count == 3, parts[0] == "GET",
      let components = URLComponents(string: "http://127.0.0.1\(parts[1])"),
      components.path == path
    else { return nil }
    let values = Dictionary<String, String>(
      uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
        guard let value = item.value else { return nil }
        return (item.name, value)
      })
    return OAuthCallbackPayload(
      state: values["state"], code: values["code"], error: values["error"])
  }
}

/// Exchanges a validated, one-shot authorization code for Keychain-bound
/// token material. The request body and response are never included in an
/// error or diagnostic string.
struct GmailOAuthTokenExchanger: Sendable {
  let fetcher: any HTTPProviderFetching

  func exchange(
    code: String,
    session: OAuthPKCESession,
    configuration: GmailOAuthConfiguration
  ) async throws(ProductivityError) -> OAuthTokenMaterial {
    guard !code.isEmpty else { throw .invalidInput("OAuth authorization code is empty") }
    var request = URLRequest(url: configuration.tokenEndpoint)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 20
    var fields = [
      ("code", code),
      ("client_id", configuration.clientID),
      ("code_verifier", session.verifierForTokenExchange),
      ("redirect_uri", session.redirectURI.absoluteString),
      ("grant_type", "authorization_code"),
    ]
    if let clientSecret = configuration.clientSecret {
      fields.append(("client_secret", clientSecret))
    }
    request.httpBody = Self.formBody(fields)

    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await fetcher.data(for: request)
    } catch let error as ProductivityError {
      throw error
    } catch let error as URLError {
      throw ProviderHTTPClient.mapped(error)
    } catch {
      throw .providerUnavailable
    }
    guard (200...299).contains(response.statusCode) else {
      if response.statusCode == 400 || response.statusCode == 401 {
        throw .oauthTokenExchangeRejected(Self.rejection(in: data))
      }
      throw .providerUnavailable
    }
    let payload: TokenResponse
    do {
      payload = try JSONDecoder().decode(TokenResponse.self, from: data)
    } catch {
      throw .providerUnavailable
    }
    let scopes = Set(
      (payload.scope ?? session.scopes.sorted().joined(separator: " "))
        .split(whereSeparator: { $0.isWhitespace })
        .map(String.init))
    try OAuthScopeManifest.gmailReadFirst.validate(requestedScopes: scopes, for: .read)
    let expiresAt = payload.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
    return try OAuthTokenMaterial(
      accessToken: payload.accessToken,
      refreshToken: payload.refreshToken,
      expiresAt: expiresAt,
      scopes: scopes)
  }

  private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let scope: String?

    enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
      case refreshToken = "refresh_token"
      case expiresIn = "expires_in"
      case scope
    }
  }

  private struct TokenErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
      case error
      case errorDescription = "error_description"
    }
  }

  /// Preserve only a reviewed OAuth protocol error identifier. In
  /// particular, `error_description` is deliberately not decoded because it
  /// is provider-controlled text and may contain request details.
  private static func rejection(in data: Data) -> OAuthTokenExchangeRejection {
    guard let response = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) else {
      return .unknown
    }
    let code = response.error
    let description = response.errorDescription?.lowercased() ?? ""
    if code == OAuthTokenExchangeRejection.invalidRequest.rawValue {
      if description.contains("client_secret") {
        return .clientSecretRequired
      }
      if description.contains("code_verifier") || description.contains("code challenge") {
        return .codeVerifierRejected
      }
      if description.contains("redirect_uri") {
        return .redirectURIMismatch
      }
      if description.contains("authorization code")
        || (description.contains("parameter") && description.contains("code"))
      {
        return .authorizationCodeRejected
      }
    }
    switch code {
    case OAuthTokenExchangeRejection.invalidGrant.rawValue:
      return .invalidGrant
    case OAuthTokenExchangeRejection.invalidClient.rawValue:
      return .invalidClient
    case OAuthTokenExchangeRejection.invalidRequest.rawValue:
      return .invalidRequest
    case OAuthTokenExchangeRejection.redirectURIMismatch.rawValue:
      return .redirectURIMismatch
    case OAuthTokenExchangeRejection.unauthorizedClient.rawValue:
      return .unauthorizedClient
    default:
      return .unknown
    }
  }

  private static func formBody(_ values: [(String, String)]) -> Data? {
    var components = URLComponents()
    components.queryItems = values.map { URLQueryItem(name: $0.0, value: $0.1) }
    return components.percentEncodedQuery?.data(using: .utf8)
  }
}

/// User-present Gmail OAuth flow. The caller receives only the resulting
/// token material so it can immediately pass it to the Keychain enrollment
/// boundary; the coordinator never persists or exposes it.
public actor GmailOAuthAuthorizationCoordinator {
  private let configuration: GmailOAuthConfiguration
  private let fetcher: any HTTPProviderFetching
  private let openURL: @Sendable (URL) -> Bool
  private var active = false

  public init(
    configuration: GmailOAuthConfiguration,
    fetcher: any HTTPProviderFetching = URLSessionProviderFetcher(),
    openURL: @escaping @Sendable (URL) -> Bool
  ) {
    self.configuration = configuration
    self.fetcher = fetcher
    self.openURL = openURL
  }

  public func authorize() async throws(ProductivityError) -> OAuthTokenMaterial {
    guard !active else { throw .invalidInput("a Gmail OAuth flow is already active") }
    active = true
    defer { active = false }

    let session = try OAuthPKCESession(
      manifest: .gmailReadFirst,
      tier: .read,
      requestedScopes: OAuthScopeManifest.gmailReadFirst.scopes(for: .read),
      redirectURI: configuration.redirectURI)
    let server = try LocalOAuthCallbackServer(configuration: configuration)
    defer { server.stop() }
    try await server.start()
    guard let authorizationURL = Self.authorizationURL(
      session: session, configuration: configuration)
    else {
      throw .invalidInput("Gmail OAuth authorization URL could not be built")
    }
    guard openURL(authorizationURL) else {
      throw .providerUnavailable
    }
    let callback = try await server.waitForCallback()
    if let error = callback.error {
      throw error == "access_denied" ? .permissionDenied : .providerUnavailable
    }
    guard let callbackState = callback.state, let code = callback.code else {
      throw .invalidInput("OAuth callback did not contain a code and state")
    }
    try session.validateCallback(
      state: callbackState, code: code, redirectURI: configuration.redirectURI)
    return try await GmailOAuthTokenExchanger(fetcher: fetcher).exchange(
      code: code, session: session, configuration: configuration)
  }

  private static func authorizationURL(
    session: OAuthPKCESession,
    configuration: GmailOAuthConfiguration
  ) -> URL? {
    guard var components = URLComponents(
      url: configuration.authorizationEndpoint, resolvingAgainstBaseURL: false)
    else { return nil }
    components.queryItems = [
      URLQueryItem(name: "client_id", value: configuration.clientID),
      URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: session.scopes.sorted().joined(separator: " ")),
      URLQueryItem(name: "state", value: session.state),
      URLQueryItem(name: "code_challenge", value: session.codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "access_type", value: "offline"),
      URLQueryItem(name: "prompt", value: "consent"),
    ]
    return components.url
  }
}
