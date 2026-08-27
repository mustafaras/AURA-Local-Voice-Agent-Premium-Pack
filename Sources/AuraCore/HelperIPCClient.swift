import Foundation

// MARK: - Authenticated helper client

/// A typed, authenticated, least-privilege client for a parent-launched helper
/// executable.
///
/// This is the production boundary that replaces the application-only echo
/// helpers. It:
///
/// 1. Verifies the helper executable's SHA-256 digest before launch
///    (`verifyHelperIntegrity`), so a substituted binary is rejected.
/// 2. Verifies the launched process's code-signature identity against a
///    designated requirement (`HelperIPCPeerVerifying`), the reviewed
///    equivalent to XPC peer identity.
/// 3. Signs every request with an HMAC-SHA256 tag over the exact transmitted
///    bytes (`HelperIPCAuthenticator`), so a peer that does not hold the
///    shared secret cannot forge a request.
/// 4. Enforces the existing typed envelope rules: protocol version, helper
///    kind, capability allowlist, plan hash, payload hash, freshness, and
///    one-time nonce replay protection.
/// 5. Bounds output and time so a crashed or malicious helper cannot hang or
///    flood the main process (helper crash containment).
///
/// The client is deliberately generic over the payload type so the shell and
/// automation helpers can each carry their own typed payload while sharing the
/// same authentication and containment machinery.
public actor HelperIPCClient {
  private let helperKind: HelperKind
  private let executableURL: URL
  private let expectedSHA256Hex: String
  private let designatedRequirement: String
  private let authenticator: HelperIPCAuthenticator
  private let peerVerifier: any HelperIPCPeerVerifying
  private let replayGuard: HelperIPCReplayGuard
  private let maximumLifetimeSeconds: TimeInterval
  private let maximumOutputBytes: Int
  private let launchTimeoutSeconds: TimeInterval

  public init(
    helperKind: HelperKind,
    executableURL: URL,
    expectedSHA256Hex: String,
    designatedRequirement: String,
    sharedSecret: Data,
    peerVerifier: any HelperIPCPeerVerifying = SecCodeHelperIPCPeerVerifier(),
    maximumLifetimeSeconds: TimeInterval = 30,
    maximumOutputBytes: Int = 1_048_576,
    launchTimeoutSeconds: TimeInterval = 10
  ) throws(AuraError) {
    self.helperKind = helperKind
    self.executableURL = executableURL
    self.expectedSHA256Hex = expectedSHA256Hex
    self.designatedRequirement = designatedRequirement
    self.authenticator = try HelperIPCAuthenticator(sharedSecret: sharedSecret)
    self.peerVerifier = peerVerifier
    self.replayGuard = HelperIPCReplayGuard()
    self.maximumLifetimeSeconds = maximumLifetimeSeconds
    self.maximumOutputBytes = maximumOutputBytes
    self.launchTimeoutSeconds = launchTimeoutSeconds
  }

  /// Execute a typed request against the helper and return the authenticated
  /// response payload. Fails closed on any integrity, identity, authentication,
  /// freshness, replay, or containment violation.
  public func execute<Request: Encodable, Response: Decodable>(
    capability: Capability,
    actor: ActorID,
    target: PolicyTarget,
    payload: Request,
    issuedAt: Date = Date()
  ) async throws(AuraError) -> Response {
    // 1. Verify the helper executable digest before launch.
    try verifyHelperIntegrity(url: executableURL, expectedSHA256Hex: expectedSHA256Hex)

    // 2. Build the typed request envelope.
    let payloadData = try encode(payload)
    let request = HelperIPCRequestEnvelope(
      helperKind: helperKind,
      capability: capability,
      actor: actor,
      target: target,
      payload: payloadData,
      issuedAt: issuedAt,
      expiresAt: issuedAt.addingTimeInterval(maximumLifetimeSeconds))

    // 3. Consume the nonce (replay protection) before launch.
    try await replayGuard.consume(request, expectedHelper: helperKind, now: issuedAt)

    // 4. Sign the request.
    let authenticated = HelperIPCAuthenticatedRequest(
      request: request,
      authenticationTag: authenticator.tag(forText: try HelperIPCCoder.text(for: request)))

    // 5. Launch, verify peer identity, send, and read the bounded response.
    let responseData = try await launchAndExchange(authenticated)

    // 6. Decode and authenticate the response.
    let authenticatedResponse: HelperIPCAuthenticatedResponse
    do {
      authenticatedResponse = try HelperIPCCoder.makeDecoder().decode(
        HelperIPCAuthenticatedResponse.self, from: responseData)
    } catch {
      throw AuraError.securityError("helper IPC response is not a valid authenticated envelope")
    }
    try authenticator.validateResponse(
      authenticatedResponse, for: request, expectedHelper: helperKind, now: Date())
    try HelperIPCValidator.validate(
      authenticatedResponse.response, for: request, expectedHelper: helperKind, now: Date())

    return try decode(authenticatedResponse.response.payload)
  }

  // MARK: - Launch and exchange

  private func launchAndExchange(
    _ authenticated: HelperIPCAuthenticatedRequest
  ) async throws(AuraError) -> Data {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = []
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
      try process.run()
    } catch {
      throw AuraError.securityError("helper IPC launch failed: \(error.localizedDescription)")
    }

    // Verify the launched process's code-signature identity.
    guard peerVerifier.verify(
      processID: process.processIdentifier, designatedRequirement: designatedRequirement)
    else {
      process.terminate()
      throw AuraError.securityError("helper IPC peer identity verification failed")
    }

    // Write the authenticated request and close stdin for EOF.
    let requestData: Data
    do {
      requestData = try HelperIPCCoder.makeEncoder().encode(authenticated)
    } catch {
      process.terminate()
      throw AuraError.serializationError("could not encode helper IPC request")
    }
    inputPipe.fileHandleForWriting.write(requestData)
    inputPipe.fileHandleForWriting.closeFile()

    // Read bounded output with a timeout so a crashed or hung helper cannot
    // block the main process indefinitely (helper crash containment).
    let collector = HelperOutputCollector(limit: maximumOutputBytes)
    let outputHandle = outputPipe.fileHandleForReading
    let errorHandle = errorPipe.fileHandleForReading

    let readTask = Task.detached {
      let data = outputHandle.readDataToEndOfFile()
      collector.append(data)
      _ = errorHandle.readDataToEndOfFile()
    }

    let deadline = Date().addingTimeInterval(launchTimeoutSeconds)
    while process.isRunning && Date() < deadline {
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
    if process.isRunning {
      process.terminate()
      readTask.cancel()
      throw AuraError.securityError("helper IPC execution timed out")
    }
    await readTask.value

    let (data, exceeded) = collector.result()
    guard !exceeded else {
      throw AuraError.securityError("helper IPC response exceeded output bound")
    }
    guard process.terminationStatus == 0 else {
      throw AuraError.securityError(
        "helper IPC failed with exit status \(process.terminationStatus)")
    }
    guard !data.isEmpty else {
      throw AuraError.securityError("helper IPC returned an empty response")
    }
    return data
  }

  // MARK: - Encoding helpers

  private func encode<T: Encodable>(_ value: T) throws(AuraError) -> Data {
    do {
      return try HelperIPCCoder.makeEncoder().encode(value)
    } catch {
      throw AuraError.serializationError("could not encode helper IPC payload")
    }
  }

  private func decode<T: Decodable>(_ data: Data) throws(AuraError) -> T {
    do {
      return try HelperIPCCoder.makeDecoder().decode(T.self, from: data)
    } catch {
      throw AuraError.serializationError("could not decode helper IPC payload")
    }
  }
}

// MARK: - Authenticator response validation

extension HelperIPCAuthenticator {
  /// Validate an authenticated response against the exact request it must bind
  /// to. The tag covers the exact transmitted response bytes, and the response
  /// must echo the request's ID and nonce.
  public func validateResponse(
    _ authenticated: HelperIPCAuthenticatedResponse,
    for request: HelperIPCRequestEnvelope,
    expectedHelper: HelperKind,
    now: Date = Date()
  ) throws(AuraError) {
    let response = authenticated.response
    guard response.header.protocolVersion == HelperIPCProtocol.version,
      response.header.requestID == request.header.requestID,
      response.header.nonce == request.header.nonce,
      response.header.sandboxAttested
    else {
      throw AuraError.securityError("helper IPC response failed request binding or attestation")
    }
    guard constantTimeEquals(
      authenticated.authenticationTag,
      tag(forText: authenticated.responseText))
    else {
      throw AuraError.securityError("helper IPC response authentication failed")
    }
  }
}
