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
/// The signature is an ECDSA P-256 signature over the canonical JSON of the
/// payload. Only the extension can produce it, and the app needs nothing
/// secret to check it.
public struct SafariBridgeEnvelope: Codable, Sendable, Equatable {
  public let payload: SafariBridgeSignedPayload
  public let signature: String

  public init(payload: SafariBridgeSignedPayload, signature: String) {
    self.payload = payload
    self.signature = signature
  }
}

/// The extension's published verifying key.
///
/// The extension writes this beside the envelope. It is deliberately public
/// data: it authenticates the extension to the app and reveals nothing, which
/// is the whole reason the bridge no longer needs a shared secret.
public struct SafariBridgeExtensionKey: Codable, Sendable, Equatable {
  public let protocolVersion: Int
  public let extensionID: String
  public let profileID: String
  /// Base64 of the P-256 public key's raw (x||y) representation.
  public let publicKey: String

  public init(
    protocolVersion: Int = SafariBridgeSignedPayload.currentProtocolVersion,
    extensionID: String,
    profileID: String,
    publicKey: String
  ) {
    self.protocolVersion = protocolVersion
    self.extensionID = extensionID
    self.profileID = profileID
    self.publicKey = publicKey
  }
}

/// Canonical JSON for a payload. Sorted keys and ISO-8601 dates keep the
/// signing input byte-identical on both sides of the bridge.
enum SafariBridgeCanonicalEncoding {
  static func data(for payload: SafariBridgeSignedPayload) throws(AuraError) -> Data {
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
}

/// The extension's signing half.
///
/// SP-009 authenticated the bridge with an HMAC over a secret both halves
/// held. SP-011 found that unbuildable on a locally signed Mac: Safari refuses
/// a web extension that is not App Sandbox confined, a sandboxed process's
/// keychain queries are routed to the data-protection keychain while the
/// unsandboxed containing app uses the file-based login keychain, and sharing
/// an item across that boundary needs `keychain-access-groups` — a restricted
/// entitlement that requires a provisioning profile.
///
/// Signing asymmetrically removes the requirement rather than working around
/// it. The private key never leaves the extension's own keychain, so there is
/// no secret to share, publish, or leak; the app holds only a public key it
/// pinned when the user connected the profile.
public struct SafariBridgeSigner: Sendable {
  private let privateKey: P256.Signing.PrivateKey

  public init(privateKey: P256.Signing.PrivateKey) {
    self.privateKey = privateKey
  }

  /// The published form of this signer's verifying key.
  public func publishedKey(
    extensionID: String,
    profileID: String
  ) -> SafariBridgeExtensionKey {
    SafariBridgeExtensionKey(
      extensionID: extensionID,
      profileID: profileID,
      publicKey: privateKey.publicKey.rawRepresentation.base64EncodedString())
  }

  /// Produce a signed envelope for one tab observation.
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
    let canonical = try SafariBridgeCanonicalEncoding.data(for: payload)
    let signature: P256.Signing.ECDSASignature
    do {
      signature = try privateKey.signature(for: canonical)
    } catch {
      throw AuraError.securityError("Safari bridge payload could not be signed")
    }
    return SafariBridgeEnvelope(
      payload: payload,
      signature: signature.derRepresentation.base64EncodedString())
  }
}

/// The app's verifying half. It holds only the public key the user pinned.
public struct SafariBridgeVerifier: Sendable {
  private let publicKey: P256.Signing.PublicKey

  public init(publicKey: P256.Signing.PublicKey) {
    self.publicKey = publicKey
  }

  /// Build a verifier from a pinned key's base64 raw representation.
  public init(pinnedPublicKey: String) throws(AuraError) {
    guard let raw = Data(base64Encoded: pinnedPublicKey),
      let key = try? P256.Signing.PublicKey(rawRepresentation: raw)
    else {
      throw AuraError.securityError("pinned Safari bridge key is not a P-256 public key")
    }
    self.publicKey = key
  }

  /// Validate an envelope received from the extension. Fails closed on any
  /// version, identity, nonce, freshness, or signature mismatch.
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
    // ECDSA verification is inherently constant-time with respect to the
    // signature bytes, so there is no tag-comparison timing leak to guard.
    guard let provided = Data(base64Encoded: envelope.signature),
      let parsed = try? P256.Signing.ECDSASignature(derRepresentation: provided),
      publicKey.isValidSignature(
        parsed, for: try SafariBridgeCanonicalEncoding.data(for: payload))
    else {
      throw AuraError.securityError("Safari bridge authentication failed")
    }
  }
}
