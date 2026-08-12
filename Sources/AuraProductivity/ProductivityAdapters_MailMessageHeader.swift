import AuraCore
import AuraSecurity
import Foundation

public struct MailMessageHeader: Sendable, Equatable, Identifiable {
  public let id: String
  public let threadID: String
  public let sender: String
  public let recipients: [String]
  public let subject: ExternalContent
  public let receivedAt: Date
  public let isUnread: Bool
  public let attachments: [AttachmentMetadata]

  public init(
    id: String,
    threadID: String,
    sender: String,
    recipients: [String],
    subject: ExternalContent,
    receivedAt: Date,
    isUnread: Bool,
    attachments: [AttachmentMetadata] = []
  ) {
    self.id = id
    self.threadID = threadID
    self.sender = sender
    self.recipients = recipients
    self.subject = subject
    self.receivedAt = receivedAt
    self.isUnread = isUnread
    self.attachments = attachments
  }
}
