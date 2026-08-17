import AuraCore
import AuraSecurity
import Foundation

/// The structured active-tab observation a Safari Web Extension returns to the
/// containing app. It is `Codable` so the native-messaging bridge can decode
/// the extension's JSON payload into this typed value. The bridge never
/// exposes cookies, passwords, hidden page state, or arbitrary page-script
/// execution.
public struct SafariWebExtensionTabResponse: Sendable, Equatable, Codable {
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
