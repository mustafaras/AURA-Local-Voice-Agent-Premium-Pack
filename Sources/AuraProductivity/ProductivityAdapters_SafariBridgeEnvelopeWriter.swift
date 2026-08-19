import AuraCore
import Foundation

/// The producing half of the Safari bridge contract.
///
/// `AuthenticatedSafariWebExtensionTransport` consumes a signed envelope from
/// the shared directory; this writer is what puts one there. It runs in the
/// Safari app-extension process (through `SafariBridgeNativeMessageHandler`),
/// signs the observation with the extension's own private key, and writes it
/// atomically alongside the public key the app pins.
///
/// Without this type the two halves of the bridge never meet: the containing
/// app would validate an envelope that nothing in the package produces.
public struct SafariBridgeEnvelopeWriter: Sendable {
  /// Bounded observation size, mirrored by the extension's `background.js`.
  public static let maxVisibleTextCharacters = 20_000

  private let extensionID: String
  private let profileID: String
  private let sharedContainerURL: URL
  private let secretStore: SafariBridgeSecretStore
  private let now: @Sendable () -> Date
  private let lifetimeSeconds: Double
  private let makeNonce: @Sendable () -> String

  public init(
    extensionID: String,
    profileID: String,
    sharedContainerURL: URL,
    secretStore: SafariBridgeSecretStore,
    now: @escaping @Sendable () -> Date = { Date() },
    lifetimeSeconds: Double = 30,
    makeNonce: @escaping @Sendable () -> String = { UUID().uuidString }
  ) {
    self.extensionID = extensionID
    self.profileID = profileID
    self.sharedContainerURL = sharedContainerURL
    self.secretStore = secretStore
    self.now = now
    self.lifetimeSeconds = lifetimeSeconds
    self.makeNonce = makeNonce
  }

  /// Sign a tab observation and write it to the shared container. Fails closed
  /// on profile mismatch, unbounded text, missing provisioning, and any
  /// signing or write failure. Returns the envelope it wrote so callers and
  /// tests can assert on the exact signed value.
  @discardableResult
  public func write(
    tab: SafariWebExtensionTabResponse
  ) async throws(SafariBridgeTransportError) -> SafariBridgeEnvelope {
    // The observation must belong to the profile this writer is bound to.
    guard tab.profileID == profileID else {
      throw .profileMismatch
    }
    // The bridge carries bounded observations only.
    guard tab.visibleText.count <= Self.maxVisibleTextCharacters else {
      throw .malformedMessage
    }

    let signer: SafariBridgeSigner
    do {
      signer = SafariBridgeSigner(privateKey: try await secretStore.signingKey(profileID: profileID))
    } catch {
      throw .unavailable
    }

    // The verifying key is republished on every observation, not only the
    // first. The user may connect the profile at any point, and a key file
    // that went missing must not leave the bridge permanently unpinnable.
    try publishVerifyingKey(signer)

    let envelope: SafariBridgeEnvelope
    do {
      envelope = try signer.makeEnvelope(
        tab: tab,
        extensionID: extensionID,
        profileID: profileID,
        nonce: makeNonce(),
        issuedAt: now(),
        lifetimeSeconds: lifetimeSeconds)
    } catch {
      throw .unavailable
    }

    try writeAtomically(envelope)
    return envelope
  }

  /// Where the extension publishes its verifying key, beside the envelope.
  public static func verifyingKeyURL(besideEnvelopeAt envelopeURL: URL) -> URL {
    envelopeURL.deletingLastPathComponent().appending(path: "extension-key.json")
  }

  private func publishVerifyingKey(
    _ signer: SafariBridgeSigner
  ) throws(SafariBridgeTransportError) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do {
      let published = signer.publishedKey(extensionID: extensionID, profileID: profileID)
      try encoder.encode(published).write(
        to: Self.verifyingKeyURL(besideEnvelopeAt: sharedContainerURL), options: .atomic)
    } catch {
      throw .unavailable
    }
  }

  private func writeAtomically(
    _ envelope: SafariBridgeEnvelope
  ) throws(SafariBridgeTransportError) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    do {
      let data = try encoder.encode(envelope)
      try data.write(to: sharedContainerURL, options: .atomic)
    } catch {
      throw .unavailable
    }
  }
}
