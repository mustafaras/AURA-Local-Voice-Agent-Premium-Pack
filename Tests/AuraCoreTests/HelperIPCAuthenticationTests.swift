import CryptoKit
import Foundation
import Testing

@testable import AuraCore

private let helperIssuedAt = Date(timeIntervalSince1970: 1_000)
private let sharedSecret = Data("test-helper-shared-secret-0123456789".utf8)

private func makeAuthenticator() throws(AuraError) -> HelperIPCAuthenticator {
  try HelperIPCAuthenticator(sharedSecret: sharedSecret)
}

private func shellRequest(
  payload: Data = Data("echo-safe".utf8),
  expiresAt: Date = helperIssuedAt.addingTimeInterval(10)
) -> HelperIPCRequestEnvelope {
  HelperIPCRequestEnvelope(
    helperKind: .shell,
    capability: .shellExec,
    actor: .agentCodex,
    target: PolicyTarget(command: "/bin/echo", arguments: ["safe"]),
    payload: payload,
    issuedAt: helperIssuedAt,
    expiresAt: expiresAt)
}

// MARK: - Authenticator

@Test
func authenticatorRejectsEmptySecret() {
  #expect(throws: AuraError.self) {
    _ = try HelperIPCAuthenticator(sharedSecret: Data())
  }
}

@Test
func authenticatorProducesStableTagForSameText() throws {
  let a = try makeAuthenticator()
  let b = try makeAuthenticator()
  #expect(a.tag(forText: "hello") == b.tag(forText: "hello"))
  #expect(a.tag(forText: "hello") != a.tag(forText: "world"))
}

@Test
func authenticatorConstantTimeEqualsDetectsMismatch() throws {
  let a = try makeAuthenticator()
  #expect(a.constantTimeEquals("abc", "abc"))
  #expect(!a.constantTimeEquals("abc", "abd"))
  #expect(!a.constantTimeEquals("abc", "abcd"))
}

// MARK: - Authenticated request/response envelopes

@Test
func authenticatedRequestRoundTripsExactText() throws {
  let request = shellRequest()
  let auth = try makeAuthenticator()
  let envelope = HelperIPCAuthenticatedRequest(
    request: request,
    authenticationTag: auth.tag(forText: try HelperIPCCoder.text(for: request)))

  let data = try HelperIPCCoder.makeEncoder().encode(envelope)
  let decoded = try HelperIPCCoder.makeDecoder().decode(
    HelperIPCAuthenticatedRequest.self, from: data)

  #expect(decoded.request == request)
  #expect(decoded.authenticationTag == envelope.authenticationTag)
  #expect(decoded.requestText == envelope.requestText)
}

@Test
func authenticatedResponseRoundTripsExactText() throws {
  let request = shellRequest()
  let response = HelperIPCResponseEnvelope(
    request: request, sandboxAttested: true, payload: Data("ok".utf8))
  let auth = try makeAuthenticator()
  let envelope = HelperIPCAuthenticatedResponse(
    response: response,
    authenticationTag: auth.tag(forText: try HelperIPCCoder.text(for: response)))

  let data = try HelperIPCCoder.makeEncoder().encode(envelope)
  let decoded = try HelperIPCCoder.makeDecoder().decode(
    HelperIPCAuthenticatedResponse.self, from: data)

  #expect(decoded.response == response)
  #expect(decoded.authenticationTag == envelope.authenticationTag)
  #expect(decoded.responseText == envelope.responseText)
}

// MARK: - Authenticator response validation

@Test
func authenticatorRejectsForgedResponseTag() throws {
  let request = shellRequest()
  let response = HelperIPCResponseEnvelope(
    request: request, sandboxAttested: true, payload: Data("ok".utf8))
  let auth = try makeAuthenticator()
  let envelope = HelperIPCAuthenticatedResponse(
    response: response,
    authenticationTag: auth.tag(forText: try HelperIPCCoder.text(for: response)))

  // A different secret produces a different tag, so validation must fail.
  let otherAuth = try HelperIPCAuthenticator(sharedSecret: Data("other-secret".utf8))
  let forged = HelperIPCAuthenticatedResponse(
    response: response,
    authenticationTag: otherAuth.tag(forText: try HelperIPCCoder.text(for: response)))

  #expect(throws: AuraError.self) {
    try auth.validateResponse(forged, for: request, expectedHelper: .shell, now: helperIssuedAt)
  }
  // The genuine envelope validates.
  try auth.validateResponse(envelope, for: request, expectedHelper: .shell, now: helperIssuedAt)
}

@Test
func authenticatorRejectsResponseBoundToDifferentRequest() throws {
  let request = shellRequest()
  let otherRequest = shellRequest(payload: Data("different".utf8))
  let response = HelperIPCResponseEnvelope(
    request: request, sandboxAttested: true, payload: Data("ok".utf8))
  let auth = try makeAuthenticator()
  let envelope = HelperIPCAuthenticatedResponse(
    response: response,
    authenticationTag: auth.tag(forText: try HelperIPCCoder.text(for: response)))

  #expect(throws: AuraError.self) {
    try auth.validateResponse(
      envelope, for: otherRequest, expectedHelper: .shell, now: helperIssuedAt)
  }
}

// MARK: - Peer identity verifier

@Test
func staticPeerVerifierHonorsConfiguredResult() {
  let accept = StaticHelperIPCPeerVerifier(result: true)
  let reject = StaticHelperIPCPeerVerifier(result: false)
  #expect(accept.verify(processID: 1, designatedRequirement: "identifier \"x\""))
  #expect(!reject.verify(processID: 1, designatedRequirement: "identifier \"x\""))
}

@Test
func secCodePeerVerifierRejectsEmptyRequirement() {
  let verifier = SecCodeHelperIPCPeerVerifier()
  #expect(!verifier.verify(processID: getpid(), designatedRequirement: ""))
}
