import AuraCore
import Foundation
import Testing

@testable import AuraVSCode

/// SP-012 cross-language interop guard.
///
/// The deterministic suite previously signed and verified entirely in Swift,
/// so it could not observe that the companion extension canonicalized payloads
/// differently and produced an unverifiable tag. This vector is real output
/// captured from the compiled TypeScript extension, so any future change that
/// breaks the wire contract fails here instead of only in live acceptance.
@Suite("AuraVSCodeBridgeInterop")
struct AuraVSCodeBridgeInteropTests {
  /// Shared secret used only to produce and verify the frozen test vector.
  private static let vectorSecret = "aura-live-acceptance-secret-0001"

  /// Envelope emitted by the compiled extension (`out/authenticator.js`).
  private static let extensionEnvelope = #"""
  {"payload":"{\"protocolVersion\":2,\"extensionID\":\"ai.aura.vscode-bridge\",\"nonce\":\"94a7db28d1b1fb08282a005503f74acb\",\"issuedAt\":\"2026-08-20T17:39:16.767Z\",\"expiresAt\":\"2026-08-20T17:39:46.767Z\",\"snapshot\":{\"editor\":{\"activeFilePath\":\"/Users/m_ras/Desktop/AURA-Local-Voice-Agent-Premium-Pack/README.md\",\"languageID\":\"markdown\",\"isDirty\":false,\"workspaceFolderPaths\":[\"/Users/m_ras/Desktop/AURA-Local-Voice-Agent-Premium-Pack\"]},\"diagnostics\":[],\"timestamp\":\"2026-08-20T17:39:16.766Z\"}}","authenticationTag":"8abDY5XoZ/yCb4Ti350eWL0znQYP6R3FWyZBwS+oTls="}
  """#

  private func decodedEnvelope() throws -> VSCodeBridgeEnvelope {
    let text = Self.extensionEnvelope.trimmingCharacters(in: .whitespacesAndNewlines)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(VSCodeBridgeEnvelope.self, from: Data(text.utf8))
  }

  @Test("Swift authenticates an envelope produced by the TypeScript extension")
  func acceptsExtensionEnvelope() throws {
    let envelope = try decodedEnvelope()
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: Self.vectorSecret)
    // Validate inside the envelope's own freshness window.
    try authenticator.validate(
      envelope,
      expectedExtensionID: "ai.aura.vscode-bridge",
      now: envelope.payload.issuedAt.addingTimeInterval(1))
  }

  @Test("the authentication tag covers the transmitted payload bytes")
  func tagCoversTransmittedBytes() throws {
    let envelope = try decodedEnvelope()
    // The signed text must carry the snapshot; a canonicalization that drops
    // nested content would leave the body unauthenticated.
    #expect(envelope.payloadText.contains("\"snapshot\""))
    #expect(envelope.payloadText.contains("activeFilePath"))
    #expect(envelope.payload.protocolVersion == VSCodeBridgeSignedPayload.currentProtocolVersion)
  }

  @Test("a tampered payload body is rejected")
  func rejectsTamperedBody() throws {
    let envelope = try decodedEnvelope()
    let tamperedText = envelope.payloadText.replacingOccurrences(
      of: "\"isDirty\":false", with: "\"isDirty\":true")
    #expect(tamperedText != envelope.payloadText)
    let tampered = #"{"payload":\#(encodeJSONString(tamperedText)),"authenticationTag":\#(encodeJSONString(envelope.authenticationTag))}"#
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let rebuilt = try decoder.decode(VSCodeBridgeEnvelope.self, from: Data(tampered.utf8))
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: Self.vectorSecret)
    #expect(throws: AuraError.self) {
      try authenticator.validate(
        rebuilt,
        expectedExtensionID: "ai.aura.vscode-bridge",
        now: rebuilt.payload.issuedAt.addingTimeInterval(1))
    }
  }

  @Test("a response that omits empty collection fields still decodes")
  func acceptsResponseOmittingEmptyCollections() throws {
    // The companion extension omits optional/empty collection fields from its
    // response result (diagnostics/tasks/tests/terminals). This is the exact
    // shape it emitted during live acceptance; it must decode to a
    // VSCodeBridgeCommandResult with those collections defaulted to empty.
    let text = #"""
    {"payload":"{\"protocolVersion\":2,\"extensionID\":\"ai.aura.vscode-bridge\",\"nonce\":\"resp-1\",\"issuedAt\":\"2026-08-21T00:00:00Z\",\"expiresAt\":\"2026-08-21T00:01:00Z\",\"requestNonce\":\"req-1\",\"result\":{\"outcome\":\"completed\",\"message\":\"editor state\"}}","authenticationTag":"unused"}
    """#
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(
      VSCodeBridgeResponseEnvelope.self,
      from: Data(text.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
    #expect(envelope.payload.result.outcome == .completed)
    #expect(envelope.payload.result.diagnostics.isEmpty)
    #expect(envelope.payload.result.tasks.isEmpty)
    #expect(envelope.payload.result.tests.isEmpty)
    #expect(envelope.payload.result.terminals.isEmpty)
  }
}

/// Encodes a Swift string as a JSON string literal.
private func encodeJSONString(_ value: String) -> String {
  let data = try? JSONSerialization.data(withJSONObject: [value], options: [])
  guard let data, let text = String(data: data, encoding: .utf8) else { return "\"\"" }
  return String(text.dropFirst().dropLast())
}
