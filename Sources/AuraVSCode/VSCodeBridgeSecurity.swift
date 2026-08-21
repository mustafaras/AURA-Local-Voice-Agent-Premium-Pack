import AuraCore
import CryptoKit
import Foundation

private struct VSCodeEnvelopeValidationInput {
  let protocolVersion: Int
  let extensionID: String
  let nonce: String
  let issuedAt: Date
  let expiresAt: Date
  let authenticationTag: String
  /// Transmitted payload bytes the tag must cover.
  let payloadText: String
  let expectedExtensionID: String?
  let now: Date
  let clockSkewSeconds: Double
}

/// Shared coder for bridge payload text. The authentication tag covers exactly
/// the transmitted payload bytes, so both sides sign and verify the same string
/// rather than a re-serialization of the decoded value. This removes every
/// cross-language canonicalization dependency (key order, escaping, date
/// precision, and fields one side does not model).
enum VSCodeBridgePayloadCoder {
  static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  static func text<P: Encodable>(for payload: P) throws(AuraError) -> String {
    do {
      let data = try makeEncoder().encode(payload)
      guard let text = String(data: data, encoding: .utf8) else {
        throw AuraError.serializationError("could not encode VS Code bridge payload")
      }
      return text
    } catch {
      throw AuraError.serializationError("could not encode VS Code bridge payload")
    }
  }
}

/// Versioned, authenticated payload written by the companion VS Code
/// extension. The bridge carries observations only; it never carries raw shell
/// commands or authority to bypass AURA policy.
public struct VSCodeBridgeSignedPayload: Codable, Sendable, Equatable {
  public static let currentProtocolVersion = 2

  public let protocolVersion: Int
  public let extensionID: String
  public let nonce: String
  public let issuedAt: Date
  public let expiresAt: Date
  public let snapshot: VSCodeBridgeSnapshot

  public init(
    protocolVersion: Int = VSCodeBridgeSignedPayload.currentProtocolVersion,
    extensionID: String,
    nonce: String,
    issuedAt: Date,
    expiresAt: Date,
    snapshot: VSCodeBridgeSnapshot
  ) {
    self.protocolVersion = protocolVersion
    self.extensionID = extensionID
    self.nonce = nonce
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.snapshot = snapshot
  }
}

public struct VSCodeBridgeEnvelope: Codable, Sendable, Equatable {
  public let payload: VSCodeBridgeSignedPayload
  public let authenticationTag: String
  /// Exact transmitted JSON text of `payload`. The authentication tag is
  /// computed over these bytes, never over a re-encoding of `payload`.
  public let payloadText: String

  private enum CodingKeys: String, CodingKey {
    case payload
    case authenticationTag
  }

  public init(payload: VSCodeBridgeSignedPayload, authenticationTag: String) {
    self.payload = payload
    self.authenticationTag = authenticationTag
    self.payloadText = (try? VSCodeBridgePayloadCoder.text(for: payload)) ?? ""
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let text = try container.decode(String.self, forKey: .payload)
    self.payloadText = text
    self.payload = try VSCodeBridgePayloadCoder.makeDecoder()
      .decode(VSCodeBridgeSignedPayload.self, from: Data(text.utf8))
    self.authenticationTag = try container.decode(String.self, forKey: .authenticationTag)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(payloadText, forKey: .payload)
    try container.encode(authenticationTag, forKey: .authenticationTag)
  }
}

/// Authenticated request carrying one command from AURA to the extension.
/// The command is an enum-backed DTO; it is never a shell string or arbitrary
/// extension command identifier.
public struct VSCodeBridgeCommandPayload: Codable, Sendable, Equatable {
  public let protocolVersion: Int
  public let extensionID: String
  public let nonce: String
  public let issuedAt: Date
  public let expiresAt: Date
  public let command: VSCodeBridgeCommand

  public init(
    protocolVersion: Int = VSCodeBridgeSignedPayload.currentProtocolVersion,
    extensionID: String,
    nonce: String,
    issuedAt: Date,
    expiresAt: Date,
    command: VSCodeBridgeCommand
  ) {
    self.protocolVersion = protocolVersion
    self.extensionID = extensionID
    self.nonce = nonce
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.command = command
  }
}

public struct VSCodeBridgeCommandEnvelope: Codable, Sendable, Equatable {
  public let payload: VSCodeBridgeCommandPayload
  public let authenticationTag: String
  /// Exact transmitted JSON text of `payload`. The authentication tag is
  /// computed over these bytes, never over a re-encoding of `payload`.
  public let payloadText: String

  private enum CodingKeys: String, CodingKey {
    case payload
    case authenticationTag
  }

  public init(payload: VSCodeBridgeCommandPayload, authenticationTag: String) {
    self.payload = payload
    self.authenticationTag = authenticationTag
    self.payloadText = (try? VSCodeBridgePayloadCoder.text(for: payload)) ?? ""
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let text = try container.decode(String.self, forKey: .payload)
    self.payloadText = text
    self.payload = try VSCodeBridgePayloadCoder.makeDecoder()
      .decode(VSCodeBridgeCommandPayload.self, from: Data(text.utf8))
    self.authenticationTag = try container.decode(String.self, forKey: .authenticationTag)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(payloadText, forKey: .payload)
    try container.encode(authenticationTag, forKey: .authenticationTag)
  }
}

/// Authenticated response tied to exactly one request nonce.
public struct VSCodeBridgeResponsePayload: Codable, Sendable, Equatable {
  public let protocolVersion: Int
  public let extensionID: String
  public let requestNonce: String
  public let nonce: String
  public let issuedAt: Date
  public let expiresAt: Date
  public let result: VSCodeBridgeCommandResult

  public init(
    protocolVersion: Int = VSCodeBridgeSignedPayload.currentProtocolVersion,
    extensionID: String,
    requestNonce: String,
    nonce: String,
    issuedAt: Date,
    expiresAt: Date,
    result: VSCodeBridgeCommandResult
  ) {
    self.protocolVersion = protocolVersion
    self.extensionID = extensionID
    self.requestNonce = requestNonce
    self.nonce = nonce
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.result = result
  }
}

public struct VSCodeBridgeResponseEnvelope: Codable, Sendable, Equatable {
  public let payload: VSCodeBridgeResponsePayload
  public let authenticationTag: String
  /// Exact transmitted JSON text of `payload`. The authentication tag is
  /// computed over these bytes, never over a re-encoding of `payload`.
  public let payloadText: String

  private enum CodingKeys: String, CodingKey {
    case payload
    case authenticationTag
  }

  public init(payload: VSCodeBridgeResponsePayload, authenticationTag: String) {
    self.payload = payload
    self.authenticationTag = authenticationTag
    self.payloadText = (try? VSCodeBridgePayloadCoder.text(for: payload)) ?? ""
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let text = try container.decode(String.self, forKey: .payload)
    self.payloadText = text
    self.payload = try VSCodeBridgePayloadCoder.makeDecoder()
      .decode(VSCodeBridgeResponsePayload.self, from: Data(text.utf8))
    self.authenticationTag = try container.decode(String.self, forKey: .authenticationTag)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(payloadText, forKey: .payload)
    try container.encode(authenticationTag, forKey: .authenticationTag)
  }
}

/// HMAC authenticator for the local bridge. The shared secret is supplied by
/// the caller and is never included in Codable payloads, logs, or diagnostics.
public struct VSCodeBridgeAuthenticator: Sendable {
  private let key: SymmetricKey

  public init(sharedSecret: String) throws(AuraError) {
    guard !sharedSecret.isEmpty else {
      throw AuraError.securityError("VS Code bridge shared secret must not be empty")
    }
    self.key = SymmetricKey(data: Data(sharedSecret.utf8))
  }

  public func makeEnvelope(
    snapshot: VSCodeBridgeSnapshot,
    extensionID: String,
    nonce: String,
    issuedAt: Date = Date(),
    lifetimeSeconds: Double = 30
  ) throws(AuraError) -> VSCodeBridgeEnvelope {
    guard !extensionID.isEmpty, !nonce.isEmpty else {
      throw AuraError.securityError("VS Code bridge extension ID and nonce are required")
    }
    guard lifetimeSeconds > 0 else {
      throw AuraError.invalidConfiguration("VS Code bridge lifetime must be positive")
    }
    let payload = VSCodeBridgeSignedPayload(
      extensionID: extensionID,
      nonce: nonce,
      issuedAt: issuedAt,
      expiresAt: issuedAt.addingTimeInterval(lifetimeSeconds),
      snapshot: snapshot
    )
    return VSCodeBridgeEnvelope(
      payload: payload,
      authenticationTag: tag(forText: try VSCodeBridgePayloadCoder.text(for: payload))
    )
  }

  public func validate(
    _ envelope: VSCodeBridgeEnvelope,
    expectedExtensionID: String?,
    now: Date = Date(),
    clockSkewSeconds: Double = 5
  ) throws(AuraError) {
    let payload = envelope.payload
    guard payload.protocolVersion == VSCodeBridgeSignedPayload.currentProtocolVersion else {
      throw AuraError.securityError("unsupported VS Code bridge protocol version")
    }
    if let expectedExtensionID {
      guard payload.extensionID == expectedExtensionID else {
        throw AuraError.securityError("unexpected VS Code bridge extension identity")
      }
    }
    guard !payload.nonce.isEmpty else {
      throw AuraError.securityError("VS Code bridge nonce is empty")
    }
    guard payload.expiresAt > payload.issuedAt else {
      throw AuraError.securityError("VS Code bridge envelope expiry is invalid")
    }
    guard payload.issuedAt <= now.addingTimeInterval(clockSkewSeconds) else {
      throw AuraError.securityError("VS Code bridge envelope is issued in the future")
    }
    guard payload.expiresAt > now else {
      throw AuraError.securityError("VS Code bridge envelope is expired")
    }
    guard constantTimeEquals(envelope.authenticationTag, tag(forText: envelope.payloadText))
    else {
      throw AuraError.securityError("VS Code bridge authentication failed")
    }
  }

  public func makeCommandEnvelope(
    command: VSCodeBridgeCommand,
    extensionID: String,
    nonce: String,
    issuedAt: Date = Date(),
    lifetimeSeconds: Double = 30
  ) throws(AuraError) -> VSCodeBridgeCommandEnvelope {
    guard !extensionID.isEmpty, !nonce.isEmpty else {
      throw AuraError.securityError("VS Code bridge command identity and nonce are required")
    }
    guard lifetimeSeconds > 0 else {
      throw AuraError.invalidConfiguration("VS Code bridge command lifetime must be positive")
    }
    let payload = VSCodeBridgeCommandPayload(
      extensionID: extensionID,
      nonce: nonce,
      issuedAt: issuedAt,
      expiresAt: issuedAt.addingTimeInterval(lifetimeSeconds),
      command: command
    )
    return VSCodeBridgeCommandEnvelope(
      payload: payload,
      authenticationTag: tag(forText: try VSCodeBridgePayloadCoder.text(for: payload))
    )
  }

  public func makeResponseEnvelope(
    result: VSCodeBridgeCommandResult,
    extensionID: String,
    requestNonce: String,
    nonce: String,
    issuedAt: Date = Date(),
    lifetimeSeconds: Double = 30
  ) throws(AuraError) -> VSCodeBridgeResponseEnvelope {
    guard !extensionID.isEmpty, !requestNonce.isEmpty, !nonce.isEmpty else {
      throw AuraError.securityError("VS Code bridge response identity and nonce are required")
    }
    guard lifetimeSeconds > 0 else {
      throw AuraError.invalidConfiguration("VS Code bridge response lifetime must be positive")
    }
    let payload = VSCodeBridgeResponsePayload(
      extensionID: extensionID,
      requestNonce: requestNonce,
      nonce: nonce,
      issuedAt: issuedAt,
      expiresAt: issuedAt.addingTimeInterval(lifetimeSeconds),
      result: result
    )
    return VSCodeBridgeResponseEnvelope(
      payload: payload,
      authenticationTag: tag(forText: try VSCodeBridgePayloadCoder.text(for: payload))
    )
  }

  public func validate(
    _ envelope: VSCodeBridgeCommandEnvelope,
    expectedExtensionID: String?,
    now: Date = Date(),
    clockSkewSeconds: Double = 5
  ) throws(AuraError) {
    try validateEnvelope(
      VSCodeEnvelopeValidationInput(
        protocolVersion: envelope.payload.protocolVersion,
        extensionID: envelope.payload.extensionID,
        nonce: envelope.payload.nonce,
        issuedAt: envelope.payload.issuedAt,
        expiresAt: envelope.payload.expiresAt,
        authenticationTag: envelope.authenticationTag,
        payloadText: envelope.payloadText,
        expectedExtensionID: expectedExtensionID,
        now: now,
        clockSkewSeconds: clockSkewSeconds
      )
    )
  }

  public func validate(
    _ envelope: VSCodeBridgeResponseEnvelope,
    expectedExtensionID: String?,
    expectedRequestNonce: String,
    now: Date = Date(),
    clockSkewSeconds: Double = 5
  ) throws(AuraError) {
    guard envelope.payload.requestNonce == expectedRequestNonce else {
      throw AuraError.securityError("VS Code bridge response does not match request")
    }
    try validateEnvelope(
      VSCodeEnvelopeValidationInput(
        protocolVersion: envelope.payload.protocolVersion,
        extensionID: envelope.payload.extensionID,
        nonce: envelope.payload.nonce,
        issuedAt: envelope.payload.issuedAt,
        expiresAt: envelope.payload.expiresAt,
        authenticationTag: envelope.authenticationTag,
        payloadText: envelope.payloadText,
        expectedExtensionID: expectedExtensionID,
        now: now,
        clockSkewSeconds: clockSkewSeconds
      )
    )
  }

  private func validateEnvelope(
    _ input: VSCodeEnvelopeValidationInput
  ) throws(AuraError) {
    guard input.protocolVersion == VSCodeBridgeSignedPayload.currentProtocolVersion else {
      throw AuraError.securityError("unsupported VS Code bridge protocol version")
    }
    if let expectedExtensionID = input.expectedExtensionID {
      guard input.extensionID == expectedExtensionID else {
        throw AuraError.securityError("unexpected VS Code bridge extension identity")
      }
    }
    guard !input.nonce.isEmpty else {
      throw AuraError.securityError("VS Code bridge nonce is empty")
    }
    guard input.expiresAt > input.issuedAt else {
      throw AuraError.securityError("VS Code bridge envelope expiry is invalid")
    }
    guard input.issuedAt <= input.now.addingTimeInterval(input.clockSkewSeconds) else {
      throw AuraError.securityError("VS Code bridge envelope is issued in the future")
    }
    guard input.expiresAt > input.now else {
      throw AuraError.securityError("VS Code bridge envelope is expired")
    }
    guard constantTimeEquals(input.authenticationTag, tag(forText: input.payloadText)) else {
      throw AuraError.securityError("VS Code bridge authentication failed")
    }
  }

  /// Authenticates the exact transmitted payload bytes.
  private func tag(forText text: String) -> String {
    let code = HMAC<SHA256>.authenticationCode(for: Data(text.utf8), using: key)
    return Data(code).base64EncodedString()
  }

  /// Compares tags without leaking match position through timing.
  private func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
    let left = Array(lhs.utf8)
    let right = Array(rhs.utf8)
    guard left.count == right.count else { return false }
    var difference: UInt8 = 0
    for index in left.indices {
      difference |= left[index] ^ right[index]
    }
    return difference == 0
  }
}
