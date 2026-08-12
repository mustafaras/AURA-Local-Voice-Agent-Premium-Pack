import AuraCore
import AuraSecurity
import Foundation

public struct SafariWebExtensionTabResponse: Sendable, Equatable {
  public let tabID: String
  public let profileID: String
  public let url: URL
  public let title: String
  public let visibleText: String

  public init(
    tabID: String,
    profileID: String,
    url: URL,
    title: String,
    visibleText: String
  ) {
    self.tabID = tabID
    self.profileID = profileID
    self.url = url
    self.title = title
    self.visibleText = visibleText
  }
}
