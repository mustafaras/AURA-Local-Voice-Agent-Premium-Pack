import CryptoKit
import Foundation
import Security

// MARK: - Helper IPC authenticated peer identity

/// Stable coder for helper IPC envelope text. The authentication tag covers
/// exactly the transmitted bytes, so both sides sign and verify the same string
/// rather than a re-serialization of the decoded value. This removes every
/// cross-process canonicalization dependency (key order, escaping, date
/// precision, and fields one side does not model).
public enum HelperIPCCoder {
  public static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  public static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  public static func text<P: Encodable>(for payload: P) throws(AuraError) -> String {
    do {
      let data = try makeEncoder().encode(payload)
      guard let text = String(data: data, encoding: .utf8) else {
        throw AuraError.serializationError("could not encode helper IPC envelope")
      }
      return text
    } catch {
      throw AuraError.serializationError("could not encode helper IPC envelope")
    }
  }
}

/// HMAC-SHA256 authenticator for the helper IPC boundary.
///
/// This is the "reviewed equivalent" to OS-authenticated XPC that ADR-044
/// requires: a shared secret (provisioned through the same `SecretStoring`
/// seam as the VS Code and Safari bridges) signs the exact transmitted
/// envelope bytes, so a compromised or spoofed peer that does not hold the
/// secret cannot forge a request or response. The tag covers the exact
/// transmitted JSON text, never a re-encoding, so there is no cross-process
/// canonicalization dependency.
///
/// The secret is never included in Codable payloads, logs, events, or
/// diagnostics; only its presence and the resulting tag are used.
public struct HelperIPCAuthenticator: Sendable {
  private let key: SymmetricKey

  public init(sharedSecret: Data) throws(AuraError) {
    guard !sharedSecret.isEmpty else {
      throw AuraError.securityError("helper IPC shared secret must not be empty")
    }
    self.key = SymmetricKey(data: sharedSecret)
  }

  public func tag(forText text: String) -> String {
    let code = HMAC<SHA256>.authenticationCode(for: Data(text.utf8), using: key)
    return code.map { String(format: "%02x", $0) }.joined()
  }

  public func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
    // Compare the UTF-8 byte counts, never `String.count`. `String.count` is a
    // grapheme count, so a hostile 64-*character* tag containing a multi-byte
    // scalar passes a grapheme-length guard while producing a longer byte array
    // than the computed tag, and indexing the shorter side traps. This check
    // runs before authentication succeeds and its input is attacker-controlled.
    let a = Array(lhs.utf8)
    let b = Array(rhs.utf8)
    guard a.count == b.count else { return false }
    var diff: UInt8 = 0
    for i in a.indices {
      diff |= a[i] ^ b[i]
    }
    return diff == 0
  }
}

/// Authenticated request envelope: the existing typed request plus an HMAC tag
/// over the exact transmitted bytes. The tag binds the helper kind, capability,
/// actor, target, plan hash, payload hash, freshness, and nonce to the shared
/// secret, so peer identity is verified before any execution.
public struct HelperIPCAuthenticatedRequest: Codable, Sendable, Equatable {
  public let request: HelperIPCRequestEnvelope
  public let authenticationTag: String
  /// Exact transmitted JSON text of `request`. The authentication tag is
  /// computed over these bytes, never over a re-encoding of `request`.
  public let requestText: String

  private enum CodingKeys: String, CodingKey {
    case request
    case authenticationTag
  }

  public init(request: HelperIPCRequestEnvelope, authenticationTag: String) {
    self.request = request
    self.authenticationTag = authenticationTag
    self.requestText = (try? HelperIPCCoder.text(for: request)) ?? ""
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let text = try container.decode(String.self, forKey: .request)
    self.requestText = text
    self.request = try HelperIPCCoder.makeDecoder().decode(
      HelperIPCRequestEnvelope.self, from: Data(text.utf8))
    self.authenticationTag = try container.decode(String.self, forKey: .authenticationTag)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(requestText, forKey: .request)
    try container.encode(authenticationTag, forKey: .authenticationTag)
  }
}

/// Authenticated response envelope tied to exactly one request nonce.
public struct HelperIPCAuthenticatedResponse: Codable, Sendable, Equatable {
  public let response: HelperIPCResponseEnvelope
  public let authenticationTag: String
  /// Exact transmitted JSON text of `response`. The authentication tag is
  /// computed over these bytes, never over a re-encoding of `response`.
  public let responseText: String

  private enum CodingKeys: String, CodingKey {
    case response
    case authenticationTag
  }

  public init(response: HelperIPCResponseEnvelope, authenticationTag: String) {
    self.response = response
    self.authenticationTag = authenticationTag
    self.responseText = (try? HelperIPCCoder.text(for: response)) ?? ""
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let text = try container.decode(String.self, forKey: .response)
    self.responseText = text
    self.response = try HelperIPCCoder.makeDecoder().decode(
      HelperIPCResponseEnvelope.self, from: Data(text.utf8))
    self.authenticationTag = try container.decode(String.self, forKey: .authenticationTag)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(responseText, forKey: .response)
    try container.encode(authenticationTag, forKey: .authenticationTag)
  }
}

// MARK: - Peer identity verification (reviewed equivalent to XPC)

/// Verifies the code-signature identity of a helper process. This is the
/// "reviewed equivalent" to XPC peer identity: the helper must be signed with
/// a designated requirement that matches the expected identity, so a
/// substituted or tampered helper binary is rejected even if it holds the
/// shared secret.
public protocol HelperIPCPeerVerifying: Sendable {
  /// Returns `true` iff the process with `processID` satisfies the given
  /// code-signature designated requirement.
  func verify(processID: pid_t, designatedRequirement: String) -> Bool
}

/// Production verifier using the Security framework's `SecCode` APIs.
///
/// `SecCodeCopyGuestWithAttributes` resolves the process's code, then
/// `SecCodeCheckValidity` checks it against a `SecRequirement` built from the
/// designated-requirement string. This is the same mechanism XPC uses to
/// authenticate a peer's code signature, applied to the parent-launched pipe.
public struct SecCodeHelperIPCPeerVerifier: HelperIPCPeerVerifying {
  public init() {}

  public func verify(processID: pid_t, designatedRequirement: String) -> Bool {
    guard !designatedRequirement.isEmpty else { return false }
    var requirement: SecRequirement?
    let reqStatus = SecRequirementCreateWithString(
      designatedRequirement as CFString, SecCSFlags(), &requirement)
    guard reqStatus == errSecSuccess, let requirement else { return false }

    var code: SecCode?
    let attrs = [kSecGuestAttributePid: processID] as CFDictionary
    let copyStatus = SecCodeCopyGuestWithAttributes(
      nil, attrs, SecCSFlags(), &code)
    guard copyStatus == errSecSuccess, let code else { return false }

    let checkStatus = SecCodeCheckValidity(code, SecCSFlags(), requirement)
    return checkStatus == errSecSuccess
  }
}

/// A test seam that always accepts or always rejects, so the client's
/// fail-closed behavior can be exercised without a real signed helper.
public struct StaticHelperIPCPeerVerifier: HelperIPCPeerVerifying {
  private let result: Bool
  public init(result: Bool) {
    self.result = result
  }
  public func verify(processID: pid_t, designatedRequirement: String) -> Bool {
    result
  }
}
