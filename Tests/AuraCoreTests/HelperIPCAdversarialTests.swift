import Foundation
import Testing

@testable import AuraCore

private let helperIssuedAt = Date(timeIntervalSince1970: 1_000)
private let sharedSecret = Data("test-helper-shared-secret-0123456789".utf8)

// MARK: - Client fail-closed behavior (no real helper launch)

@Test
func clientRejectsMissingExecutable() async {
  let url = URL(fileURLWithPath: "/nonexistent/helper")
  let client = try? HelperIPCClient(
    helperKind: .shell,
    executableURL: url,
    expectedSHA256Hex: String(repeating: "a", count: 64),
    designatedRequirement: "identifier \"com.aura.helper\"",
    sharedSecret: sharedSecret,
    peerVerifier: StaticHelperIPCPeerVerifier(result: true))
  #expect(client != nil)
  do {
    let _: String = try await client!.execute(
      capability: .shellExec,
      actor: .agentCodex,
      target: PolicyTarget(command: "/bin/echo", arguments: ["safe"]),
      payload: Data("echo-safe".utf8),
      issuedAt: helperIssuedAt)
    Issue.record("client unexpectedly succeeded with a missing executable")
  } catch {
    #expect(error == .invalidConfiguration("helper executable is unreadable: /nonexistent/helper"))
  }
}

@Test
func clientRejectsInvalidSHA256() async {
  let url = URL(fileURLWithPath: "/bin/echo")
  let client = try? HelperIPCClient(
    helperKind: .shell,
    executableURL: url,
    expectedSHA256Hex: "not-a-valid-hash",
    designatedRequirement: "identifier \"com.aura.helper\"",
    sharedSecret: sharedSecret,
    peerVerifier: StaticHelperIPCPeerVerifier(result: true))
  #expect(client != nil)
  do {
    let _: String = try await client!.execute(
      capability: .shellExec,
      actor: .agentCodex,
      target: PolicyTarget(command: "/bin/echo", arguments: ["safe"]),
      payload: Data("echo-safe".utf8),
      issuedAt: helperIssuedAt)
    Issue.record("client unexpectedly succeeded with an invalid SHA-256")
  } catch {
    #expect(error == .invalidConfiguration("invalid helper SHA-256 digest"))
  }
}

// MARK: - Replay protection

@Test
func replayGuardRejectsReplayedNonce() async throws {
  let guardStore = HelperIPCReplayGuard()
  let request = HelperIPCRequestEnvelope(
    helperKind: .shell,
    capability: .shellExec,
    actor: .agentCodex,
    target: PolicyTarget(command: "/bin/echo", arguments: ["safe"]),
    payload: Data("echo-safe".utf8),
    issuedAt: helperIssuedAt,
    expiresAt: helperIssuedAt.addingTimeInterval(10))
  try await guardStore.consume(request, expectedHelper: .shell, now: helperIssuedAt)
  do {
    try await guardStore.consume(
      request, expectedHelper: .shell, now: helperIssuedAt.addingTimeInterval(1))
    Issue.record("replay guard accepted a replayed nonce")
  } catch {
    #expect(error == .securityError("helper IPC nonce replay detected"))
  }
}

// MARK: - Downgrade / protocol version

@Test
func validatorRejectsDowngradedProtocolVersion() {
  let request = HelperIPCRequestEnvelope(
    helperKind: .shell,
    capability: .shellExec,
    actor: .agentCodex,
    target: PolicyTarget(command: "/bin/echo", arguments: ["safe"]),
    payload: Data("echo-safe".utf8),
    issuedAt: helperIssuedAt,
    expiresAt: helperIssuedAt.addingTimeInterval(10))
  // Force a downgraded protocol version.
  let downgraded = HelperIPCRequestEnvelope(
    header: HelperIPCRequestHeader(
      protocolVersion: 1,
      requestID: request.header.requestID,
      nonce: request.header.nonce,
      helperKind: .shell,
      capability: .shellExec,
      actor: .agentCodex,
      target: PolicyTarget(command: "/bin/echo", arguments: ["safe"]),
      planHash: request.header.planHash,
      issuedAt: helperIssuedAt,
      expiresAt: helperIssuedAt.addingTimeInterval(10),
      payloadSHA256Hex: request.header.payloadSHA256Hex),
    payload: request.payload)
  #expect(throws: AuraError.self) {
    try HelperIPCValidator.validate(downgraded, expectedHelper: .shell, now: helperIssuedAt)
  }
}

// MARK: - Identity mismatch

@Test
func clientRejectsPeerIdentityMismatch() async throws {
  // A helper that exists and matches the expected SHA-256, but whose peer
  // identity verification fails, must be rejected before any exchange.
  let url = URL(fileURLWithPath: "/bin/echo")
  let data = try Data(contentsOf: url)
  let digest = sha256Hex(data)
  let client = try HelperIPCClient(
    helperKind: .shell,
    executableURL: url,
    expectedSHA256Hex: digest,
    designatedRequirement: "identifier \"com.aura.helper\"",
    sharedSecret: sharedSecret,
    peerVerifier: StaticHelperIPCPeerVerifier(result: false))
  do {
    let _: String = try await client.execute(
      capability: .shellExec,
      actor: .agentCodex,
      target: PolicyTarget(command: "/bin/echo", arguments: ["safe"]),
      payload: Data("echo-safe".utf8),
      issuedAt: helperIssuedAt)
    Issue.record("client unexpectedly accepted a peer identity mismatch")
  } catch {
    #expect(error == .securityError("helper IPC peer identity verification failed"))
  }
}

// MARK: - Helper crash containment

@Test
func clientFailsClosedWhenHelperCrashes() async throws {
  // A helper that exits immediately with a non-zero status must produce a
  // fail-closed error, not a hang or a partial result.
  let url = URL(fileURLWithPath: "/usr/bin/false")
  let data = try Data(contentsOf: url)
  let digest = sha256Hex(data)
  let client = try HelperIPCClient(
    helperKind: .shell,
    executableURL: url,
    expectedSHA256Hex: digest,
    designatedRequirement: "identifier \"com.aura.helper\"",
    sharedSecret: sharedSecret,
    peerVerifier: StaticHelperIPCPeerVerifier(result: true),
    launchTimeoutSeconds: 2)
  do {
    let _: String = try await client.execute(
      capability: .shellExec,
      actor: .agentCodex,
      target: PolicyTarget(command: "/bin/echo", arguments: ["safe"]),
      payload: Data("echo-safe".utf8),
      issuedAt: helperIssuedAt)
    Issue.record("client unexpectedly succeeded with a crashing helper")
  } catch {
    // Either the helper exited non-zero (empty response / non-zero status) or
    // the exchange failed; both are fail-closed security errors.
    #expect(error == .securityError("helper IPC failed with exit status 1"))
  }
}

// MARK: - Capability escalation

@Test
func validatorRejectsCapabilityEscalationAcrossHelperKinds() {
  let request = HelperIPCRequestEnvelope(
    helperKind: .automation,
    capability: .secretRetrieve,
    actor: .automation,
    target: .empty,
    payload: Data(),
    issuedAt: helperIssuedAt,
    expiresAt: helperIssuedAt.addingTimeInterval(10))
  #expect(throws: AuraError.self) {
    try HelperIPCValidator.validate(request, expectedHelper: .automation, now: helperIssuedAt)
  }
}
