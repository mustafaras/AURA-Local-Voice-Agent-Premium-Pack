import AuraCore
import Foundation

extension VSCodeFileBridge {
  public func execute(_ command: VSCodeBridgeCommand) async throws(AuraError)
    -> VSCodeBridgeCommandResult
  {
    let context = try executionContext(for: command)
    let requestNonce = UUID().uuidString
    let envelope = try context.authenticator.makeCommandEnvelope(
      command: command, extensionID: context.extensionID, nonce: requestNonce,
      lifetimeSeconds: context.timeoutSeconds)
    let data = try encodeCommand(envelope)
    // Record the request time *before* issuing the command so a response the
    // extension writes within the same wall-clock tick is never misread as a
    // stale file. The response must only be newer than the command we just
    // sent, never newer than an arbitrary post-write timestamp.
    let requestDate = Date()
    try writeCommand(data, to: context.commandPath)
    return try await awaitResponse(
      BridgeResponseContext(
        responsePath: context.responsePath, extensionID: context.extensionID,
        requestNonce: requestNonce, timeoutSeconds: context.timeoutSeconds,
        authenticator: context.authenticator),
      requestDate: requestDate)
  }

  private func executionContext(
    for command: VSCodeBridgeCommand
  ) throws(AuraError) -> BridgeExecutionContext {
    guard requireAuthentication else {
      throw AuraError.securityError("unauthenticated VS Code bridge cannot execute commands")
    }
    guard let authenticator else {
      throw AuraError.securityError("VS Code bridge command authentication is not configured")
    }
    guard let extensionID = expectedExtensionID, !extensionID.isEmpty else {
      throw AuraError.invalidConfiguration(
        "VS Code bridge command execution requires an expected extension ID")
    }
    guard let commandPath, let responsePath else {
      throw AuraError.invalidConfiguration("VS Code bridge command paths are not configured")
    }
    guard commandTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("VS Code bridge command timeout must be positive")
    }
    try validate(command: command)
    return BridgeExecutionContext(
      authenticator: authenticator, extensionID: extensionID, commandPath: commandPath,
      responsePath: responsePath, timeoutSeconds: commandTimeoutSeconds)
  }

  private func encodeCommand(
    _ envelope: VSCodeBridgeCommandEnvelope
  ) throws(AuraError) -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    do {
      return try encoder.encode(envelope)
    } catch {
      throw AuraError.vscodeError(
        "could not encode VS Code bridge command: " + error.localizedDescription)
    }
  }

  private func writeCommand(_ data: Data, to path: String) throws(AuraError) {
    do {
      guard data.count <= maxPayloadBytes else {
        throw AuraError.securityError("VS Code bridge command exceeds configured limit")
      }
      try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    } catch let error as AuraError {
      throw error
    } catch {
      throw AuraError.vscodeError(
        "could not write VS Code bridge command: " + error.localizedDescription)
    }
  }

  private func awaitResponse(
    _ context: BridgeResponseContext,
    requestDate: Date
  ) async throws(AuraError) -> VSCodeBridgeCommandResult {
    let deadline = requestDate.addingTimeInterval(context.timeoutSeconds)
    let responseURL = URL(fileURLWithPath: context.responsePath)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    while Date() < deadline {
      guard !Task.isCancelled else {
        throw AuraError.vscodeError("VS Code bridge command was cancelled")
      }
      if let response = try? readResponse(
        context: context, requestDate: requestDate, responseURL: responseURL, decoder: decoder)
      {
        try context.authenticator.validate(
          response, expectedExtensionID: context.extensionID,
          expectedRequestNonce: context.requestNonce)
        try accept(nonce: response.payload.nonce)
        return response.payload.result
      }
      do {
        try await Task.sleep(for: .milliseconds(25))
      } catch {
        throw AuraError.vscodeError("VS Code bridge command was cancelled")
      }
    }
    throw AuraError.vscodeError("VS Code bridge command response timed out")
  }

  private func readResponse(
    context: BridgeResponseContext,
    requestDate: Date,
    responseURL: URL,
    decoder: JSONDecoder
  ) throws -> VSCodeBridgeResponseEnvelope {
    guard FileManager.default.fileExists(atPath: context.responsePath),
      let attributes = try? FileManager.default.attributesOfItem(atPath: context.responsePath),
      let modificationDate = attributes[.modificationDate] as? Date,
      modificationDate >= requestDate,
      let responseData = try? Data(contentsOf: responseURL),
      responseData.count <= maxPayloadBytes
    else {
      throw AuraError.vscodeError("response not ready")
    }
    return try decoder.decode(VSCodeBridgeResponseEnvelope.self, from: responseData)
  }
}
