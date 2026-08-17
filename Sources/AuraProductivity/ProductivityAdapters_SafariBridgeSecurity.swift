import AuraCore
import CryptoKit
import Foundation

/// Versioned, authenticated observation payload written by the Safari Web
/// Extension and delivered to the containing app through native messaging.
/// The bridge carries observations only; it never carries raw page scripts,
/// cookies, passwords, or authority to bypass AURA policy.
public struct SafariBridgeSignedPayload: Codable, Sendable, Equatable {
  public static let currentProtocolVersion = 1

  public let protocolVersion: Int
  public let extensionID: String
  public let profileID: String
  public let nonce: String
  public let issuedAt: Date
  public let expiresAt: Date
  public let tab: SafariWebExtensionTabResponse

  public init(
    protocolVersion: Int = SafariBridgeSignedPayload.currentProtocolVersion,
    extensionID: String,
    profileID: String,
    nonce: String,
    issuedAt: Date,
    expiresAt: Date,
    tab: SafariWebExtensionTabResponse
  ) {
    self.protocolVersion = protocolVersion
    self.extensionID = extensionID
    self.profileID = profileID
    self.nonce = nonce
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.tab = tab
  }
}

/// The authenticated envelope the extension produces and the app validates.
/// The authentication tag is an HMAC over the canonical JSON of the payload;
/// the shared secret is never included in the payload, logs, or diagnostics.
public struct SafariBridgeEnvelope: Codable, Sendable, Equatable {
  public let payload: SafariBridgeSignedPayload
  public let authenticationTag: String

  public init(payload: SafariBridgeSignedPayload, authenticationTag: String) {
    self.payload = payload
    self.authenticationTag = authenticationTag
  }
}

/// HMAC authenticator for the Safari native-messaging bridge. The shared
/// secret is provisioned into the Keychain-backed secret store and supplied to
/// the extension at onboarding; it is never embedded in source, fixtures, or
/// ledgers.
public struct SafariBridgeAuthenticator: Sendable {
  private let key: SymmetricKey

  public init(sharedSecret: String) throws(AuraError) {
    guard !sharedSecret.isEmpty else {
      throw AuraError.securityError("Safari bridge shared secret must not be empty")
    }
    self.key = SymmetricKey(data: Data(sharedSecret.utf8))
  }

  /// Produce an authenticated envelope for a tab observation. Used by the
  /// extension side (or by tests) to sign a payload.
  public func makeEnvelope(
    tab: SafariWebExtensionTabResponse,
    extensionID: String,
    profileID: String,
    nonce: String,
    issuedAt: Date = Date(),
    lifetimeSeconds: Double = 30
  ) throws(AuraError) -> SafariBridgeEnvelope {
    guard !extensionID.isEmpty, !profileID.isEmpty, !nonce.isEmpty else {
      throw AuraError.securityError(
        "Safari bridge extension ID, profile ID, and nonce are required")
    }
    guard lifetimeSeconds > 0 else {
      throw AuraError.invalidConfiguration("Safari bridge lifetime must be positive")
    }
    let payload = SafariBridgeSignedPayload(
      extensionID: extensionID,
      profileID: profileID,
      nonce: nonce,
      issuedAt: issuedAt,
      expiresAt: issuedAt.addingTimeInterval(lifetimeSeconds),
      tab: tab
    )
    return SafariBridgeEnvelope(
      payload: payload,
      authenticationTag: try tag(for: payload)
    )
  }

  /// Validate an envelope received from the extension. Fails closed on any
  /// version, identity, nonce, freshness, or authentication mismatch.
  public func validate(
    _ envelope: SafariBridgeEnvelope,
    expectedExtensionID: String?,
    expectedProfileID: String?,
    now: Date = Date(),
    clockSkewSeconds: Double = 5
  ) throws(AuraError) {
    let payload = envelope.payload
    guard payload.protocolVersion == SafariBridgeSignedPayload.currentProtocolVersion else {
      throw AuraError.securityError("unsupported Safari bridge protocol version")
    }
    if let expectedExtensionID {
      guard payload.extensionID == expectedExtensionID else {
        throw AuraError.securityError("unexpected Safari bridge extension identity")
      }
    }
    if let expectedProfileID {
      guard payload.profileID == expectedProfileID else {
        throw AuraError.securityError("unexpected Safari bridge profile identity")
      }
    }
    guard !payload.nonce.isEmpty else {
      throw AuraError.securityError("Safari bridge nonce is empty")
    }
    guard payload.expiresAt > payload.issuedAt else {
      throw AuraError.securityError("Safari bridge envelope expiry is invalid")
    }
    guard payload.issuedAt <= now.addingTimeInterval(clockSkewSeconds) else {
      throw AuraError.securityError("Safari bridge envelope is issued in the future")
    }
    guard payload.expiresAt > now else {
      throw AuraError.securityError("Safari bridge envelope is expired")
    }
    guard try isValidTag(envelope.authenticationTag, for: payload) else {
      throw AuraError.securityError("Safari bridge authentication failed")
    }
  }

  /// Canonical JSON for the payload. Sorted keys and ISO-8601 dates keep the
  /// signing input byte-identical on both sides of the bridge.
  private func canonicalData(for payload: SafariBridgeSignedPayload) throws(AuraError) -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    do {
      return try encoder.encode(payload)
    } catch {
      throw AuraError.serializationError(
        "could not encode Safari bridge payload: " + error.localizedDescription)
    }
  }

  private func tag(for payload: SafariBridgeSignedPayload) throws(AuraError) -> String {
    let digest = HMAC<SHA256>.authenticationCode(for: try canonicalData(for: payload), using: key)
    return Data(digest).base64EncodedString()
  }

  /// Constant-time tag verification. Comparing authentication tags with `==`
  /// short-circuits on the first differing byte and leaks how much of a forged
  /// tag was correct, so verification goes through CryptoKit's constant-time
  /// check instead.
  private func isValidTag(
    _ tag: String,
    for payload: SafariBridgeSignedPayload
  ) throws(AuraError) -> Bool {
    guard let provided = Data(base64Encoded: tag) else {
      return false
    }
    return HMAC<SHA256>.isValidAuthenticationCode(
      provided,
      authenticating: try canonicalData(for: payload),
      using: key)
  }
}
