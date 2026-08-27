import Foundation

/// The single, deny-by-default `URLSession` factory for every production
/// network client.
///
/// A client that constructs its own `URLSession` bypasses the cookie, cache,
/// redirect, and offline bounds by construction, so every production
/// `URLSession` must come from here. The factory:
/// - disables cookies (`httpShouldSetCookies = false`,
///   `httpCookieAcceptPolicy = .never`, `httpCookieStorage = nil`);
/// - disables the shared cache (`urlCache = nil`,
///   `requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData`);
/// - refuses redirects by default through a shared redirect-rejecting
///   delegate (a redirect is exactly how an allowlisted host becomes an
///   unallowlisted one, and a policy can only validate a URL it is handed).
///
/// Offline/TLS failures are not decided here: they surface as `URLError`
/// codes that each client maps to its own typed offline/unavailable state
/// (e.g. `ProviderHTTPClient.mapped`), so a user whose network is down is
/// never told their account needs reconnecting.
public enum URLSessionFactory {
  /// Shared redirect-rejecting delegate. Redirects are refused rather than
  /// followed so a policy can only ever validate the URL it was handed.
  public static let redirectRejectingDelegate = RedirectRejectingDelegate()

  /// Build a `URLSession` with cookies and cache disabled and redirects
  /// refused. Pass a custom `delegate` only when the client needs to observe
  /// task events; the default delegate refuses every redirect.
  public static func makeSession(
    delegate: URLSessionTaskDelegate? = nil
  ) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieAcceptPolicy = .never
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return URLSession(
      configuration: configuration,
      delegate: delegate ?? redirectRejectingDelegate,
      delegateQueue: nil)
  }
}

/// Refuses every HTTP redirect. A provider or daemon redirect is exactly how
/// an allowlisted host becomes an unallowlisted one, and a policy can only
/// validate a URL it is handed.
public final class RedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
