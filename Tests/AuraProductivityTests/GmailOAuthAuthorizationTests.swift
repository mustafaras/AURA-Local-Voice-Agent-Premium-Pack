import AuraProductivity
import Foundation
import Testing

actor OAuthURLCapture {
  private(set) var value: URL?

  func set(_ url: URL) { value = url }
}

actor OAuthHTTPFetcherFake: HTTPProviderFetching {
  private(set) var requests: [URLRequest] = []
  private let payload: Data
  private let responseStatus: Int

  init(payload: Data, responseStatus: Int = 200) {
    self.payload = payload
    self.responseStatus = responseStatus
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    return (
      payload,
      HTTPURLResponse(
        url: request.url!, statusCode: responseStatus, httpVersion: nil, headerFields: nil)!)
  }
}

private func queryValue(_ name: String, in url: URL) -> String? {
  URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first {
    $0.name == name
  }?.value
}

@Test
func gmailOAuthUsesLoopbackPKCEAndEntersKeychainBoundary() async throws {
  let redirect = URL(string: "http://127.0.0.1:48081/oauth2callback")!
  let configuration = try GmailOAuthConfiguration(
    clientID: "desktop-client.apps.googleusercontent.com", redirectURI: redirect)
  let fetcher = OAuthHTTPFetcherFake(
    payload: Data(
      #"{"access_token":"access-token","refresh_token":"refresh-token","expires_in":3600,"scope":"https://www.googleapis.com/auth/gmail.readonly"}"#.utf8))
  let capture = OAuthURLCapture()
  let coordinator = GmailOAuthAuthorizationCoordinator(
    configuration: configuration,
    fetcher: fetcher,
    openURL: { url in
      Task {
        await capture.set(url)
        guard let state = queryValue("state", in: url),
          var callback = URLComponents(
            url: redirect, resolvingAgainstBaseURL: false)
        else { return }
        callback.queryItems = [
          URLQueryItem(name: "state", value: state),
          URLQueryItem(name: "code", value: "authorization-code"),
        ]
        guard let callbackURL = callback.url else { return }
        var request = URLRequest(url: callbackURL)
        request.httpMethod = "GET"
        _ = try? await URLSession.shared.data(for: request)
      }
      return true
    })

  let material = try await coordinator.authorize()
  #expect(material.accessToken == "access-token")
  #expect(material.refreshToken == "refresh-token")
  #expect(material.scopes == ["https://www.googleapis.com/auth/gmail.readonly"])

  let authorizationURL = await capture.value
  #expect(authorizationURL != nil)
  #expect(queryValue("code_challenge_method", in: authorizationURL!) == "S256")
  #expect(queryValue("scope", in: authorizationURL!)?.contains("gmail.readonly") == true)
  #expect(queryValue("client_secret", in: authorizationURL!) == nil)

  let requests = await fetcher.requests
  #expect(requests.count == 1)
  #expect(requests[0].url?.host == "oauth2.googleapis.com")
  #expect(requests[0].value(forHTTPHeaderField: "Authorization") == nil)
  #expect(String(data: requests[0].httpBody ?? Data(), encoding: .utf8)?.contains("access-token") == false)
}

@Test
func gmailOAuthKeepsDesktopClientSecretOutOfAuthorizationURL() async throws {
  let redirect = URL(string: "http://127.0.0.1:48085/oauth2callback")!
  let configuration = try GmailOAuthConfiguration(
    clientID: "desktop-client.apps.googleusercontent.com",
    clientSecret: "desktop-client-secret",
    redirectURI: redirect)
  let fetcher = OAuthHTTPFetcherFake(
    payload: Data(
      #"{"access_token":"access-token","scope":"https://www.googleapis.com/auth/gmail.readonly"}"#.utf8))
  let capture = OAuthURLCapture()
  let coordinator = GmailOAuthAuthorizationCoordinator(
    configuration: configuration,
    fetcher: fetcher,
    openURL: { url in
      Task {
        await capture.set(url)
        guard let state = queryValue("state", in: url),
          var callback = URLComponents(url: redirect, resolvingAgainstBaseURL: false)
        else { return }
        callback.queryItems = [
          URLQueryItem(name: "state", value: state),
          URLQueryItem(name: "code", value: "authorization-code"),
        ]
        guard let callbackURL = callback.url else { return }
        var request = URLRequest(url: callbackURL)
        request.httpMethod = "GET"
        _ = try? await URLSession.shared.data(for: request)
      }
      return true
    })

  _ = try await coordinator.authorize()
  let authorizationURL = await capture.value
  #expect(authorizationURL != nil)
  #expect(queryValue("client_secret", in: authorizationURL!) == nil)

  let requests = await fetcher.requests
  let body = String(data: requests[0].httpBody ?? Data(), encoding: .utf8) ?? ""
  #expect(body.contains("client_secret=desktop-client-secret"))
}

@Test
func gmailOAuthRejectsMultilineClientSecret() {
  #expect(throws: ProductivityError.self) {
    _ = try GmailOAuthConfiguration(
      clientID: "desktop-client.apps.googleusercontent.com",
      clientSecret: "secret\nleak")
  }
}

@Test
func gmailOAuthRejectsStateMismatchBeforeTokenExchange() async throws {
  let redirect = URL(string: "http://127.0.0.1:48082/oauth2callback")!
  let configuration = try GmailOAuthConfiguration(
    clientID: "desktop-client.apps.googleusercontent.com", redirectURI: redirect)
  let fetcher = OAuthHTTPFetcherFake(
    payload: Data(#"{"access_token":"never-used"}"#.utf8))
  let coordinator = GmailOAuthAuthorizationCoordinator(
    configuration: configuration,
    fetcher: fetcher,
    openURL: { url in
      Task {
        guard var callback = URLComponents(
          url: redirect, resolvingAgainstBaseURL: false)
        else { return }
        callback.queryItems = [
          URLQueryItem(name: "state", value: "wrong-state"),
          URLQueryItem(name: "code", value: "authorization-code"),
        ]
        guard let callbackURL = callback.url else { return }
        var request = URLRequest(url: callbackURL)
        request.httpMethod = "GET"
        _ = try? await URLSession.shared.data(for: request)
      }
      return true
    })

  await #expect(throws: ProductivityError.self) {
    _ = try await coordinator.authorize()
  }
  #expect(await fetcher.requests.isEmpty)
}

@Test
func gmailOAuthClassifiesTokenRejectionWithoutProviderDescription() async throws {
  let redirect = URL(string: "http://127.0.0.1:48083/oauth2callback")!
  let configuration = try GmailOAuthConfiguration(
    clientID: "desktop-client.apps.googleusercontent.com", redirectURI: redirect)
  let fetcher = OAuthHTTPFetcherFake(
    payload: Data(
      #"{"error":"invalid_grant","error_description":"authorization-code-secret"}"#.utf8),
    responseStatus: 400)
  let coordinator = GmailOAuthAuthorizationCoordinator(
    configuration: configuration,
    fetcher: fetcher,
    openURL: { url in
      Task {
        guard let state = queryValue("state", in: url),
          var callback = URLComponents(url: redirect, resolvingAgainstBaseURL: false)
        else { return }
        callback.queryItems = [
          URLQueryItem(name: "state", value: state),
          URLQueryItem(name: "code", value: "authorization-code"),
        ]
        guard let callbackURL = callback.url else { return }
        var request = URLRequest(url: callbackURL)
        request.httpMethod = "GET"
        _ = try? await URLSession.shared.data(for: request)
      }
      return true
    })

  await #expect(throws: ProductivityError.oauthTokenExchangeRejected(.invalidGrant)) {
    _ = try await coordinator.authorize()
  }
  #expect(
    ProductivityRedaction.diagnostic(
      for: .oauthTokenExchangeRejected(.invalidGrant))
      == "the OAuth token exchange was rejected: invalid_grant")
}

@Test
func gmailOAuthClassifiesRequiredClientSecretWithoutEchoingDescription() async throws {
  let redirect = URL(string: "http://127.0.0.1:48084/oauth2callback")!
  let configuration = try GmailOAuthConfiguration(
    clientID: "desktop-client.apps.googleusercontent.com", redirectURI: redirect)
  let fetcher = OAuthHTTPFetcherFake(
    payload: Data(
      #"{"error":"invalid_request","error_description":"client_secret is missing; private-value"}"#.utf8),
    responseStatus: 400)
  let coordinator = GmailOAuthAuthorizationCoordinator(
    configuration: configuration,
    fetcher: fetcher,
    openURL: { url in
      Task {
        guard let state = queryValue("state", in: url),
          var callback = URLComponents(url: redirect, resolvingAgainstBaseURL: false)
        else { return }
        callback.queryItems = [
          URLQueryItem(name: "state", value: state),
          URLQueryItem(name: "code", value: "authorization-code"),
        ]
        guard let callbackURL = callback.url else { return }
        var request = URLRequest(url: callbackURL)
        request.httpMethod = "GET"
        _ = try? await URLSession.shared.data(for: request)
      }
      return true
    })

  await #expect(
    throws: ProductivityError.oauthTokenExchangeRejected(.clientSecretRequired)
  ) {
    _ = try await coordinator.authorize()
  }
  let diagnostic = ProductivityRedaction.diagnostic(
    for: .oauthTokenExchangeRejected(.clientSecretRequired))
  #expect(diagnostic.contains("client_secret_required"))
  #expect(diagnostic.contains("private-value") == false)
}

@Test
func gmailOAuthConfigurationRejectsNonLoopbackRedirect() {
  #expect(throws: ProductivityError.self) {
    _ = try GmailOAuthConfiguration(
      clientID: "desktop-client.apps.googleusercontent.com",
      redirectURI: URL(string: "http://192.168.1.20:48080/oauth2callback")!)
  }
}
