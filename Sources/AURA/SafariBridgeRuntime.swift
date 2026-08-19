import AuraCore
import AuraIntent
import AuraProductivity
import AuraSecurity
import Foundation

/// The composition unit for the Safari read bridge. It owns the authenticated
/// transport, the Keychain-backed secret store, and the profile-scoped read
/// adapter, and it exposes truthful availability. It is constructed by the
/// composition root but the capability remains disabled until the live
/// package and trust path are verified.
public struct SafariBridgeRuntime: Sendable {
  public let profile: BrowserProfileScope
  public let extensionID: String
  public let transport: any SafariWebExtensionTransport
  public let secretStore: SafariBridgeSecretStore
  public let adapter: SafariBrowserReadAdapter
  private let sharedContainerURL: URL

  public init(
    profile: BrowserProfileScope,
    extensionID: String,
    sharedContainerURL: URL,
    secretStore: SafariBridgeSecretStore,
    networkPolicy: ProductivityNetworkPolicy,
    classifier: PromptInjectionClassifier = PromptInjectionClassifier(),
    now: @escaping @Sendable () -> Date = { Date() },
    clockSkewSeconds: Double = 5,
    maxObservationAge: Double = 30
  ) {
    self.profile = profile
    self.extensionID = extensionID
    self.secretStore = secretStore
    self.sharedContainerURL = sharedContainerURL
    let transport = AuthenticatedSafariWebExtensionTransport(
      extensionID: extensionID,
      profileID: profile.profileID,
      sharedContainerURL: sharedContainerURL,
      secretStore: secretStore,
      now: now,
      clockSkewSeconds: clockSkewSeconds,
      maxObservationAge: maxObservationAge)
    self.transport = transport
    self.adapter = SafariBrowserReadAdapter(
      profile: profile,
      networkPolicy: networkPolicy,
      transport: transport,
      classifier: classifier)
  }

  /// The key the extension has published beside its envelope, if any.
  ///
  /// Read at connect time only. A missing file means the extension has never
  /// run, which the connect path reports as a next step rather than a failure.
  public func publishedExtensionKey() -> SafariBridgeExtensionKey? {
    let url = SafariBridgeEnvelopeWriter.verifyingKeyURL(besideEnvelopeAt: sharedContainerURL)
    guard let data = try? Data(contentsOf: url), data.count <= 8_192 else { return nil }
    return try? JSONDecoder().decode(SafariBridgeExtensionKey.self, from: data)
  }

  /// Truthful availability for the browser.read capability.
  public func availability() async -> CapabilityAvailability {
    await SafariBridgeAvailability.availability(
      transport: transport,
      profileID: profile.profileID,
      secretStore: secretStore)
  }
}
