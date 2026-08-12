import AuraCore
import AuraSecurity
import Foundation

public struct BrowserTabSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let profileID: String
  public let url: URL
  public let title: ExternalContent
  public let visibleText: ExternalContent

  public init(
    id: String,
    profileID: String,
    url: URL,
    title: ExternalContent,
    visibleText: ExternalContent
  ) {
    self.id = id
    self.profileID = profileID
    self.url = url
    self.title = title
    self.visibleText = visibleText
  }
}
