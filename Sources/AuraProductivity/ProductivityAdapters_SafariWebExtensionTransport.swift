import AuraCore
import AuraSecurity
import Foundation

/// The containing macOS app communicates with a Safari Web Extension through
/// this structured bridge. The bridge never exposes cookies, passwords,
/// hidden page state, or arbitrary page-script execution.
public protocol SafariWebExtensionTransport: Sendable {
  func readActiveTab(profileID: String) async throws -> SafariWebExtensionTabResponse
}
