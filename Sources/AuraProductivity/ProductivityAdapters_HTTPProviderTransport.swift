import AuraCore
import AuraSecurity
import Foundation

/// The single seam every provider HTTP call goes through.
///
/// It exists so the production transport can be exercised deterministically:
/// tests inject a fetcher that returns recorded provider payloads, and no
/// test ever opens a socket. `URLSessionProviderFetcher` is the only
/// conformer that touches the network.
public protocol HTTPProviderFetching: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Production fetcher. Redirects are refused rather than followed: a provider
/// redirect is exactly how an allowlisted host becomes an unallowlisted one,
/// and `ProductivityNetworkPolicy` can only validate a URL it is handed.
///
/// The `URLSession` is built by the mandatory `URLSessionFactory`, so cookies
/// and cache are disabled and redirects are refused by construction — a
/// provider transport can never construct an ungoverned session.
public final class URLSessionProviderFetcher: NSObject, HTTPProviderFetching, URLSessionTaskDelegate,
  @unchecked Sendable
{
  private let session: URLSession

  public override init() {
    self.session = URLSessionFactory.makeSession()
    super.init()
  }

  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request, delegate: self)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ProductivityError.providerUnavailable
    }
    return (data, httpResponse)
  }

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

/// Shared request construction and failure mapping for provider transports.
///
/// Two properties matter more than the plumbing. First, the bearer token is
/// attached here and nowhere else, and it is never interpolated into a URL,
/// an error, or a thrown message — a failure carries the HTTP status and the
/// host, never the credential. Second, every status maps to a *distinct*
/// `ProductivityError`, because the health surface has to tell "reconnect
/// this account" (401) apart from "the provider is down" (503); collapsing
/// them would make the truthful-capability-health requirement unmeetable.
public struct ProviderHTTPClient: Sendable {
  private let fetcher: any HTTPProviderFetching
  private let networkPolicy: ProductivityNetworkPolicy

  public init(fetcher: any HTTPProviderFetching, networkPolicy: ProductivityNetworkPolicy) {
    self.fetcher = fetcher
    self.networkPolicy = networkPolicy
  }

  public func get(
    url: URL,
    accessToken: String,
    queryItems: [URLQueryItem] = []
  ) async throws(ProductivityError) -> Data {
    let resolved = try resolve(url: url, queryItems: queryItems)
    try networkPolicy.validate(resolved)

    var request = URLRequest(url: resolved)
    request.httpMethod = "GET"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 20

    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await fetcher.data(for: request)
    } catch let error as ProductivityError {
      throw error
    } catch let error as URLError {
      throw Self.mapped(error)
    } catch {
      throw .providerUnavailable
    }
    try Self.validate(status: response.statusCode)
    return data
  }

  private func resolve(
    url: URL,
    queryItems: [URLQueryItem]
  ) throws(ProductivityError) -> URL {
    guard !queryItems.isEmpty else { return url }
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw .invalidInput("provider URL could not be parsed")
    }
    components.queryItems = (components.queryItems ?? []) + queryItems
    guard let resolved = components.url else {
      throw .invalidInput("provider URL could not be composed")
    }
    return resolved
  }

  /// Offline and TLS failures are their own state. A user whose network is
  /// down must not be told their account needs reconnecting.
  static func mapped(_ error: URLError) -> ProductivityError {
    switch error.code {
    case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
      .internationalRoamingOff, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
      .timedOut:
      return .networkUnavailable
    case .cancelled:
      return .cancelled
    case .appTransportSecurityRequiresSecureConnection, .secureConnectionFailed,
      .serverCertificateUntrusted, .serverCertificateHasBadDate,
      .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
      return .providerUnavailable
    case .httpTooManyRedirects, .redirectToNonExistentLocation:
      return .invalidRedirect(host: error.failingURL?.host ?? "unknown")
    default:
      return .providerUnavailable
    }
  }

  static func validate(status: Int) throws(ProductivityError) {
    switch status {
    case 200...299:
      return
    case 401:
      throw .tokenExpiredOrRevoked
    case 403:
      throw .insufficientScope(required: "the provider refused the configured read scope")
    case 404:
      throw .invalidInput("the provider has no such resource")
    default:
      throw .providerUnavailable
    }
  }
}
