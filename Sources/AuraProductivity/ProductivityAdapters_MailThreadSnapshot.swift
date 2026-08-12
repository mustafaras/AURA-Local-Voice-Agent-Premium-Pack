import AuraCore
import AuraSecurity
import Foundation

public struct MailThreadSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let messages: [MailMessageSnapshot]

  public init(id: String, messages: [MailMessageSnapshot]) {
    self.id = id
    self.messages = messages
  }
}
