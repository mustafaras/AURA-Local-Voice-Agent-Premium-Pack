import AuraCore
import AuraSecurity
import Foundation

/// A `SafariWebExtensionTransport` that reads a signed native-messaging
/// observation envelope from the shared app-group container, validates it
/// (version, extension identity, profile identity, nonce, freshness, signature),
/// and returns the typed active-tab response. It fails closed on every
/// unavailable, stale, mismatched, revoked, or unauthenticated state.
///
/// The extension writes the envelope to the shared directory; the containing
/// app reads it and checks the signature against the public key it pinned when
/// the user connected the profile. Nothing secret crosses the boundary and the
/// app holds no signing capability of its own.
public struct AuthenticatedSafariWebExtensionTransport: SafariWebExtensionTransport, Sendable {
  private let extensionID: String
  private let profileID: String
  private let sharedContainerURL: URL
  private let secretStore: SafariBridgeSecretStore
  private let now: @Sendable () -> Date
  private let clockSkewSeconds: Double
  private let maxObservationAge: Double
  private let maxPayloadBytes: Int

  /// - Parameters:
  ///   - clockSkewSeconds: tolerance for the two processes' clocks disagreeing.
  ///   - maxObservationAge: how long a written observation stays readable.
  ///     This must match the writer's envelope lifetime. It used to be the
  ///     clock-skew value, which made the file unreadable after five seconds
  ///     while the envelope it contained claimed thirty — so a user who
  ///     clicked the extension button and then asked AURA to read the page
  ///     always missed the window, and `browser.read` was never registered as
  ///     a usable tool by the time the request arrived.
  public init(
    extensionID: String,
    profileID: String,
    sharedContainerURL: URL,
    secretStore: SafariBridgeSecretStore,
    now: @escaping @Sendable () -> Date = { Date() },
    clockSkewSeconds: Double = 5,
    maxObservationAge: Double = 30,
    maxPayloadBytes: Int = 1_048_576
  ) {
    self.extensionID = extensionID
    self.profileID = profileID
    self.sharedContainerURL = sharedContainerURL
    self.secretStore = secretStore
    self.now = now
    self.clockSkewSeconds = clockSkewSeconds
    self.maxObservationAge = maxObservationAge
    self.maxPayloadBytes = maxPayloadBytes
  }

  public func readActiveTab(profileID: String) async throws -> SafariWebExtensionTabResponse {
    // The requested profile must match the transport's bound profile.
    guard profileID == self.profileID else {
      throw SafariBridgeTransportError.profileMismatch
    }
    // A pinned key must exist; otherwise the profile was never connected or
    // has been revoked, and an unpinned signature proves nothing.
    let pinned: String
    do {
      guard let existing = try await secretStore.pinnedPublicKey(profileID: profileID) else {
        throw SafariBridgeTransportError.notProvisioned
      }
      pinned = existing
    } catch let error as SafariBridgeTransportError {
      throw error
    } catch {
      throw SafariBridgeTransportError.unavailable
    }

    let verifier: SafariBridgeVerifier
    do {
      verifier = try SafariBridgeVerifier(pinnedPublicKey: pinned)
    } catch {
      throw SafariBridgeTransportError.unavailable
    }

    // Read the envelope from the shared container.
    let envelope = try readEnvelope()

    // Validate version, identity, profile, nonce, freshness, and signature.
    do {
      try verifier.validate(
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
    // A stale observation is refused. The bound is the observation's own
    // lifetime plus clock tolerance; the envelope's `expiresAt` is then
    // checked again during signature validation, so this is a cheap early
    // rejection, not the only expiry check.
    guard now().timeIntervalSince(modificationDate) <= maxObservationAge + clockSkewSeconds
    else {
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
  /// No extension key is pinned (never connected or revoked).
  case notProvisioned
  /// Version, identity, profile, nonce, freshness, or signature validation
  /// failed.
  case authenticationFailed
  /// The extension's native message was absent, undecodable, wrong-typed,
  /// wrong-versioned, or over the bounded observation size.
  case malformedMessage
}
