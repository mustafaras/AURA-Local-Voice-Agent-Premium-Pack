import AuraCore
import AuraSecurity
import Foundation

// MARK: - Mail

public struct MailAccountSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let displayName: String
  public let provider: OAuthProviderID

  public init(id: String, displayName: String, provider: OAuthProviderID) {
    self.id = id
    self.displayName = displayName
    self.provider = provider
  }
}
