import AuraCore
import AuraSecurity
import Foundation

/// A `SafariWebExtensionTransport` that reads a signed native-messaging
/// observation envelope from the shared app-group container, validates it
/// (version, extension identity, profile identity, nonce, freshness, HMAC),
/// and returns the typed active-tab response. It fails closed on every
/// unavailable, stale, mismatched, revoked, or unauthenticated state.
///
/// The extension writes the envelope to the shared container; the containing
/// app reads and validates it. The shared secret is provisioned through
/// `SafariBridgeSecretStore` and is never embedded in the payload.
public struct AuthenticatedSafariWebExtensionTransport: SafariWebExtensionTransport, Sendable {
  private let extensionID: String
  private let profileID: String
  private let sharedContainerURL: URL
  private let secretStore: SafariBridgeSecretStore
  private let now: @Sendable () -> Date
  private let clockSkewSeconds: Double
  private let maxPayloadBytes: Int

  public init(
    extensionID: String,
    profileID: String,
    sharedContainerURL: URL,
    secretStore: SafariBridgeSecretStore,
    now: @escaping @Sendable () -> Date = { Date() },
    clockSkewSeconds: Double = 5,
    maxPayloadBytes: Int = 1_048_576
  ) {
    self.extensionID = extensionID
    self.profileID = profileID
    self.sharedContainerURL = sharedContainerURL
    self.secretStore = secretStore
    self.now = now
    self.clockSkewSeconds = clockSkewSeconds
    self.maxPayloadBytes = maxPayloadBytes
  }

  public func readActiveTab(profileID: String) async throws -> SafariWebExtensionTabResponse {
    // The requested profile must match the transport's bound profile.
    guard profileID == self.profileID else {
      throw SafariBridgeTransportError.profileMismatch
    }
    // The shared secret must be provisioned; otherwise the bridge is revoked
    // or never onboarded.
    let secret: String
    do {
      guard let provisioned = try await secretStore.sharedSecret(profileID: profileID) else {
        throw SafariBridgeTransportError.notProvisioned
      }
      secret = provisioned
    } catch let error as SafariBridgeTransportError {
      throw error
    } catch {
      throw SafariBridgeTransportError.unavailable
    }

    let authenticator: SafariBridgeAuthenticator
    do {
      authenticator = try SafariBridgeAuthenticator(sharedSecret: secret)
    } catch {
      throw SafariBridgeTransportError.unavailable
    }

    // Read the envelope from the shared container.
    let envelope = try readEnvelope()

    // Validate version, identity, profile, nonce, freshness, and HMAC.
    do {
      try authenticator.validate(
        envelope,
        expectedExtensionID: extensionID,
        expectedProfileID: profileID,
        now: now(),
        clockSkewSeconds: clockSkewSeconds)
    } catch {
      throw SafariBridgeTransportError.authenticationFailed
    }

    return envelope.payload.tab
  }

  private func readEnvelope() throws(SafariBridgeTransportError) -> SafariBridgeEnvelope {
    guard FileManager.default.fileExists(atPath: sharedContainerURL.path) else {
      throw .unavailable
    }
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: sharedContainerURL.path),
      let modificationDate = attributes[.modificationDate] as? Date
    else {
      throw .unavailable
    }
    // A stale observation (older than the freshness window) is refused.
    guard now().timeIntervalSince(modificationDate) <= clockSkewSeconds else {
      throw .stale
    }
    guard let data = try? Data(contentsOf: sharedContainerURL),
      data.count <= maxPayloadBytes
    else {
      throw .unavailable
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
      return try decoder.decode(SafariBridgeEnvelope.self, from: data)
    } catch {
      throw .unavailable
    }
  }
}

/// Distinct, user-presentable failure states for the Safari bridge transport.
public enum SafariBridgeTransportError: Error, Sendable, Equatable {
  /// The extension is not installed, the app group is not configured, or the
  /// shared container is not readable.
  case unavailable
  /// The observation is older than the freshness window.
  case stale
  /// The requested profile does not match the transport's bound profile.
  case profileMismatch
  /// The shared secret is not provisioned (never onboarded or revoked).
  case notProvisioned
  /// Version, identity, profile, nonce, freshness, or HMAC validation failed.
  case authenticationFailed
  /// The extension's native message was absent, undecodable, wrong-typed,
  /// wrong-versioned, or over the bounded observation size.
  case malformedMessage
}
