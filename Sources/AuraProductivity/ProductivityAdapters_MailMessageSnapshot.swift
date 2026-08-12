import AuraCore
import AuraSecurity
import Foundation

public struct MailMessageSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let header: MailMessageHeader
  public let body: ExternalContent

  public init(id: String, header: MailMessageHeader, body: ExternalContent) {
    self.id = id
    self.header = header
    self.body = body
  }
}
