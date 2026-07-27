import AuraCore
import AuraSecurity
import Foundation
import Testing

@Test
func scannerDetectsOpenAIStyleKey() {
  let scanner = SecretScanner()
  let token = "sk-" + String(repeating: "a", count: 48)
  let matches = scanner.scan("api_key=\(token)")
  #expect(matches.contains { $0.patternName == "openaiStyleKey" })
}

@Test
func scannerDetectsGitHubToken() {
  let scanner = SecretScanner()
  let token = "ghp_" + String(repeating: "a", count: 36)
  #expect(scanner.containsSecret(token))
}

@Test
func scannerDetectsAWSAccessKey() {
  let scanner = SecretScanner()
  // Constructed at runtime so no real-looking AWS access key literal lives in source.
  let fixture = "AKIA" + String(repeating: "A", count: 16)
  #expect(scanner.containsSecret(fixture))
}

@Test
func scannerDetectsPrivateKeyBlock() {
  let scanner = SecretScanner()
  #expect(scanner.containsSecret("-----BEGIN RSA PRIVATE KEY-----\nMIIB...\n-----END RSA PRIVATE KEY-----"))
}

@Test
func scannerDetectsJWT() {
  let scanner = SecretScanner()
  let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
  #expect(scanner.containsSecret(jwt))
}

@Test
func scannerDetectsHex40() {
  let scanner = SecretScanner()
  #expect(scanner.containsSecret(String(repeating: "a", count: 40)))
}

@Test
func scannerReportsNoMatchesForBenignText() {
  let scanner = SecretScanner()
  #expect(scanner.scan("This is a normal sentence about the weather.").isEmpty)
  #expect(!scanner.containsSecret("just some regular log output"))
}

@Test
func scannerReportsEmptyForEmptyInput() {
  let scanner = SecretScanner()
  #expect(scanner.scan("").isEmpty)
}

// MARK: - Consistency with OutputRedactor/RepositoryInstructionsScanner

@Test
func scannerAndOutputRedactorAgreeOnDetection() {
  let scanner = SecretScanner()
  let token = "sk-" + String(repeating: "b", count: 48)
  let text = "token=\(token)"
  #expect(scanner.containsSecret(text))
  #expect(OutputRedactor.default.redact(text) != text)
}
