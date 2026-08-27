import AuraSecurity
import Foundation
import Testing

// MARK: - URLSessionFactory

@Test
func factorySessionDisablesCookiesAndCache() {
  let session = URLSessionFactory.makeSession()
  #expect(session.configuration.httpShouldSetCookies == false)
  #expect(session.configuration.httpCookieAcceptPolicy == .never)
  #expect(session.configuration.httpCookieStorage == nil)
  #expect(session.configuration.urlCache == nil)
  #expect(
    session.configuration.requestCachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
}

@Test
func factorySessionRefusesRedirectsByDefault() {
  // The factory must install the shared redirect-rejecting delegate so a
  // policy can only ever validate the URL it was handed. The delegate's
  // refusal behavior is exercised through the production clients that use it
  // (URLSessionProviderFetcher / URLSessionOllamaAPIClient); here we assert
  // the factory wires that delegate in by default.
  let session = URLSessionFactory.makeSession()
  #expect(session.delegate === URLSessionFactory.redirectRejectingDelegate)
}

// MARK: - ResolvedIPValidator

@Test
func emptyIPAllowlistDeniesEverything() {
  let validator = ResolvedIPValidator(allowedIPs: [])
  #expect(!validator.isAllowed(ip: "127.0.0.1"))
  #expect(!validator.isAllowed(ip: "::1"))
}

@Test
func exactIPMatchIsAllowed() {
  let validator = ResolvedIPValidator(allowedIPs: ["127.0.0.1", "::1"])
  #expect(validator.isAllowed(ip: "127.0.0.1"))
  #expect(validator.isAllowed(ip: "::1"))
  #expect(!validator.isAllowed(ip: "192.168.1.20"))
}

@Test
func ipv6ZoneIdentifierIsNormalizedAway() {
  let validator = ResolvedIPValidator(allowedIPs: ["fe80::1"])
  #expect(validator.isAllowed(ip: "fe80::1%en0"))
}

@Test
func allAllowedRequiresEveryCandidateToPass() {
  let validator = ResolvedIPValidator(allowedIPs: ["127.0.0.1"])
  #expect(validator.allAllowed(resolvedIPs: ["127.0.0.1"]))
  // A single unexpected address fails the whole set (DNS rebinding defense).
  #expect(!validator.allAllowed(resolvedIPs: ["127.0.0.1", "192.168.1.20"]))
  // An empty resolution is never trusted.
  #expect(!validator.allAllowed(resolvedIPs: []))
}
