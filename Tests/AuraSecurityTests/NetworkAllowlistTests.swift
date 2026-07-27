import AuraCore
import AuraSecurity
import Foundation
import Testing

@Test
func emptyAllowlistDeniesEverything() {
  let allowlist = NetworkAllowlist(allowedHosts: [])
  #expect(!allowlist.isAllowed(host: "example.com"))
  #expect(!allowlist.isAllowed(host: "127.0.0.1"))
}

@Test
func exactHostMatchIsAllowed() {
  let allowlist = NetworkAllowlist(allowedHosts: ["api.example.com"])
  #expect(allowlist.isAllowed(host: "api.example.com"))
  #expect(allowlist.isAllowed(host: "API.EXAMPLE.COM"))
}

@Test
func unlistedHostIsDenied() {
  let allowlist = NetworkAllowlist(allowedHosts: ["api.example.com"])
  #expect(!allowlist.isAllowed(host: "evil.example.com"))
  #expect(!allowlist.isAllowed(host: "example.com"))
}

@Test
func wildcardSubdomainMatchesSubdomainsAndBareDomain() {
  let allowlist = NetworkAllowlist(allowedHosts: ["*.githubusercontent.com"])
  #expect(allowlist.isAllowed(host: "raw.githubusercontent.com"))
  #expect(allowlist.isAllowed(host: "githubusercontent.com"))
  #expect(!allowlist.isAllowed(host: "notgithubusercontent.com"))
  #expect(!allowlist.isAllowed(host: "githubusercontent.com.evil.example"))
}

@Test
func wildcardDoesNotFalsePositiveOnSuffixCollision() {
  // "evilgithubusercontent.com" shares a suffix with the wildcard's bare
  // domain but is not a subdomain of it — must be rejected.
  let allowlist = NetworkAllowlist(allowedHosts: ["*.githubusercontent.com"])
  #expect(!allowlist.isAllowed(host: "evilgithubusercontent.com"))
}

@Test
func configurationInitializerReadsSecurityConfiguration() {
  var config = SecurityConfiguration()
  config.networkAllowlist = ["ollama.local"]
  let allowlist = NetworkAllowlist(configuration: config)
  #expect(allowlist.isAllowed(host: "ollama.local"))
  #expect(!allowlist.isAllowed(host: "attacker.example"))
}
