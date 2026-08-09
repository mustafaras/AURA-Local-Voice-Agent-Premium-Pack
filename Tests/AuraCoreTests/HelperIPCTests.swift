import Foundation
import Testing
@testable import AuraCore

private let helperIssuedAt = Date(timeIntervalSince1970: 1_000)

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

@Test
func helperIPCValidRequestBindsPlanPayloadAndFreshness() throws {
  let request = shellRequest()
  try HelperIPCValidator.validate(request, expectedHelper: .shell, now: helperIssuedAt.addingTimeInterval(1))

  #expect(request.header.planHash.count == 64)
  #expect(request.header.payloadSHA256Hex == sha256Hex(request.payload))
}

@Test
func helperIPCDeniesCapabilityEscalationAcrossHelperKinds() {
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

@Test
func helperIPCRejectsExpiredTamperedAndWrongKindRequests() throws {
  let expired = shellRequest(expiresAt: helperIssuedAt.addingTimeInterval(1))
  #expect(throws: AuraError.self) {
    try HelperIPCValidator.validate(expired, expectedHelper: .shell, now: helperIssuedAt.addingTimeInterval(2))
  }

  let original = shellRequest()
  let tamperedPayload = Data("echo-unsafe".utf8)
  let tampered = HelperIPCRequestEnvelope(header: original.header, payload: tamperedPayload)
  #expect(throws: AuraError.self) {
    try HelperIPCValidator.validate(tampered, expectedHelper: .shell, now: helperIssuedAt)
  }
  #expect(throws: AuraError.self) {
    try HelperIPCValidator.validate(original, expectedHelper: .automation, now: helperIssuedAt)
  }
}

@Test
func helperIPCReplayGuardConsumesNonceExactlyOnce() async throws {
  let guardStore = HelperIPCReplayGuard()
  let request = shellRequest()
  try await guardStore.consume(request, expectedHelper: .shell, now: helperIssuedAt)
  do {
    try await guardStore.consume(request, expectedHelper: .shell, now: helperIssuedAt.addingTimeInterval(1))
    Issue.record("helper IPC nonce replay unexpectedly succeeded")
  } catch {
    #expect(error == .securityError("helper IPC nonce replay detected"))
  }
}

@Test
func helperIPCResponseMustBindRequestAndPayload() throws {
  let request = shellRequest()
  let response = HelperIPCResponseEnvelope(
    request: request, sandboxAttested: true, payload: Data("ok".utf8))
  try HelperIPCValidator.validate(
    response, for: request, expectedHelper: .shell, now: helperIssuedAt)

  let wrongRequest = shellRequest(payload: Data("different".utf8))
  #expect(throws: AuraError.self) {
    try HelperIPCValidator.validate(
      response, for: wrongRequest, expectedHelper: .shell, now: helperIssuedAt)
  }
}
